"""Tick-level simulation of one basket, used to check the ADR-001 invariants.

This is a behaviour check of the rules, not a profitability backtest: the
price path is a random walk and costs are ignored.
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import List

from rgg import (BUY, SELL, Order, RR_RATIO, break_even_sl, breakout_levels, lot_for_risk,
                 pending_valid, per_order_risk, profit, range_levels, risk_budget_allows,
                 worst_case)

CONTRACT = 100.0  # XAUUSD: 1 lot = 100 oz
TICK = 0.01
STEP, VMIN, VMAX = 0.01, 0.01, 100.0


@dataclass
class SimResult:
    realized: float = 0.0
    min_worst_case: float = 0.0
    placed: List[Order] = field(default_factory=list)
    closed_reason: str = "end"
    basket_risk: float = 0.0
    wins: int = 0
    losses: int = 0
    breakevens: int = 0


def _price_path(seed: int, start: float, n: int, vol: float, gap_at: int = -1, gap: float = 0.0):
    rng = random.Random(seed)
    p = start
    for i in range(n):
        p += rng.gauss(0.0, vol)
        if i == gap_at:
            p += gap
        yield round(p, 2)


def simulate_basket(mode: str, seed: int, equity: float = 10_000.0, basket_pct: float = 6.0,
                    levels: int = 3, atr: float = 4.0, spread: float = 0.20, n_ticks: int = 20_000,
                    vol: float = 0.15, fill_at_market: bool = False, gap_at: int = -1,
                    gap: float = 0.0, use_be: bool = True) -> SimResult:
    rng = random.Random(seed * 7919 + 1)
    basket_risk = equity * basket_pct / 100.0
    res = SimResult(basket_risk=basket_risk, min_worst_case=0.0)
    is_range = mode == "range"
    risk_each = per_order_risk(basket_risk, levels, is_range)
    min_dist = 0.10

    start = 2650.0
    bid = start
    ask = bid + spread
    positions: List[Order] = []
    pendings: List[Order] = []

    def try_add(o: Order) -> None:
        o.volume = lot_for_risk(risk_each, o, CONTRACT, STEP, VMIN, VMAX)
        if o.volume <= 0:
            return
        if not risk_budget_allows(res.realized, positions, pendings, o, basket_risk, CONTRACT):
            return
        res.placed.append(Order(o.direction, o.entry, o.sl, o.tp, o.volume, o.level, o.side_tag))
        pendings.append(o)

    low, high = start - 10.0, start + 10.0  # W = 20 = 5 ATR
    if is_range:
        for o in range_levels(low, high, atr, levels, 0.20, 0.10, 0.25, 1.0, 2.0, 20.0, TICK, min_dist):
            if pending_valid(o.direction, True, o.entry, ask, bid, min_dist):
                o.side_tag = "R"
                try_add(o)
        template = {(o.direction, o.level): o for o in
                    range_levels(low, high, atr, levels, 0.20, 0.10, 0.25, 1.0, 2.0, 20.0, TICK, min_dist)}
    else:
        direction = BUY if rng.random() < 0.5 else SELL
        for o in breakout_levels(direction, ask, bid, atr, levels, 0.1, 0.5, 1.5, 2.0, 20.0, TICK, min_dist):
            o.side_tag = "B"
            try_add(o)
        template = {}

    def close(o: Order, price: float) -> None:
        pnl = profit(o.direction, o.volume, o.entry, price, CONTRACT)
        res.realized += pnl
        if pnl > 1e-9:
            res.wins += 1
        elif pnl < -1e-9:
            res.losses += 1
        else:
            res.breakevens += 1
        positions.remove(o)

    for bid in _price_path(seed, start, n_ticks, vol, gap_at, gap):
        ask = round(bid + spread, 2)
        # pending triggers
        for o in list(pendings):
            hit = (ask >= o.entry if o.direction == BUY else bid <= o.entry) if o.side_tag == "B" else \
                  (ask <= o.entry if o.direction == BUY else bid >= o.entry)
            if hit:
                pendings.remove(o)
                positions.append(o)
        # SL / TP
        for o in list(positions):
            px = bid if o.direction == BUY else ask
            sl_hit = px <= o.sl if o.direction == BUY else px >= o.sl
            tp_hit = px >= o.tp if o.direction == BUY else px <= o.tp
            if sl_hit:
                close(o, px if fill_at_market else o.sl)
            elif tp_hit:
                close(o, px if fill_at_market else o.tp)
        # break-even
        if use_be:
            for o in positions:
                new_sl = break_even_sl(o, bid, ask, 0.05, TICK)
                if new_sl is not None:
                    o.sl = new_sl
        # basket stop / target
        floating = sum(profit(o.direction, o.volume, o.entry, bid if o.direction == BUY else ask, CONTRACT)
                       for o in positions)
        net = res.realized + floating
        if net <= -basket_risk or net >= RR_RATIO * basket_risk:
            for o in list(positions):
                close(o, bid if o.direction == BUY else ask)
            pendings.clear()
            res.closed_reason = "basket_stop" if net < 0 else "basket_target"
            break
        # range re-arm of empty slots
        if is_range:
            for (direction, level), tpl in template.items():
                taken = any(o.direction == direction and o.level == level for o in positions + pendings)
                if taken or not pending_valid(direction, True, tpl.entry, ask, bid, min_dist):
                    continue
                o = Order(direction, tpl.entry, tpl.sl, tpl.tp, 0.0, level, "R")
                try_add(o)
        wc = worst_case(res.realized, positions, pendings, CONTRACT)
        res.min_worst_case = min(res.min_worst_case, wc)
        if not positions and not pendings and not is_range:
            res.closed_reason = "flat"
            break
    else:
        for o in list(positions):
            close(o, bid if o.direction == BUY else ask)
    return res

