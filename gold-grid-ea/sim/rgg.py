"""Python mirror of the pure logic in RobbinsGoldGrid.mq5 (v2.00).

Function names are the snake_case form of the MQL5 functions they mirror
(e.g. MakeLayerOrder -> make_layer_order). Formulas must stay identical on both
sides; change them together. Stdlib only, so it runs anywhere with Python 3.8+.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import List, Optional, Sequence, Tuple

RR_RATIO = 3.0
RR_TOLERANCE = 0.01

BUY = 1
SELL = -1


# ---------------------------------------------------------------- prices / volume

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


def make_layer_order(direction: int, entry: float, sl: float, tick: float,
                     min_dist: float) -> Optional[Order]:
    """Layer with a fixed (structural) SL: TP = entry + 3 x own risk. Mirrors MakeLayerOrder()."""
    e = norm_price(entry, tick)
    s = norm_price(sl, tick)
    risk = direction * (e - s)
    if risk <= 0 or risk < min_dist:
        return None
    tp = norm_price(e + direction * RR_RATIO * risk, tick)
    if abs(abs(tp - e) / risk - RR_RATIO) > RR_TOLERANCE:
        return None
    return Order(direction, e, s, tp)


def build_layers(direction: int, e1: float, sl: float, levels: int, step_r: float,
                 min_sl: float, min_dist: float, tick: float) -> List[Order]:
    """Layer 0 at E1 (market), layer k at E1 -/+ k * step_r * R1, all sharing the SL."""
    r1 = direction * (e1 - sl)
    out = []
    for k in range(levels):
        entry = e1 - direction * k * step_r * r1
        o = make_layer_order(direction, entry, sl, tick, max(min_sl, min_dist))
        if o:
            o.level = k
            out.append(o)
    return out


def rr_repair_tp(direction: int, open_price: float, sl: float, tp: float,
                 tick: float) -> Optional[float]:
    """After slippage: the TP that restores exactly 3R from the actual open, or None if fine.
    Only while the SL is still on the losing side. Mirrors the RR repair in ManagePositions()."""
    risk = direction * (open_price - sl)
    if risk <= 0:
        return None
    want = norm_price(open_price + direction * RR_RATIO * risk, tick)
    if abs(tp - want) <= max(tick, 0.005 * risk):
        return None
    return want


def pending_valid(direction: int, entry: float, ask: float, bid: float, min_dist: float) -> bool:
    """Limit order validity (layers 2..N are always limits)."""
    return entry <= ask - min_dist if direction == BUY else entry >= bid + min_dist


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


def worst_case(realized: float, positions: Sequence[Order], pendings: Sequence[Order],
               contract_size: float) -> float:
    return realized + sum(pl_at_sl(o, contract_size) for o in positions) + \
        sum(pl_at_sl(o, contract_size) for o in pendings)


def risk_budget_allows(realized: float, positions: Sequence[Order], pendings: Sequence[Order],
                       new_order: Order, budget_money: float, contract_size: float) -> bool:
    wc = worst_case(realized, positions, pendings, contract_size) + pl_at_sl(new_order, contract_size)
    return wc >= -budget_money * 1.0001


def layers_allowed(levels: int, max_losses: int, losses_today: int) -> int:
    return max(0, min(levels, max_losses - losses_today))


def loss_limit_hit(losses_today: int, max_losses: int) -> bool:
    return losses_today >= max_losses


def hard_stop_hit(equity: float, peak_equity: float, max_dd_pct: float) -> bool:
    return max_dd_pct > 0 and equity <= peak_equity * (1.0 - max_dd_pct / 100.0)


def break_even_sl(o: Order, bid: float, ask: float, buffer_r: float, tick: float) -> Optional[float]:
    """New SL if the position has run >= 1R and SL is still on the losing side (option, off by default)."""
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


# ---------------------------------------------------------------- chart reading

@dataclass
class Bar:
    open: float
    high: float
    low: float
    close: float


@dataclass
class SignalParams:
    adx_min: float = 20.0
    pullback_bars: int = 6
    rsi_pullback: float = 40.0
    pin_wick_ratio: float = 2.0
    volatile_atr_mult: float = 2.0
    sl_buffer_atr: float = 0.2


def trend_state(ema_fast: float, ema_slow: float, ema_fast_prev: float, adx: float,
                adx_min: float) -> int:
    """H1 trend: +1 up, -1 down, 0 none. Mirrors TrendState()."""
    if adx < adx_min:
        return 0
    if ema_fast > ema_slow and ema_fast > ema_fast_prev:
        return BUY
    if ema_fast < ema_slow and ema_fast < ema_fast_prev:
        return SELL
    return 0


def bullish_confirm(c: Bar, p: Bar, wick_ratio: float) -> bool:
    rng = c.high - c.low
    if rng <= 0:
        return False
    body = abs(c.close - c.open)
    engulf = c.close > c.open and p.close < p.open and c.close >= p.open and c.open <= p.close
    lower_wick = min(c.open, c.close) - c.low
    pin = lower_wick >= wick_ratio * body and lower_wick >= 0.5 * rng and c.close >= c.low + 0.6 * rng
    return engulf or pin


def bearish_confirm(c: Bar, p: Bar, wick_ratio: float) -> bool:
    rng = c.high - c.low
    if rng <= 0:
        return False
    body = abs(c.close - c.open)
    engulf = c.close < c.open and p.close > p.open and c.close <= p.open and c.open >= p.close
    upper_wick = c.high - max(c.open, c.close)
    pin = upper_wick >= wick_ratio * body and upper_wick >= 0.5 * rng and c.close <= c.high - 0.6 * rng
    return engulf or pin


def detect_signal(trend: int, bars: Sequence[Bar], ema_fast: Sequence[float],
                  ema_slow: Sequence[float], rsi: Sequence[float], atr: float, atr_avg: float,
                  p: SignalParams) -> Tuple[Optional[float], str]:
    """Series are newest first: index 0 = last CLOSED bar (shift 1). Returns (sl, reason);
    sl is None when there is no signal and reason says why. Mirrors DetectSignal()."""
    n = p.pullback_bars
    if trend == 0:
        return None, "no trend"
    if len(bars) < max(n, 2) or len(rsi) < max(n, 2):
        return None, "data"
    if atr > p.volatile_atr_mult * atr_avg:
        return None, "volatile"
    window = range(n)
    if trend == BUY:
        touched = any(bars[k].low <= ema_fast[k] for k in window)
        extreme = min(bars[k].low for k in window)
        rsi_ok = min(rsi[k] for k in window) <= p.rsi_pullback and rsi[0] > rsi[1]
        held = bars[0].close > ema_slow[0]
        candle = bullish_confirm(bars[0], bars[1], p.pin_wick_ratio)
        sl = extreme - p.sl_buffer_atr * atr
    else:
        touched = any(bars[k].high >= ema_fast[k] for k in window)
        extreme = max(bars[k].high for k in window)
        rsi_ok = max(rsi[k] for k in window) >= 100.0 - p.rsi_pullback and rsi[0] < rsi[1]
        held = bars[0].close < ema_slow[0]
        candle = bearish_confirm(bars[0], bars[1], p.pin_wick_ratio)
        sl = extreme + p.sl_buffer_atr * atr
    if not touched:
        return None, "no pullback to zone"
    if not rsi_ok:
        return None, "rsi"
    if not held:
        return None, "zone broken"
    if not candle:
        return None, "no confirmation candle"
    return sl, "signal"
