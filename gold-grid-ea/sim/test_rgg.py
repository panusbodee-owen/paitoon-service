"""Tests for the Python mirror of RobbinsGoldGrid.mq5.

Run:  python3 -m unittest -v      (from gold-grid-ea/sim)
"""

import random
import unittest

from basket_sim import CONTRACT, TICK, simulate_basket
from rgg import (BUY, SELL, Order, RR_RATIO, RR_TOLERANCE, REGIME_BREAKOUT_DOWN,
                 REGIME_BREAKOUT_UP, REGIME_NEUTRAL, REGIME_RANGE, REGIME_VOLATILE,
                 RegimeMetrics, RegimeParams, RegimeTracker, basket_risk_budget, break_even_sl,
                 daily_target_hit,
                 breakout_levels, classify_regime, daily_loss_hit, floor_volume, hard_stop_hit,
                 lot_for_risk, make_order, pending_valid, per_order_risk, pl_at_sl,
                 range_entry, range_levels, resolve_preset, risk_budget_allows)


def rr_of(o: Order) -> float:
    return abs(o.tp - o.entry) / abs(o.entry - o.sl)


class TestOrderGeometry(unittest.TestCase):
    def test_rr_is_three_for_random_orders(self):
        rng = random.Random(1)
        for _ in range(5000):
            d = rng.choice((BUY, SELL))
            o = make_order(d, rng.uniform(1500, 4000), rng.uniform(1.0, 25.0), TICK)
            self.assertIsNotNone(o)
            self.assertAlmostEqual(rr_of(o), RR_RATIO, delta=RR_TOLERANCE)
            if d == BUY:
                self.assertLess(o.sl, o.entry)
                self.assertGreater(o.tp, o.entry)
            else:
                self.assertGreater(o.sl, o.entry)
                self.assertLess(o.tp, o.entry)

    def test_rr_rejected_when_tick_too_coarse(self):
        # with a 1.0 tick size a 0.4 stop distance rounds to zero -> rejected
        self.assertIsNone(make_order(BUY, 2650.0, 0.4, 1.0))

    def test_breakout_levels_buy(self):
        ask, bid, atr = 2650.20, 2650.00, 4.0
        lv = breakout_levels(BUY, ask, bid, atr, 3, 0.1, 0.5, 1.5, 2.0, 20.0, TICK, 0.10)
        self.assertEqual(len(lv), 3)
        self.assertAlmostEqual(lv[0].entry, 2650.60, places=2)
        self.assertAlmostEqual(lv[1].entry - lv[0].entry, 2.0, places=2)
        for o in lv:
            self.assertAlmostEqual(o.entry - o.sl, 6.0, places=2)
            self.assertAlmostEqual(o.tp - o.entry, 18.0, places=2)
            self.assertTrue(pending_valid(BUY, False, o.entry, ask, bid, 0.10))

    def test_breakout_levels_sell_respect_min_distance(self):
        ask, bid, atr = 2650.20, 2650.00, 1.0
        lv = breakout_levels(SELL, ask, bid, atr, 3, 0.1, 0.5, 1.5, 2.0, 20.0, TICK, 0.50)
        self.assertLessEqual(lv[0].entry, bid - 0.50 + 1e-9)
        for o in lv:
            self.assertGreaterEqual(o.sl - o.entry, 2.0 - 1e-9)  # MinSL clamp
            self.assertAlmostEqual(rr_of(o), 3.0, delta=RR_TOLERANCE)

    def test_range_levels_layout(self):
        low, high, atr = 2640.0, 2660.0, 4.0  # W = 20
        lv = range_levels(low, high, atr, 3, 0.20, 0.10, 0.25, 1.0, 2.0, 20.0, TICK, 0.10)
        buys = sorted((o for o in lv if o.direction == BUY), key=lambda o: o.level)
        sells = sorted((o for o in lv if o.direction == SELL), key=lambda o: o.level)
        self.assertEqual([o.entry for o in buys], [2644.0, 2642.0, 2640.0])
        self.assertEqual([o.entry for o in sells], [2656.0, 2658.0, 2660.0])
        for o in lv:
            self.assertAlmostEqual(abs(o.entry - o.sl), 5.0, places=2)   # R = 0.25 * W
            self.assertAlmostEqual(abs(o.tp - o.entry), 15.0, places=2)  # 3R = 0.75 * W
        # TP of the first buy lands just under the range top
        self.assertAlmostEqual(buys[0].tp, 2659.0, places=2)

    def test_range_r_has_atr_floor(self):
        lv = range_levels(2640.0, 2650.0, 4.0, 1, 0.2, 0.1, 0.25, 1.0, 2.0, 20.0, TICK, 0.1)
        self.assertAlmostEqual(abs(lv[0].entry - lv[0].sl), 4.0, places=2)  # max(2.5, 4.0)

    def test_range_entry_mirror(self):
        self.assertAlmostEqual(range_entry(BUY, 100, 200, 0, 0.2, 0.1), 120.0)
        self.assertAlmostEqual(range_entry(SELL, 100, 200, 2, 0.2, 0.1), 200.0)


