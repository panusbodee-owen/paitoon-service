"""Tests for the Python mirror of RobbinsGoldGrid.mq5 (v2.00).

Run:  python3 -m unittest -v      (from gold-grid-ea/sim)
"""

import random
import unittest

from rgg import (BUY, SELL, RR_RATIO, RR_TOLERANCE, Bar, Order, SignalParams, break_even_sl,
                 bearish_confirm, build_layers, bullish_confirm, detect_signal, floor_volume,
                 hard_stop_hit, layers_allowed, lot_for_risk, loss_limit_hit, make_layer_order,
                 pending_valid, pl_at_sl, risk_budget_allows, rr_repair_tp, trend_state)
from setup_sim import CONTRACT, TICK, simulate_day


def rr_of(o: Order) -> float:
    return abs(o.tp - o.entry) / abs(o.entry - o.sl)


class TestLayers(unittest.TestCase):
    def test_layer_rr_is_three_for_random_inputs(self):
        rng = random.Random(1)
        for _ in range(5000):
            d = rng.choice((BUY, SELL))
            e = rng.uniform(1500, 5000)
            o = make_layer_order(d, e, e - d * rng.uniform(1.0, 25.0), TICK, 0.1)
            self.assertIsNotNone(o)
            self.assertAlmostEqual(rr_of(o), RR_RATIO, delta=RR_TOLERANCE)
            self.assertGreater(d * (o.tp - o.entry), 0)
            self.assertLess(d * (o.sl - o.entry), 0)

    def test_layer_rejects_sl_on_wrong_side_or_too_close(self):
        self.assertIsNone(make_layer_order(BUY, 4000, 4001, TICK, 0.1))
        self.assertIsNone(make_layer_order(SELL, 4000, 3999, TICK, 0.1))
        self.assertIsNone(make_layer_order(BUY, 4000, 3999.95, TICK, 0.1))

    def test_build_layers_buy_example(self):
        lv = build_layers(BUY, 4000.0, 3995.0, 3, 0.3, 1.0, 0.1, TICK)
        self.assertEqual([o.entry for o in lv], [4000.0, 3998.5, 3997.0])
        self.assertEqual([o.sl for o in lv], [3995.0] * 3)          # shared structural SL
        self.assertEqual([o.tp for o in lv], [4015.0, 4009.0, 4003.0])

    def test_build_layers_sell_and_min_sl(self):
        lv = build_layers(SELL, 4000.0, 4002.0, 3, 0.3, 1.0, 0.1, TICK)
        # R1 = 2 -> layers at R 2.0, 1.4, 0.8 ; the 0.8 layer is below MinSL 1.0 and dropped
        self.assertEqual([o.entry for o in lv], [4000.0, 4000.6])
        for o in lv:
            self.assertAlmostEqual(rr_of(o), 3.0, delta=RR_TOLERANCE)

    def test_rr_repair_after_slippage(self):
        # intended E 4000 SL 3995 TP 4015, filled at 4000.40 -> TP must become 4016.60
        self.assertAlmostEqual(rr_repair_tp(BUY, 4000.40, 3995.0, 4015.0, TICK), 4016.60)
        self.assertIsNone(rr_repair_tp(BUY, 4000.0, 3995.0, 4015.0, TICK))
        self.assertAlmostEqual(rr_repair_tp(SELL, 3999.70, 4005.0, 3985.0, TICK), 3983.80)
        self.assertIsNone(rr_repair_tp(BUY, 4000.0, 4000.5, 4015.0, TICK))  # SL in profit: leave

    def test_pending_valid(self):
        self.assertTrue(pending_valid(BUY, 3998.5, 4000.2, 4000.0, 0.1))
        self.assertFalse(pending_valid(BUY, 4000.15, 4000.2, 4000.0, 0.1))
        self.assertTrue(pending_valid(SELL, 4001.5, 4000.2, 4000.0, 0.1))


