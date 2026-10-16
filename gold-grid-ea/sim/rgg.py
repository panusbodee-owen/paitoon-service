"""Python mirror of the pure logic in RobbinsGoldGrid.mq5.

Function names are the snake_case form of the MQL5 functions they mirror
(e.g. MakeOrder -> make_order). Formulas must stay identical on both sides;
change them together. Stdlib only, so it runs anywhere with Python 3.8+.
"""

from __future__ import annotations

import math
from dataclasses import dataclass, field
from typing import List, Optional

RR_RATIO = 3.0
RR_TOLERANCE = 0.01

BUY = 1
SELL = -1

REGIME_NEUTRAL = "NEUTRAL"
REGIME_RANGE = "RANGE"
REGIME_BREAKOUT_UP = "BREAKOUT_UP"
REGIME_BREAKOUT_DOWN = "BREAKOUT_DOWN"
REGIME_VOLATILE = "VOLATILE"

# preset -> (basket risk %, daily loss %, max drawdown %)
PRESETS = {
    "CONSERVATIVE": (1.5, 3.0, 10.0),
    "BALANCED": (3.0, 6.0, 15.0),
    "ROBBINS": (6.0, 12.0, 30.0),
}


def resolve_preset(preset: str, custom=(6.0, 12.0, 30.0)):
    return PRESETS.get(preset, custom)


# ---------------------------------------------------------------- prices/volume

def norm_price(price: float, tick: float) -> float:
    return round(round(price / tick) * tick, 10)


def floor_volume(volume: float, step: float, vmin: float, vmax: float) -> float:
    """Round DOWN to the volume step. Below the broker minimum -> 0 (skip)."""
    if volume <= 0:
        return 0.0
    lots = math.floor(volume / step + 1e-9) * step
    if lots < vmin - 1e-12:
        return 0.0
    lots = min(lots, vmax)
    decimals = max(0, -int(math.floor(math.log10(step)))) if step < 1 else 0
    return round(lots, decimals)


# ---------------------------------------------------------------- orders

@dataclass
class Order:
    direction: int  # BUY / SELL
    entry: float
    sl: float
    tp: float
    volume: float = 0.0
    level: int = 0
    side_tag: str = ""


def make_order(direction: int, entry: float, r_dist: float, tick: float) -> Optional[Order]:
    """Entry/SL normalized first, TP derived from the normalized distance, then
    the realized ratio is verified. Mirrors MakeOrder()."""
    if r_dist <= 0:
        return None
    e = norm_price(entry, tick)
    sl = norm_price(e - direction * r_dist, tick)
    risk = abs(e - sl)
    if risk <= 0:
        return None
    tp = norm_price(e + direction * RR_RATIO * risk, tick)
    ratio = abs(tp - e) / risk
    if abs(ratio - RR_RATIO) > RR_TOLERANCE:
        return None
    return Order(direction, e, sl, tp)


def clamp_r(r_dist: float, min_sl: float, max_sl: float, min_dist: float) -> float:
    r = min(max(r_dist, min_sl), max_sl)
    return max(r, min_dist)


def breakout_levels(direction: int, ask: float, bid: float, atr: float, levels: int,
                    entry_buf_atr: float, step_atr: float, sl_atr: float,
                    min_sl: float, max_sl: float, tick: float, min_dist: float) -> List[Order]:
    r = clamp_r(sl_atr * atr, min_sl, max_sl, min_dist)
    orders = []
    if direction == BUY:
        base = max(ask + entry_buf_atr * atr, ask + min_dist)
    else:
        base = min(bid - entry_buf_atr * atr, bid - min_dist)
    for i in range(levels):
        entry = base + direction * i * step_atr * atr
        o = make_order(direction, entry, r, tick)
        if o:
            o.level = i
            orders.append(o)
    return orders


def range_r(width: float, atr: float, risk_frac: float, min_sl_atr: float,
            min_sl: float, max_sl: float, min_dist: float) -> float:
    return clamp_r(max(risk_frac * width, min_sl_atr * atr), min_sl, max_sl, min_dist)


def range_entry(direction: int, low: float, high: float, level: int,
                first_offset: float, step_frac: float) -> float:
    width = high - low
    offset = (first_offset - level * step_frac) * width
    return low + offset if direction == BUY else high - offset


def range_levels(low: float, high: float, atr: float, levels: int, first_offset: float,
                 step_frac: float, risk_frac: float, min_sl_atr: float,
                 min_sl: float, max_sl: float, tick: float, min_dist: float) -> List[Order]:
    r = range_r(high - low, atr, risk_frac, min_sl_atr, min_sl, max_sl, min_dist)
    out = []
    for direction in (BUY, SELL):
        for i in range(levels):
            o = make_order(direction, range_entry(direction, low, high, i, first_offset, step_frac), r, tick)
            if o:
                o.level = i
                out.append(o)
    return out


def pending_valid(direction: int, is_limit: bool, entry: float, ask: float, bid: float,
                  min_dist: float) -> bool:
    if direction == BUY:
        return entry <= ask - min_dist if is_limit else entry >= ask + min_dist
    return entry >= bid + min_dist if is_limit else entry <= bid - min_dist


# ---------------------------------------------------------------- money / risk

def profit(direction: int, volume: float, open_price: float, close_price: float,
           contract_size: float) -> float:
    """Stand-in for OrderCalcProfit on a USD account."""
    return direction * (close_price - open_price) * volume * contract_size


def pl_at_sl(o: Order, contract_size: float) -> float:
    return profit(o.direction, o.volume, o.entry, o.sl, contract_size)