class TestSizing(unittest.TestCase):
    def test_floor_volume_never_rounds_up(self):
        self.assertEqual(floor_volume(0.339, 0.01, 0.01, 100), 0.33)
        self.assertEqual(floor_volume(0.0099, 0.01, 0.01, 100), 0.0)
        self.assertEqual(floor_volume(500, 0.01, 0.01, 100), 100)
        self.assertEqual(floor_volume(0.30000000004, 0.01, 0.01, 100), 0.30)

    def test_lot_for_risk_example_from_design(self):
        o = make_order(BUY, 2650.40, 6.0, TICK)
        lots = lot_for_risk(200.0, o, CONTRACT, 0.01, 0.01, 100)
        self.assertEqual(lots, 0.33)
        o.volume = lots
        self.assertAlmostEqual(pl_at_sl(o, CONTRACT), -198.0, places=6)

    def test_lot_for_risk_bounds(self):
        rng = random.Random(2)
        for _ in range(2000):
            o = make_order(rng.choice((BUY, SELL)), 2650, rng.uniform(2, 20), TICK)
            risk = rng.uniform(5, 5000)
            lots = lot_for_risk(risk, o, CONTRACT, 0.01, 0.01, 100)
            o.volume = lots
            loss = -pl_at_sl(o, CONTRACT)
            self.assertLessEqual(loss, risk + 1e-6)
            if lots > 0:
                one_step = abs(o.entry - o.sl) * CONTRACT * 0.01
                self.assertGreater(loss, risk - one_step - 1e-6)

    def test_per_order_risk_sums_to_basket(self):
        self.assertAlmostEqual(per_order_risk(600, 3, False) * 3, 600)
        self.assertAlmostEqual(per_order_risk(600, 3, True) * 6, 600)


