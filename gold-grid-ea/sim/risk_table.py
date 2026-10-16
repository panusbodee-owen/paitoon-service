"""Risk table: what basket risk X means once a daily profit target caps the upside.

Run:  python3 risk_table.py [capital] [daily_target_pct]
Example: python3 risk_table.py 10000 5
"""

import math
import sys

RR = 3.0


def row(capital: float, x_pct: float, target_pct: float, dd_limit_pct: float = 30.0):
    win = min(RR * x_pct, target_pct) if target_pct > 0 else RR * x_pct
    loss = x_pct
    breakeven = loss / (loss + win)
    streak_to_dd = math.ceil(math.log(1 - dd_limit_pct / 100) / math.log(1 - x_pct / 100))
    after5 = capital * (1 - x_pct / 100) ** 5
    return win, loss, win / loss, breakeven, streak_to_dd, after5


def main():
    capital = float(sys.argv[1]) if len(sys.argv) > 1 else 10_000.0
    target = float(sys.argv[2]) if len(sys.argv) > 2 else 5.0
    print(f"capital {capital:,.0f} | daily target +{target}% | RR 1:{RR:.0f}")
    print(f"{'X %':>6} {'X $':>8} {'win cap %':>10} {'real RR':>8} {'need win%':>10} "
          f"{'losses to -30%':>15} {'after 5 losses':>15}")
    for x in (target / RR, 2.0, 3.0, 6.0, 8.0, 10.0, 15.0):
        win, loss, rr, be, streak, after5 = row(capital, x, target)
        print(f"{x:6.2f} {capital * x / 100:8,.0f} {win:10.2f} {rr:8.2f} {100 * be:9.1f}% "
              f"{streak:15d} {after5:15,.0f}")


if __name__ == "__main__":
    main()