class TestFixedMoneySizing(unittest.TestCase):
    def test_user_example_30_dollar_account(self):
        # risk 5 per trade: R = 5$ -> 0.01 lot, lose 5 / win 15
        o = make_layer_order(BUY, 4000.0, 3995.0, TICK, 0.1)
        o.volume = lot_for_risk(5.0, o, CONTRACT, 0.01, 0.01, 100)
        self.assertEqual(o.volume, 0.01)
        self.assertAlmostEqual(pl_at_sl(o, CONTRACT), -5.0)
        self.assertAlmostEqual((o.tp - o.entry) * o.volume * CONTRACT, 15.0)

    def test_min_lot_too_big_is_skipped_not_rounded_up(self):
        o = make_layer_order(BUY, 4000.0, 3994.0, TICK, 0.1)  # 0.01 lot would lose 6 > 5
        self.assertEqual(lot_for_risk(5.0, o, CONTRACT, 0.01, 0.01, 100), 0.0)

    def test_bigger_risk_scales_lots(self):
        o = make_layer_order(SELL, 4000.0, 4005.0, TICK, 0.1)
        self.assertEqual(lot_for_risk(200.0, o, CONTRACT, 0.01, 0.01, 100), 0.40)

    def test_loss_never_exceeds_risk_money(self):
        rng = random.Random(2)
        for _ in range(3000):
            d = rng.choice((BUY, SELL))
            o = make_layer_order(d, 4000, 4000 - d * rng.uniform(1, 20), TICK, 0.1)
            risk = rng.uniform(1, 2000)
            o.volume = lot_for_risk(risk, o, CONTRACT, 0.01, 0.01, 100)
            self.assertLessEqual(-pl_at_sl(o, CONTRACT), risk + 1e-6)

    def test_floor_volume(self):
        self.assertEqual(floor_volume(0.339, 0.01, 0.01, 100), 0.33)
        self.assertEqual(floor_volume(0.0099, 0.01, 0.01, 100), 0.0)


class TestDailyRules(unittest.TestCase):
    def test_layers_capped_by_remaining_losses(self):
        self.assertEqual(layers_allowed(3, 3, 0), 3)
        self.assertEqual(layers_allowed(3, 3, 2), 1)
        self.assertEqual(layers_allowed(3, 3, 3), 0)
        self.assertEqual(layers_allowed(3, 5, 1), 3)

    def test_loss_limit(self):
        self.assertFalse(loss_limit_hit(2, 3))
        self.assertTrue(loss_limit_hit(3, 3))

    def test_hard_stop_off_by_default(self):
        self.assertFalse(hard_stop_hit(1.0, 10_000, 0.0))
        self.assertTrue(hard_stop_hit(7_000, 10_000, 30.0))

    def test_risk_budget(self):
        a = make_layer_order(BUY, 4000, 3995, TICK, 0.1); a.volume = 0.01
        b = make_layer_order(BUY, 3998.5, 3995, TICK, 0.1); b.volume = 0.01
        c = make_layer_order(BUY, 3997, 3995, TICK, 0.1); c.volume = 0.02
        self.assertTrue(risk_budget_allows(0, [a], [b], c, 15.0, CONTRACT))   # 5 + 3.5 + 4 = 12.5
        c.volume = 0.04
        self.assertFalse(risk_budget_allows(0, [a], [b], c, 15.0, CONTRACT))  # 5 + 3.5 + 8 = 16.5

    def test_break_even_option(self):
        o = make_layer_order(BUY, 4000, 3995, TICK, 0.1)
        self.assertIsNone(break_even_sl(o, 4004.99, 4005.2, 0.05, TICK))
        self.assertAlmostEqual(break_even_sl(o, 4005.0, 4005.2, 0.05, TICK), 4000.25)


def up_bars(last: Bar, prev: Bar, lows=None):
    """Six bars newest first; earlier bars pulled back to ~3990."""
    lows = lows or [3990.5, 3990.0, 3991.0, 3992.0]
    older = [Bar(l + 2, l + 3, l, l + 1) for l in lows]
    return [last, prev] + older