class TestGuards(unittest.TestCase):
    def test_risk_budget(self):
        a = make_order(BUY, 2650, 6.0, TICK); a.volume = 0.33
        b = make_order(BUY, 2652, 6.0, TICK); b.volume = 0.33
        c = make_order(BUY, 2654, 6.0, TICK); c.volume = 0.34
        self.assertTrue(risk_budget_allows(0.0, [a], [b], c, 600.0, CONTRACT))  # 198+198+204=600
        c.volume = 0.35
        self.assertFalse(risk_budget_allows(0.0, [a], [b], c, 600.0, CONTRACT))
        # realized profit creates room, realized loss removes it
        self.assertTrue(risk_budget_allows(50.0, [a], [b], c, 600.0, CONTRACT))
        c.volume = 0.30
        self.assertFalse(risk_budget_allows(-50.0, [a], [b], c, 600.0, CONTRACT))

    def test_risk_budget_full_x_when_room(self):
        self.assertEqual(basket_risk_budget(10_000, 10_000, 10_000, 6, 12, 30), (600.0, "ok"))

    def test_risk_budget_throttles_instead_of_blocking(self):
        # day: 1200 limit, 700 used -> 500 room < X 552 -> throttled to 500
        budget, status = basket_risk_budget(9_300, 10_000, 10_000, 6, 12, 30)
        self.assertEqual(status, "ok")
        self.assertAlmostEqual(budget, 500.0)

    def test_regression_v100_silent_stall(self):
        # User backtest 2024 (500$ deposit, Robbins): peak equity 576.40, equity 428.16.
        # v1.00 required dd_used + X <= 30% of peak (173.93 > 172.92) and never traded again.
        budget, status = basket_risk_budget(428.16, 428.16, 576.40, 6, 12, 30)
        self.assertEqual(status, "ok")
        self.assertAlmostEqual(budget, 576.40 * 0.30 - (576.40 - 428.16), places=6)  # 24.68
        self.assertGreater(budget, 0.0)

    def test_risk_budget_explicit_halts(self):
        # DD room 3000-2950 = 50 < 25% of X (423) -> hard stop, never a silent idle
        self.assertEqual(basket_risk_budget(7_050, 7_050, 10_000, 6, 12, 30), (0.0, "hard_stop"))
        # daily room 1200-1150 = 50 < 25% of X -> paused for the day
        self.assertEqual(basket_risk_budget(8_850, 10_000, 10_000, 6, 12, 30), (0.0, "daily_halt"))

    def test_risk_budget_never_crosses_limits(self):
        rng = random.Random(3)
        for _ in range(5000):
            peak = rng.uniform(1_000, 20_000)
            equity = peak * rng.uniform(0.6, 1.0)
            day_start = max(equity, peak * rng.uniform(0.6, 1.0))
            budget, status = basket_risk_budget(equity, day_start, peak, 6, 12, 30)
            if status == "ok":
                self.assertLessEqual((peak - equity) + budget, peak * 0.30 + 1e-6)
                self.assertLessEqual(max(0.0, day_start - equity) + budget, day_start * 0.12 + 1e-6)
                self.assertGreaterEqual(budget, 0.25 * equity * 0.06 - 1e-9)

    def test_target_aligned_x_for_10k_and_5_percent(self):
        kw = dict(daily_target_pct=5.0, align_to_target=True)
        # start of day: X = 500 / 3
        b, st = basket_risk_budget(10_000, 10_000, 10_000, 6, 12, 30, **kw)
        self.assertEqual(st, "ok")
        self.assertAlmostEqual(b, 500 / 3)
        # already +200 today: X = 300 / 3 so a full win lands exactly on +5%
        b, _ = basket_risk_budget(10_200, 10_000, 10_200, 6, 12, 30, **kw)
        self.assertAlmostEqual(b, 100.0)
        # +480 today: remaining 20 -> below 10% of the full aligned X -> stop
        self.assertEqual(basket_risk_budget(10_480, 10_000, 10_480, 6, 12, 30, **kw), (0.0, "near_target"))

    def test_target_alignment_never_chases_losses_or_overshoots(self):
        rng = random.Random(4)
        kw = dict(daily_target_pct=5.0, align_to_target=True)
        for _ in range(5000):
            day_start = rng.uniform(5_000, 20_000)
            equity = day_start * rng.uniform(0.9, 1.049)
            peak = max(day_start, equity) * rng.uniform(1.0, 1.2)
            b, st = basket_risk_budget(equity, day_start, peak, 6, 12, 30, **kw)
            if st != "ok":
                continue
            self.assertLessEqual(b, day_start * 0.05 / 3 + 1e-9)  # never above target / 3
            day_pl = equity - day_start
            # a full winning basket (3X) never pushes the day beyond the target
            self.assertLessEqual(max(0.0, day_pl) + 3 * b, day_start * 0.05 + 1e-6)

    def test_daily_target_hit(self):
        self.assertTrue(daily_target_hit(10_500, 10_000, 5))
        self.assertFalse(daily_target_hit(10_499.99, 10_000, 5))
        self.assertFalse(daily_target_hit(20_000, 10_000, 0))

    def test_stops(self):
        self.assertTrue(hard_stop_hit(7_000, 10_000, 30))
        self.assertFalse(hard_stop_hit(7_001, 10_000, 30))
        self.assertTrue(daily_loss_hit(8_800, 10_000, 12))
        self.assertFalse(daily_loss_hit(8_801, 10_000, 12))

    def test_break_even(self):
        o = make_order(BUY, 2650, 5.0, TICK)
        self.assertIsNone(break_even_sl(o, 2654.99, 2655.2, 0.05, TICK))
        self.assertAlmostEqual(break_even_sl(o, 2655.0, 2655.2, 0.05, TICK), 2650.25)
        o.sl = 2650.25
        self.assertIsNone(break_even_sl(o, 2660, 2660.2, 0.05, TICK))  # already protected
        s = make_order(SELL, 2650, 5.0, TICK)
        self.assertAlmostEqual(break_even_sl(s, 2644.8, 2645.0, 0.05, TICK), 2649.75)

    def test_presets(self):
        self.assertEqual(resolve_preset("ROBBINS"), (6.0, 12.0, 30.0))
        self.assertEqual(resolve_preset("CUSTOM", (2.0, 5.0, 20.0)), (2.0, 5.0, 20.0))
        for x, daily, dd in (resolve_preset(p) for p in ("CONSERVATIVE", "BALANCED", "ROBBINS")):
            self.assertGreaterEqual(daily, 2 * x)  # at least two full baskets per day
            self.assertGreater(dd, daily)


def metrics(**kw):
    base = dict(close=2650, donch_high=2660, donch_low=2640, range_high=2660, range_low=2640,
                atr=4.0, atr_avg=4.0, adx=15, adx_prev=16, bbw=0.004, bbw_prev=0.005, bbw_pct=20)
    base.update(kw)
    return RegimeMetrics(**base)


