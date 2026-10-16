"""Tick-level simulation of one trading day of v2.00 setups, used to check the
ADR-005 invariants (not a profitability backtest: random-walk prices, no costs).
"""

from __future__ import annotations

import random
from dataclasses import dataclass, field
from typing import List

from rgg import (BUY, SELL, Order, build_layers, layers_allowed, lot_for_risk, loss_limit_hit,
                 pending_valid, profit, risk_budget_allows, worst_case)

CONTRACT = 100.0  # XAUUSD: 1 lot = 100 oz -> 0.01 lot = 1 USD per 1 USD move
TICK = 0.01


@dataclass
class DayResult:
    trades: List[float] = field(default_factory=list)       # net P/L per closed trade
    risks: List[float] = field(default_factory=list)        # money at risk per closed trade
    placed: List[Order] = field(default_factory=list)
    losses: int = 0
    setups: int = 0
    max_layers_seen: int = 0
    min_worst_case_ratio: float = 0.0                        # worst case / setup budget (>= -1)
    stopped_by_losses: bool = False


def simulate_day(seed: int, risk_money: float = 5.0, levels: int = 3, max_losses: int = 3,
                 step_r: float = 0.3, vmin: float = 0.01, vstep: float = 0.01,
                 n_ticks: int = 30_000, vol: float = 0.12, spread: float = 0.20) -> DayResult:
    rng = random.Random(seed)
    res = DayResult()
    bid = 4000.0
    positions: List[Order] = []
    pendings: List[Order] = []
    realized_setup = 0.0
    budget = 0.0
    tick_i = 0

    def close(o: Order, price: float) -> None:
        nonlocal realized_setup
        pnl = profit(o.direction, o.volume, o.entry, price, CONTRACT)
        res.trades.append(pnl)
        res.risks.append(abs(profit(o.direction, o.volume, o.entry, o.sl, CONTRACT)))
        realized_setup += pnl
        if pnl < -1e-9:
            res.losses += 1
        positions.remove(o)

    while tick_i < n_ticks and not loss_limit_hit(res.losses, max_losses):
        # ---- start a setup
        ask = round(bid + spread, 2)
        direction = BUY if rng.random() < 0.5 else SELL
        e1 = ask if direction == BUY else bid
        r1 = rng.uniform(1.5, 8.0)
        sl = e1 - direction * r1
        n_layers = layers_allowed(levels, max_losses, res.losses)
        res.max_layers_seen = max(res.max_layers_seen, n_layers)
        budget = n_layers * risk_money
        realized_setup = 0.0
        res.setups += 1
        for o in build_layers(direction, e1, sl, n_layers, step_r, 1.0, 0.10, TICK):
            o.volume = lot_for_risk(risk_money, o, CONTRACT, vstep, vmin, 100.0)
            if o.volume <= 0:
                continue
            if not risk_budget_allows(realized_setup, positions, pendings, o, budget, CONTRACT):
                continue
            if o.level > 0 and not pending_valid(direction, o.entry, ask, bid, 0.10):
                continue
            res.placed.append(Order(o.direction, o.entry, o.sl, o.tp, o.volume, o.level))
            (positions if o.level == 0 else pendings).append(o)
        if not positions and not pendings:
            tick_i += 50
            continue
        # ---- run the setup
        while tick_i < n_ticks and (positions or pendings):
            tick_i += 1
            bid = round(bid + rng.gauss(0.0, vol), 2)
            ask = round(bid + spread, 2)
            for o in list(pendings):
                if (ask <= o.entry) if o.direction == BUY else (bid >= o.entry):
                    pendings.remove(o)
                    positions.append(o)
            closed_any = False
            for o in list(positions):
                px = bid if o.direction == BUY else ask
                if (px <= o.sl) if o.direction == BUY else (px >= o.sl):
                    close(o, o.sl)
                    closed_any = True
                elif (px >= o.tp) if o.direction == BUY else (px <= o.tp):
                    close(o, o.tp)
                    closed_any = True
            if closed_any:
                pendings.clear()  # setup resolved: remaining layers are cancelled
            if budget > 0:
                wc = worst_case(realized_setup, positions, pendings, CONTRACT)
                res.min_worst_case_ratio = min(res.min_worst_case_ratio, wc / budget)
        tick_i += 20  # cooldown
    res.stopped_by_losses = loss_limit_hit(res.losses, max_losses)
    return res