class TestChartReading(unittest.TestCase):
    p = SignalParams()

    def test_trend_state(self):
        self.assertEqual(trend_state(4000, 3950, 3995, 25, 20), BUY)
        self.assertEqual(trend_state(3900, 3950, 3905, 25, 20), SELL)
        self.assertEqual(trend_state(4000, 3950, 3995, 15, 20), 0)   # weak trend
        self.assertEqual(trend_state(4000, 3950, 4001, 25, 20), 0)   # fast EMA not rising

    def test_candles(self):
        prev_bear = Bar(3995, 3996, 3990, 3991)
        self.assertTrue(bullish_confirm(Bar(3990.5, 3997, 3990, 3996), prev_bear, 2.0))   # engulfing
        self.assertTrue(bullish_confirm(Bar(3994, 3995, 3988, 3994.6), Bar(1, 2, 0.5, 1.5), 2.0))  # hammer
        self.assertFalse(bullish_confirm(Bar(3996, 3997, 3990, 3991), prev_bear, 2.0))
        prev_bull = Bar(3991, 3996, 3990, 3995)
        self.assertTrue(bearish_confirm(Bar(3995.5, 3996, 3989, 3990), prev_bull, 2.0))
        self.assertTrue(bearish_confirm(Bar(3990, 3997, 3989.5, 3989.8), Bar(1, 2, 0.5, 1.5), 2.0))  # shooting star
        self.assertFalse(bearish_confirm(Bar(3990, 3996, 3989, 3995), prev_bull, 2.0))

    def _buy_case(self, **over):
        last = Bar(3990.5, 3997, 3990, 3996)      # bullish engulfing of prev
        prev = Bar(3995, 3996, 3990.2, 3991)
        bars = over.get("bars", up_bars(last, prev))
        ema20 = over.get("ema20", [3994] * 6)
        ema50 = over.get("ema50", [3989] * 6)
        rsi = over.get("rsi", [46, 38, 35, 41, 45, 50])
        atr = over.get("atr", 4.0)
        return detect_signal(BUY, bars, ema20, ema50, rsi, atr, 4.0, self.p)

    def test_buy_signal_and_structural_sl(self):
        sl, why = self._buy_case()
        self.assertEqual(why, "signal")
        self.assertAlmostEqual(sl, 3990.0 - 0.2 * 4.0)   # lowest low of 6 bars - 0.2 ATR

    def test_buy_rejections(self):
        self.assertEqual(self._buy_case(rsi=[46, 44, 45, 47, 48, 50])[1], "rsi")            # no RSI dip
        self.assertEqual(self._buy_case(rsi=[36, 38, 35, 41, 45, 50])[1], "rsi")            # RSI still falling
        self.assertEqual(self._buy_case(ema20=[3980] * 6)[1], "no pullback to zone")
        self.assertEqual(self._buy_case(ema50=[3997] * 6)[1], "zone broken")
        self.assertEqual(self._buy_case(atr=8.5)[1], "volatile")
        flat = up_bars(Bar(3995, 3996, 3994.8, 3995.3), Bar(3995, 3996, 3994, 3995.2))  # small body, no wick
        self.assertEqual(self._buy_case(bars=flat)[1], "no confirmation candle")
        self.assertEqual(detect_signal(0, flat, [1] * 6, [1] * 6, [50] * 6, 4, 4, self.p)[1], "no trend")

    def test_sell_signal_mirror(self):
        last = Bar(4009.5, 4010, 4003, 4004)       # bearish engulfing
        prev = Bar(4005, 4009.8, 4004, 4009)
        older = [Bar(h - 2, h, h - 3, h - 1) for h in (4009.5, 4010.0, 4009.0, 4008.0)]
        sl, why = detect_signal(SELL, [last, prev] + older, [4006] * 6, [4011] * 6,
                                [54, 62, 65, 59, 55, 50], 4.0, 4.0, self.p)
        self.assertEqual(why, "signal")
        self.assertAlmostEqual(sl, 4010.0 + 0.8)


class TestSetupInvariants(unittest.TestCase):
    """ADR-005: every trade -1R/+3R within the fixed money, losses/day <= limit."""

    def _check(self, seeds, **kw):
        for seed in seeds:
            r = simulate_day(seed, **kw)
            with self.subTest(seed=seed):
                risk = kw.get("risk_money", 5.0)
                self.assertLessEqual(r.losses, kw.get("max_losses", 3))
                self.assertGreaterEqual(r.min_worst_case_ratio, -1.0002)
                for pnl, at_risk in zip(r.trades, r.risks):
                    self.assertLessEqual(at_risk, risk + 1e-6)
                    if pnl > 0:
                        self.assertAlmostEqual(pnl, 3 * at_risk, delta=0.02)
                    else:
                        self.assertAlmostEqual(pnl, -at_risk, delta=0.02)
                for o in r.placed:
                    self.assertAlmostEqual(rr_of(o), RR_RATIO, delta=RR_TOLERANCE)

    def test_30_dollar_account_days(self):
        self._check(range(150), risk_money=5.0)
        placed = [o for s in range(30) for o in simulate_day(s).placed]
        self.assertTrue(placed)
        for o in placed:  # tight SL -> more lots, wide SL -> 0.01 or skipped; loss never above 5
            self.assertGreaterEqual(o.volume, 0.01)
            self.assertLessEqual(-pl_at_sl(o, CONTRACT), 5.0 + 1e-6)

    def test_10k_account_days(self):
        self._check(range(150), risk_money=200.0)

    def test_daily_stop_reached_and_layers_shrink(self):
        days = [simulate_day(s) for s in range(60)]
        self.assertTrue(any(d.stopped_by_losses for d in days))
        self.assertTrue(all(d.losses <= 3 for d in days))


if __name__ == "__main__":
    unittest.main()