def lot_for_risk(risk_money: float, o: Order, contract_size: float,
                 step: float, vmin: float, vmax: float) -> float:
    loss_per_lot = abs(profit(o.direction, 1.0, o.entry, o.sl, contract_size))
    if loss_per_lot <= 0 or risk_money <= 0:
        return 0.0
    return floor_volume(risk_money / loss_per_lot, step, vmin, vmax)


def per_order_risk(basket_risk_money: float, levels: int, is_range: bool) -> float:
    return basket_risk_money / (levels * (2 if is_range else 1))


def worst_case(realized: float, positions: List[Order], pendings: List[Order],
               contract_size: float) -> float:
    return realized + sum(pl_at_sl(o, contract_size) for o in positions) + \
        sum(pl_at_sl(o, contract_size) for o in pendings)


def risk_budget_allows(realized: float, positions: List[Order], pendings: List[Order],
                       new_order: Order, basket_risk_money: float, contract_size: float) -> bool:
    wc = worst_case(realized, positions, pendings, contract_size) + pl_at_sl(new_order, contract_size)
    return wc >= -basket_risk_money * 1.0001


def account_gate(equity: float, day_start_equity: float, peak_equity: float,
                 daily_loss_pct: float, max_dd_pct: float, basket_risk_money: float) -> bool:
    daily_used = max(0.0, day_start_equity - equity)
    dd_used = max(0.0, peak_equity - equity)
    daily_ok = daily_used + basket_risk_money <= day_start_equity * daily_loss_pct / 100.0
    dd_ok = dd_used + basket_risk_money <= peak_equity * max_dd_pct / 100.0
    return daily_ok and dd_ok


def hard_stop_hit(equity: float, peak_equity: float, max_dd_pct: float) -> bool:
    return equity <= peak_equity * (1.0 - max_dd_pct / 100.0)


def daily_loss_hit(equity: float, day_start_equity: float, daily_loss_pct: float) -> bool:
    return equity <= day_start_equity * (1.0 - daily_loss_pct / 100.0)


def break_even_sl(o: Order, bid: float, ask: float, buffer_r: float, tick: float) -> Optional[float]:
    """New SL if the position has run >= 1R and SL is still on the losing side."""
    r = abs(o.entry - o.sl)
    if r <= 0:
        return None
    if o.direction == BUY:
        if o.sl >= o.entry or bid - o.entry < r:
            return None
        return norm_price(o.entry + buffer_r * r, tick)
    if o.sl <= o.entry or o.entry - ask < r:
        return None
    return norm_price(o.entry - buffer_r * r, tick)


# ---------------------------------------------------------------- regime

@dataclass
class RegimeParams:
    volatile_atr_mult: float = 2.0
    breakout_buffer_atr: float = 0.2
    adx_trend: float = 20.0
    bbw_pct_range: float = 40.0
    range_min_width_atr: float = 4.0
    range_max_width_atr: float = 12.0
    confirm_bars: int = 2
    sticky_bars: int = 8


@dataclass
class RegimeMetrics:
    close: float
    donch_high: float      # bars 2..N+1 (excludes last closed bar)
    donch_low: float
    range_high: float      # bars 1..N
    range_low: float
    atr: float
    atr_avg: float
    adx: float
    adx_prev: float
    bbw: float
    bbw_prev: float
    bbw_pct: float
    news: bool = False


def classify_regime(m: RegimeMetrics, p: RegimeParams) -> str:
    if m.news or m.atr > p.volatile_atr_mult * m.atr_avg:
        return REGIME_VOLATILE
    trend_ok = (m.adx >= p.adx_trend and m.adx > m.adx_prev) or (m.bbw > m.bbw_prev)
    buf = p.breakout_buffer_atr * m.atr
    if trend_ok and m.close > m.donch_high + buf:
        return REGIME_BREAKOUT_UP
    if trend_ok and m.close < m.donch_low - buf:
        return REGIME_BREAKOUT_DOWN
    width = m.range_high - m.range_low
    if (m.adx < p.adx_trend and m.bbw_pct <= p.bbw_pct_range
            and p.range_min_width_atr * m.atr <= width <= p.range_max_width_atr * m.atr
            and m.range_low <= m.close <= m.range_high):
        return REGIME_RANGE
    return REGIME_NEUTRAL


@dataclass
class RegimeTracker:
    params: RegimeParams = field(default_factory=RegimeParams)
    active: str = REGIME_NEUTRAL
    candidate: str = REGIME_NEUTRAL
    count: int = 0
    bo_level: float = 0.0
    bo_bar: int = -1

    def update(self, cand: str, m: RegimeMetrics, bar: int) -> str:
        if cand == REGIME_VOLATILE:
            self.active, self.candidate, self.count = cand, cand, 0
            return self.active
        if cand in (REGIME_BREAKOUT_UP, REGIME_BREAKOUT_DOWN):
            self.active, self.candidate, self.count = cand, cand, 0
            self.bo_level = m.donch_high if cand == REGIME_BREAKOUT_UP else m.donch_low
            self.bo_bar = bar
            return self.active
        if self.active in (REGIME_BREAKOUT_UP, REGIME_BREAKOUT_DOWN):
            beyond = m.close > self.bo_level if self.active == REGIME_BREAKOUT_UP else m.close < self.bo_level
            if beyond and bar - self.bo_bar < self.params.sticky_bars:
                return self.active
        if cand == self.candidate:
            self.count += 1
        else:
            self.candidate, self.count = cand, 1
        if self.count >= self.params.confirm_bars:
            self.active = cand
        return self.active