class TestRegime(unittest.TestCase):
    p = RegimeParams()

    def test_classify(self):
        self.assertEqual(classify_regime(metrics(), self.p), REGIME_RANGE)
        self.assertEqual(classify_regime(metrics(atr=8.1), self.p), REGIME_VOLATILE)
        self.assertEqual(classify_regime(metrics(news=True), self.p), REGIME_VOLATILE)
        self.assertEqual(classify_regime(metrics(close=2661, adx=25, adx_prev=22), self.p), REGIME_BREAKOUT_UP)
        self.assertEqual(classify_regime(metrics(close=2638, bbw=0.006), self.p), REGIME_BREAKOUT_DOWN)
        # breakout without momentum confirmation is not a breakout
        self.assertNotEqual(classify_regime(metrics(close=2661, adx=25, adx_prev=26), self.p), REGIME_BREAKOUT_UP)
        # buffer: 0.2 * ATR = 0.8
        self.assertNotIn(classify_regime(metrics(close=2660.5, adx=25, adx_prev=22), self.p),
                         (REGIME_BREAKOUT_UP,))
        self.assertEqual(classify_regime(metrics(range_high=2700), self.p), REGIME_NEUTRAL)  # too wide
        self.assertEqual(classify_regime(metrics(adx=21), self.p), REGIME_NEUTRAL)

    def test_tracker_hysteresis_and_sticky(self):
        t = RegimeTracker(self.p)
        m = metrics()
        self.assertEqual(t.update(REGIME_RANGE, m, 0), REGIME_NEUTRAL)
        self.assertEqual(t.update(REGIME_RANGE, m, 1), REGIME_RANGE)
        bo = metrics(close=2662, donch_high=2660)
        self.assertEqual(t.update(REGIME_BREAKOUT_UP, bo, 2), REGIME_BREAKOUT_UP)
        # still above level -> sticky even though candidate is neutral
        self.assertEqual(t.update(REGIME_NEUTRAL, metrics(close=2661), 3), REGIME_BREAKOUT_UP)
        # back inside -> needs 2 confirmations
        self.assertEqual(t.update(REGIME_NEUTRAL, metrics(close=2655), 4), REGIME_BREAKOUT_UP)
        self.assertEqual(t.update(REGIME_NEUTRAL, metrics(close=2655), 5), REGIME_NEUTRAL)
        self.assertEqual(t.update(REGIME_VOLATILE, m, 6), REGIME_VOLATILE)

    def test_sticky_expires(self):
        t = RegimeTracker(self.p)
        t.update(REGIME_BREAKOUT_DOWN, metrics(close=2638, donch_low=2640), 0)
        for bar in range(1, 8):
            self.assertEqual(t.update(REGIME_NEUTRAL, metrics(close=2630), bar), REGIME_BREAKOUT_DOWN)
        t.update(REGIME_NEUTRAL, metrics(close=2630), 8)
        self.assertEqual(t.update(REGIME_NEUTRAL, metrics(close=2630), 9), REGIME_NEUTRAL)


class TestBasketInvariants(unittest.TestCase):
    """ADR-001: with exact SL fills the basket can never lose more than X."""

    def _check(self, mode, seeds):
        for seed in seeds:
            r = simulate_basket(mode, seed)
            with self.subTest(mode=mode, seed=seed):
                self.assertGreaterEqual(r.min_worst_case, -r.basket_risk * 1.0002)
                self.assertGreaterEqual(r.realized, -r.basket_risk * 1.0002)
                self.assertLessEqual(r.realized, 3 * r.basket_risk + 3 * 0.01 * CONTRACT * 3)
                for o in r.placed:
                    self.assertAlmostEqual(rr_of(o), RR_RATIO, delta=RR_TOLERANCE)
                    self.assertGreater(o.volume, 0)

    def test_breakout_baskets(self):
        self._check("breakout", range(150))

    def test_range_baskets_with_rearm(self):
        self._check("range", range(150))

    def test_range_rearms_and_trades_both_ways(self):
        total_placed = sum(len(simulate_basket("range", s).placed) for s in range(30))
        self.assertGreater(total_placed, 30 * 6)  # re-arm happened

    def test_gap_is_outside_the_invariant_and_backstop_closes_all(self):
        # A 40$ gap through the SLs fills at market: losses can exceed X (documented
        # residual risk). The basket stop must then flatten the basket immediately.
        stops = 0
        for seed in range(40):
            r = simulate_basket("breakout", seed, fill_at_market=True, gap_at=3000, gap=-40.0,
                                use_be=False, vol=0.05)
            if r.closed_reason == "basket_stop":
                stops += 1
                self.assertLess(r.realized, -r.basket_risk)
        self.assertGreater(stops, 10)

if __name__ == "__main__":
    unittest.main()
