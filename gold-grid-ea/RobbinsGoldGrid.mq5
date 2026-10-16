//+------------------------------------------------------------------+
//|                                              RobbinsGoldGrid.mq5 |
//|  Regime-switching grid EA for XAUUSD (MetaTrader 5, hedging).    |
//|                                                                  |
//|  - Every order: SL = 1R, TP = 3R (RR fixed at 1:3, not an input) |
//|  - Basket: stop at -X% , target at +3X% of basket-start equity   |
//|  - Range grid (limits) in sideways markets, breakout grid        |
//|    (stops, pyramiding) on breakouts, stand aside when volatile   |
//|  - Fixed-risk lots (no martingale), daily loss limit,            |
//|    equity hard-stop from peak, spread/session/news filters       |
//|                                                                  |
//|  Design: .10x/specs/2026-10-16-gold-grid-ea-design.md            |
//|  Python mirror of the pure logic: gold-grid-ea/sim/rgg.py        |
//+------------------------------------------------------------------+
#property copyright   "paitoon-service"
#property version     "1.10"
#property description "Robbins Gold Grid: regime-switching XAUUSD grid with fixed 1:3 RR."
#property description "Every order SL=1R / TP=3R. Basket stop -X% / target +3X%."
#property description "Fixed-risk lots, daily loss limit, equity hard-stop. Hedging accounts only."

#include <Trade\Trade.mqh>

#define RR_RATIO       3.0     // fixed by design (ADR-001) - deliberately not an input
#define RR_TOLERANCE   0.01
#define EA_TAG         "RGG"
#define EA_NAME        "Robbins Gold Grid"
#define RECENT_TTL_SEC 10

//====================================================================
// 1. CONFIG
//====================================================================
enum ENUM_RISK_PRESET
  {
   PRESET_CONSERVATIVE = 0, // Conservative (X 1.5% / Daily 3% / DD 10%)
   PRESET_BALANCED     = 1, // Balanced (X 3% / Daily 6% / DD 15%)
   PRESET_ROBBINS      = 2, // Robbins aggressive (X 6% / Daily 12% / DD 30%)
   PRESET_CUSTOM       = 3  // Custom (use the Custom inputs below)
  };

enum ENUM_RGG_REGIME
  {
   REGIME_NEUTRAL       = 0,
   REGIME_RANGE         = 1,
   REGIME_BREAKOUT_UP   = 2,
   REGIME_BREAKOUT_DOWN = 3,
   REGIME_VOLATILE      = 4
  };

enum ENUM_BASKET_TYPE
  {
   BASKET_NONE     = 0,
   BASKET_RANGE    = 1,
   BASKET_BREAKOUT = 2
  };

input group "=== Risk / Portfolio ==="
input ENUM_RISK_PRESET InpRiskPreset         = PRESET_ROBBINS; // Risk preset
input double           InpCustomBasketPct    = 6.0;   // Custom: basket risk X (% of equity)
input double           InpCustomDailyPct     = 12.0;  // Custom: daily loss limit (% of day-start equity)
input double           InpCustomMaxDDPct     = 30.0;  // Custom: equity hard-stop (% drawdown from peak)
input int              InpGridLevels         = 3;     // Grid levels per side (1-10)
input int              InpCooldownBars       = 4;     // Cooldown after basket stop/target (signal bars)
input bool             InpResetHardStop      = false; // Reset a triggered hard-stop when the EA starts
input double           InpMinRiskFraction    = 0.25;  // Halt when daily/DD headroom < this fraction of X

input group "=== Regime detector ==="
input ENUM_TIMEFRAMES  InpSignalTF           = PERIOD_M15; // Signal timeframe
input ENUM_TIMEFRAMES  InpContextTF          = PERIOD_H1;  // Context timeframe (ADX)
input int              InpATRPeriod          = 14;    // ATR period
input int              InpATRAvgBars         = 96;    // Bars for the average ATR
input double           InpVolatileATRMult    = 2.0;   // VOLATILE when ATR > mult x average ATR
input int              InpDonchianBars       = 24;    // Donchian / range box bars
input double           InpBreakoutBufferATR  = 0.2;   // Breakout must close beyond box by x ATR
input int              InpADXPeriod          = 14;    // ADX period (context TF)
input double           InpADXTrend           = 20.0;  // ADX trend threshold
input int              InpBBPeriod           = 20;    // Bollinger period
input double           InpBBDeviation        = 2.0;   // Bollinger deviation
input int              InpBBWidthLookback    = 100;   // Bars for BB-width percentile
input double           InpBBWidthPctRange    = 40.0;  // RANGE needs BB-width percentile <= this
input double           InpRangeMinWidthATR   = 4.0;   // RANGE box min width (x ATR)
input double           InpRangeMaxWidthATR   = 12.0;  // RANGE box max width (x ATR)
input int              InpConfirmBars        = 2;     // Confirmation bars for RANGE / NEUTRAL
input int              InpBreakoutStickyBars = 8;     // Breakout regime persists up to N bars

input group "=== Breakout grid ==="
input double           InpBreakoutSLATR      = 1.5;   // R = x ATR
input double           InpBreakoutStepATR    = 0.5;   // Distance between levels (x ATR)
input double           InpBreakoutEntryATR   = 0.1;   // First stop order distance from price (x ATR)
input int              InpPendingExpiryBars  = 8;     // Delete unfilled breakout stops after N bars
input int              InpBreakoutEntryBars  = 2;     // A breakout may start a basket within N bars

input group "=== Range grid ==="
input double           InpRangeRiskFrac      = 0.25;  // R = frac x box width
input double           InpRangeMinSLATR      = 1.0;   // ...but at least x ATR
input double           InpRangeFirstFrac     = 0.20;  // First level offset inside the box (x width)
input double           InpRangeStepFrac      = 0.10;  // Distance between levels (x width)
input bool             InpRangeRearm         = true;  // Re-arm a level after its trade closes

input group "=== Stops / trade care ==="
input double           InpMinSL              = 2.0;   // Minimum R (price units, e.g. 2.0 = 2$)
input double           InpMaxSL              = 20.0;  // Maximum R (price units)
input bool             InpUseBreakEven       = true;  // Move SL to break-even after +1R
input double           InpBreakEvenBufferR   = 0.05;  // Break-even buffer (x R) to cover costs

input group "=== Filters ==="
input double           InpMaxSpread          = 0.50;  // Max spread for new orders (price units)
input int              InpSessionStartHour   = 7;     // Trading session start (server hour, inclusive)
input int              InpSessionEndHour     = 21;    // Trading session end (server hour, exclusive)
input bool             InpAvoidRollover      = true;  // No new orders 23:00-01:00 server time
input int              InpFridayCutoffHour   = 20;    // Friday: no new orders from this hour
input bool             InpCloseAllFriday     = false; // Friday cutoff also closes positions (exit is not 1:3)
input bool             InpUseNewsFilter      = true;  // High-impact USD news filter (live only)
input int              InpNewsBeforeMin      = 30;    // Minutes before news
input int              InpNewsAfterMin       = 30;    // Minutes after news

input group "=== General ==="
input long             InpMagic              = 20261016; // Magic number
input int              InpSlippagePoints     = 30;    // Max slippage (points)
input bool             InpAllowNonGold       = false; // Allow symbols other than XAU/GOLD
input bool             InpShowDashboard      = true;  // Show status panel on chart
input bool             InpPushAlerts         = false; // Send push notifications on stops

//====================================================================
// 2. STATE
//====================================================================
struct RegimeMetrics
  {
   double            close;
   double            donchHigh;   // bars 2..N+1 (excludes the last closed bar)
   double            donchLow;
   double            rangeHigh;   // bars 1..N
   double            rangeLow;
   double            atr;
   double            atrAvg;
   double            adx;
   double            adxPrev;
   double            bbw;
   double            bbwPrev;
   double            bbwPct;
   bool              news;
  };

struct BasketState
  {
   bool              active;
   int               type;        // ENUM_BASKET_TYPE
   int               dir;         // breakout direction (+1/-1), 0 for range
   datetime          start;
   double            startEquity;
   double            riskMoney;   // X in account currency
   double            r;           // R distance in price units
   double            rangeLow;
   double            rangeHigh;
   bool              frozen;      // regime moved away: no more re-arming
  };

struct RecentOrder
  {
   ulong             ticket;
   int               dir;
   double            entry;
   double            plAtSl;
   datetime          at;
  };

CTrade                  g_trade;
int                     g_hATR = INVALID_HANDLE;
int                     g_hADX = INVALID_HANDLE;
int                     g_hBB  = INVALID_HANDLE;
double                  g_basketPct = 0.0;
double                  g_dailyPct  = 0.0;
double                  g_maxDDPct  = 0.0;
string                  g_gvPrefix  = "";
double                  g_point = 0.0;
double                  g_tick  = 0.0;
int                     g_digits = 0;
ENUM_ORDER_TYPE_FILLING g_marketFilling = ORDER_FILLING_FOK;

// regime
ENUM_RGG_REGIME         g_regime    = REGIME_NEUTRAL;
ENUM_RGG_REGIME         g_candidate = REGIME_NEUTRAL;
int                     g_candCount = 0;
double                  g_boLevel   = 0.0;
int                     g_barsSinceBO = 1000000;
bool                    g_boTraded  = true;
datetime                g_lastBarTime = 0;
datetime                g_regimeBarTime = 0; // signal bar on which the state machine last advanced (persisted)
double                  g_atr       = 0.0;
double                  g_boxHigh   = 0.0;
double                  g_boxLow    = 0.0;

// guards (persisted)
double                  g_peakEquity     = 0.0;
double                  g_dayStartEquity = 0.0;
datetime                g_dayStamp       = 0;
bool                    g_dailyHalt      = false;
bool                    g_hardHalt       = false;
datetime                g_cooldownUntil  = 0;

// basket (persisted)
BasketState             g_basket;
double                  g_realized      = 0.0;
bool                    g_historyDirty  = true;
datetime                g_lastBasketEnd = 0;

// closing state machine
bool                    g_closing         = false;
string                  g_closingReason   = "";
bool                    g_closingCooldown = false;

// misc
RecentOrder             g_recent[];
bool                    g_tradeDirty    = true;
datetime                g_lastMaintain  = 0;
datetime                g_newsCheckedAt = 0;
bool                    g_newsActive    = false;
string                  g_blockReason   = "";
uint                    g_lastDashMs    = 0;

// tester statistics (printed by OnTester)
int                     g_regimeBars[5];
int                     g_statBaskets[3];
int                     g_statSkipLot    = 0;
int                     g_statSkipMargin = 0;
int                     g_statSkipBudget = 0;
int                     g_statThrottled  = 0;

//====================================================================
// 3. UTILITIES
//====================================================================
void Log(const string msg)
  {
   PrintFormat("[%s] %s", EA_TAG, msg);
  }

void Notify(const string msg)
  {
   Log(msg);
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   Alert(EA_NAME, " ", _Symbol, ": ", msg);
   if(InpPushAlerts)
      SendNotification(EA_NAME + " " + _Symbol + ": " + msg);
  }

double NormPrice(const double price)
  {
   if(g_tick <= 0.0)
      return NormalizeDouble(price, g_digits);
   return NormalizeDouble(MathRound(price / g_tick) * g_tick, g_digits);
  }

int VolumeDigits(const double step)
  {
   int    digits = 0;
   double s      = step;
   while(s < 1.0 - 1e-9 && digits < 8)
     {
      s *= 10.0;
      digits++;
     }
   return digits;
  }

// Round DOWN to the volume step. Below the broker minimum -> 0 (skip the order, never round up).
double NormVolumeDown(const double volume)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(volume <= 0.0 || step <= 0.0)
      return 0.0;
   double lots = MathFloor(volume / step + 1e-9) * step;
   if(lots < vmin - 1e-12)
      return 0.0;
   if(lots > vmax)
      lots = vmax;
   return NormalizeDouble(lots, VolumeDigits(step));
  }

double MinStopDistance()
  {
   double stops  = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double freeze = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   return MathMax(stops, freeze) * g_point + g_tick;
  }

datetime DayStart(const datetime t)
  {
   return (datetime)((long)t - (long)t % 86400);
  }

int DirOfOrderType(const ENUM_ORDER_TYPE type)
  {
   if(type == ORDER_TYPE_BUY || type == ORDER_TYPE_BUY_LIMIT ||
      type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_BUY_STOP_LIMIT)
      return 1;
   return -1;
  }

string RegimeName(const ENUM_RGG_REGIME r)
  {
   switch(r)
     {
      case REGIME_RANGE:
         return "RANGE";
      case REGIME_BREAKOUT_UP:
         return "BREAKOUT UP";
      case REGIME_BREAKOUT_DOWN:
         return "BREAKOUT DOWN";
      case REGIME_VOLATILE:
         return "VOLATILE";
      default:
         return "NEUTRAL";
     }
  }

string BasketName(const int type)
  {
   if(type == BASKET_RANGE)
      return "RANGE";
   if(type == BASKET_BREAKOUT)
      return "BREAKOUT";
   return "NONE";
  }

string PresetName()
  {
   switch(InpRiskPreset)
     {
      case PRESET_CONSERVATIVE:
         return "Conservative";
      case PRESET_BALANCED:
         return "Balanced";
      case PRESET_ROBBINS:
         return "Robbins";
      default:
         return "Custom";
     }
  }

bool IsGoldSymbol()
  {
   string s = _Symbol;
   StringToUpper(s);
   return StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0;
  }

string SlotComment(const int basketType, const int dir, const int level)
  {
   return StringFormat("%s|%s|%s|%d", EA_TAG,
                       basketType == BASKET_RANGE ? "R" : "B",
                       dir > 0 ? "B" : "S", level);
  }

//====================================================================
// 4. PERSISTENCE (terminal global variables)
//====================================================================
string GVName(const string key)
  {
   return g_gvPrefix + key;
  }

void GVSet(const string key, const double value)
  {
   GlobalVariableSet(GVName(key), value);
  }

double GVGet(const string key, const double def)
  {
   string name = GVName(key);
   if(!GlobalVariableCheck(name))
      return def;
   return GlobalVariableGet(name);
  }

void SaveGuards()
  {
   GVSet("peak", g_peakEquity);
   GVSet("dayStamp", (double)g_dayStamp);
   GVSet("dayEq", g_dayStartEquity);
   GVSet("dHalt", g_dailyHalt ? 1.0 : 0.0);
   GVSet("hHalt", g_hardHalt ? 1.0 : 0.0);
   GVSet("cool", (double)g_cooldownUntil);
  }

void LoadGuards()
  {
   g_peakEquity     = GVGet("peak", 0.0);
   g_dayStamp       = (datetime)(long)GVGet("dayStamp", 0.0);
   g_dayStartEquity = GVGet("dayEq", 0.0);
   g_dailyHalt      = GVGet("dHalt", 0.0) > 0.5;
   g_hardHalt       = GVGet("hHalt", 0.0) > 0.5;
   g_cooldownUntil  = (datetime)(long)GVGet("cool", 0.0);
  }

void SaveBasket()
  {
   GVSet("bAct", g_basket.active ? 1.0 : 0.0);
   GVSet("bType", (double)g_basket.type);
   GVSet("bDir", (double)g_basket.dir);
   GVSet("bStart", (double)g_basket.start);
   GVSet("bEq", g_basket.startEquity);
   GVSet("bRisk", g_basket.riskMoney);
   GVSet("bR", g_basket.r);
   GVSet("bLow", g_basket.rangeLow);
   GVSet("bHigh", g_basket.rangeHigh);
   GVSet("bFrz", g_basket.frozen ? 1.0 : 0.0);
  }

void LoadBasket()
  {
   g_basket.active      = GVGet("bAct", 0.0) > 0.5;
   g_basket.type        = (int)GVGet("bType", 0.0);
   g_basket.dir         = (int)GVGet("bDir", 0.0);
   g_basket.start       = (datetime)(long)GVGet("bStart", 0.0);
   g_basket.startEquity = GVGet("bEq", 0.0);
   g_basket.riskMoney   = GVGet("bRisk", 0.0);
   g_basket.r           = GVGet("bR", 0.0);
   g_basket.rangeLow    = GVGet("bLow", 0.0);
   g_basket.rangeHigh   = GVGet("bHigh", 0.0);
   g_basket.frozen      = GVGet("bFrz", 0.0) > 0.5;
  }

void SaveRegime()
  {
   GVSet("rg", (double)g_regime);
   GVSet("rgC", (double)g_candidate);
   GVSet("rgN", (double)g_candCount);
   GVSet("rgBO", g_boLevel);
   GVSet("rgBS", (double)g_barsSinceBO);
   GVSet("rgBT", g_boTraded ? 1.0 : 0.0);
   GVSet("rgBar", (double)g_regimeBarTime);
  }

// Restores the regime state machine so a restart (chart timeframe change, VPS reboot)
// does not see a NEUTRAL regime and cancel an active basket's grid.
void LoadRegime()
  {
   g_regime        = (ENUM_RGG_REGIME)(int)GVGet("rg", (double)REGIME_NEUTRAL);
   g_candidate     = (ENUM_RGG_REGIME)(int)GVGet("rgC", (double)REGIME_NEUTRAL);
   g_candCount     = (int)GVGet("rgN", 0.0);
   g_boLevel       = GVGet("rgBO", 0.0);
   g_barsSinceBO   = (int)GVGet("rgBS", 1000000.0);
   g_boTraded      = GVGet("rgBT", 1.0) > 0.5;
   g_regimeBarTime = (datetime)(long)GVGet("rgBar", 0.0);
  }

void ResetBasketStruct()
  {
   g_basket.active      = false;
   g_basket.type        = BASKET_NONE;
   g_basket.dir         = 0;
   g_basket.start       = 0;
   g_basket.startEquity = 0.0;
   g_basket.riskMoney   = 0.0;
   g_basket.r           = 0.0;
   g_basket.rangeLow    = 0.0;
   g_basket.rangeHigh   = 0.0;
   g_basket.frozen      = false;
  }

//====================================================================
// 5. POSITION / ORDER QUERIES (scoped to symbol + magic)
//====================================================================
bool SelectedPositionIsOurs()
  {
   return PositionGetInteger(POSITION_MAGIC) == InpMagic &&
          PositionGetString(POSITION_SYMBOL) == _Symbol;
  }

bool SelectedOrderIsOurs()
  {
   return OrderGetInteger(ORDER_MAGIC) == InpMagic &&
          OrderGetString(ORDER_SYMBOL) == _Symbol;
  }

int CountPositions()
  {
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(SelectedPositionIsOurs())
         n++;
     }
   return n;
  }

int CountPendings()
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0)
         continue;
      if(SelectedOrderIsOurs())
         n++;
     }
   return n;
  }

double FloatingPL()
  {
   double sum = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if(!SelectedPositionIsOurs())
         continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
     }
   return sum;
  }

// An order placed a moment ago may not be in the terminal lists yet; it is visible
// once it is a pending order or has become a position (identifier = opening order ticket).
bool TicketVisible(const ulong ticket)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
      if(OrderGetTicket(i) == ticket)
         return true;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0)
         continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == ticket)
         return true;
     }
   return false;
  }

void AddRecent(const ulong ticket, const int dir, const double entry, const double plAtSl)
  {
   int n = ArraySize(g_recent);
   ArrayResize(g_recent, n + 1);
   g_recent[n].ticket = ticket;
   g_recent[n].dir    = dir;
   g_recent[n].entry  = entry;
   g_recent[n].plAtSl = plAtSl;
   g_recent[n].at     = TimeCurrent();
  }

void PurgeRecent()
  {
   for(int i = ArraySize(g_recent) - 1; i >= 0; i--)
     {
      if(TicketVisible(g_recent[i].ticket) || TimeCurrent() - g_recent[i].at > RECENT_TTL_SEC)
         ArrayRemove(g_recent, (uint)i, 1);
     }
  }

int InvisibleRecentCount()
  {
   int n = 0;
   for(int i = ArraySize(g_recent) - 1; i >= 0; i--)
      if(!TicketVisible(g_recent[i].ticket))
         n++;
   return n;
  }

bool SlotTaken(const int basketType, const int dir, const int level, const double entry, const double tol)
  {
   string tag = SlotComment(basketType, dir, level);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0 || !SelectedPositionIsOurs())
         continue;
      int pdir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(PositionGetString(POSITION_COMMENT) == tag)
         return true;
      if(pdir == dir && MathAbs(PositionGetDouble(POSITION_PRICE_OPEN) - entry) <= tol)
         return true;
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0 || !SelectedOrderIsOurs())
         continue;
      int odir = DirOfOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
      if(OrderGetString(ORDER_COMMENT) == tag)
         return true;
      if(odir == dir && MathAbs(OrderGetDouble(ORDER_PRICE_OPEN) - entry) <= tol)
         return true;
     }
   for(int i = ArraySize(g_recent) - 1; i >= 0; i--)
     {
      if(g_recent[i].dir == dir && MathAbs(g_recent[i].entry - entry) <= tol &&
         !TicketVisible(g_recent[i].ticket))
         return true;
     }
   return false;
  }

//====================================================================
// 6. RISK MANAGER
//====================================================================
// Broker-exact money for a price move (contract size, tick value, account currency).
bool ProfitAt(const int dir, const double volume, const double openPrice,
              const double closePrice, double &profit)
  {
   profit = 0.0;
   ENUM_ORDER_TYPE t = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return OrderCalcProfit(t, _Symbol, volume, openPrice, closePrice, profit);
  }

double ClampR(const double r, const double minDist)
  {
   double v = MathMin(MathMax(r, InpMinSL), InpMaxSL);
   return MathMax(v, minDist);
  }

// Entry and SL are normalized first, TP is derived from the normalized distance,
// then the realized ratio is verified. Mirrors rgg.make_order().
bool MakeOrder(const int dir, const double rawEntry, const double r,
               double &entry, double &sl, double &tp)
  {
   if(r <= 0.0)
      return false;
   entry = NormPrice(rawEntry);
   sl    = NormPrice(entry - dir * r);
   double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;
   tp = NormPrice(entry + dir * RR_RATIO * risk);
   double ratio = MathAbs(tp - entry) / risk;
   return MathAbs(ratio - RR_RATIO) <= RR_TOLERANCE;
  }

double LotForRisk(const int dir, const double entry, const double sl, const double riskMoney)
  {
   double lossPerLot = 0.0;
   if(riskMoney <= 0.0 || !ProfitAt(dir, 1.0, entry, sl, lossPerLot))
      return 0.0;
   lossPerLot = MathAbs(lossPerLot);
   if(lossPerLot <= 0.0)
      return 0.0;
   return NormVolumeDown(riskMoney / lossPerLot);
  }

bool MarginOk(const int dir, const double lots, const double price)
  {
   double margin = 0.0;
   ENUM_ORDER_TYPE t = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcMargin(t, _Symbol, lots, price, margin))
      return false;
   return margin <= AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9;
  }

void RefreshRealized()
  {
   if(!g_historyDirty)
      return;
   g_realized = 0.0;
   if(!g_basket.active)
     {
      g_historyDirty = false;
      return;
     }
   if(!HistorySelect(g_basket.start, TimeCurrent() + 60))
      return; // stays dirty, retried next call
   g_historyDirty = false;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      g_realized += HistoryDealGetDouble(deal, DEAL_PROFIT) +
                    HistoryDealGetDouble(deal, DEAL_SWAP) +
                    HistoryDealGetDouble(deal, DEAL_COMMISSION) +
                    HistoryDealGetDouble(deal, DEAL_FEE);
     }
  }

// realized + P/L if every open position and pending order of the EA hits its SL.
bool WorstCaseBasket(double &worst)
  {
   worst = g_realized;
   double p = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      if(PositionGetTicket(i) == 0 || !SelectedPositionIsOurs())
         continue;
      double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
         return false; // unbounded until repaired
      int dir = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      if(!ProfitAt(dir, PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN), sl, p))
         return false;
      worst += p + PositionGetDouble(POSITION_SWAP);
     }
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderGetTicket(i) == 0 || !SelectedOrderIsOurs())
         continue;
      double sl = OrderGetDouble(ORDER_SL);
      if(sl <= 0.0)
         return false;
      int dir = DirOfOrderType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE));
      if(!ProfitAt(dir, OrderGetDouble(ORDER_VOLUME_CURRENT), OrderGetDouble(ORDER_PRICE_OPEN), sl, p))
         return false;
      worst += p;
     }
   for(int i = ArraySize(g_recent) - 1; i >= 0; i--)
      if(!TicketVisible(g_recent[i].ticket))
         worst += g_recent[i].plAtSl;
   return true;
  }

// ADR-001 invariant: the basket can never be set up to lose more than X.
bool RiskBudgetAllows(const double plAtSlNew)
  {
   if(!g_basket.active)
      return false;
   RefreshRealized();
   double worst = 0.0;
   if(!WorstCaseBasket(worst))
      return false;
   return worst + plAtSlNew >= -g_basket.riskMoney * 1.0001;
  }

// Risk throttle for a NEW basket (ADR-003, mirrors rgg.basket_risk_budget):
// X shrinks to the remaining daily / drawdown headroom so a new basket can never
// cross either limit. When the headroom is below InpMinRiskFraction of X the EA halts
// explicitly (drawdown: hard-stop, daily: until the next server day) instead of idling
// silently - v1.00 blocked new baskets forever once DD + X exceeded the limit.
double BasketRiskBudget(const double equity)
  {
   double x       = equity * g_basketPct / 100.0;
   double dayRoom = g_dayStartEquity * g_dailyPct / 100.0 - MathMax(0.0, g_dayStartEquity - equity);
   double ddRoom  = g_peakEquity * g_maxDDPct / 100.0 - MathMax(0.0, g_peakEquity - equity);
   double floorX  = x * InpMinRiskFraction;
   if(ddRoom < floorX)
     {
      g_hardHalt = true;
      SaveGuards();
      Notify(StringFormat("EQUITY HARD-STOP: drawdown headroom %.2f is below %.0f%% of one basket (X = %.2f). Trading halted until reset.",
                          ddRoom, 100.0 * InpMinRiskFraction, x));
      return 0.0;
     }
   if(dayRoom < floorX)
     {
      g_dailyHalt = true;
      SaveGuards();
      Notify(StringFormat("DAILY LIMIT: daily headroom %.2f is below %.0f%% of one basket (X = %.2f). Paused until next day.",
                          dayRoom, 100.0 * InpMinRiskFraction, x));
      return 0.0;
     }
   double budget = MathMin(x, MathMin(dayRoom, ddRoom));
   if(budget < x - 1e-9)
     {
      g_statThrottled++;
      Log(StringFormat("Risk throttled: X %.2f -> %.2f (daily room %.2f, DD room %.2f)", x, budget, dayRoom, ddRoom));
     }
   return budget;
  }

//====================================================================
// 7. TRADE EXECUTION
//====================================================================
ENUM_ORDER_TYPE_FILLING DetectMarketFilling()
  {
   long mode = SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((mode & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
      return ORDER_FILLING_FOK;
   if((mode & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
      return ORDER_FILLING_IOC;
   return ORDER_FILLING_RETURN;
  }

ENUM_ORDER_TYPE_FILLING NextFilling(const ENUM_ORDER_TYPE_FILLING f)
  {
   if(f == ORDER_FILLING_FOK)
      return ORDER_FILLING_IOC;
   if(f == ORDER_FILLING_IOC)
      return ORDER_FILLING_RETURN;
   return ORDER_FILLING_FOK;
  }

ENUM_ORDER_TYPE_TIME PendingTimeType()
  {
   long modes = SymbolInfoInteger(_Symbol, SYMBOL_EXPIRATION_MODE);
   if((modes & SYMBOL_EXPIRATION_GTC) == SYMBOL_EXPIRATION_GTC)
      return ORDER_TIME_GTC;
   return ORDER_TIME_DAY;
  }

bool IsRetryable(const uint rc)
  {
   return rc == TRADE_RETCODE_REQUOTE || rc == TRADE_RETCODE_PRICE_CHANGED ||
          rc == TRADE_RETCODE_PRICE_OFF || rc == TRADE_RETCODE_TIMEOUT ||
          rc == TRADE_RETCODE_CONNECTION || rc == TRADE_RETCODE_TOO_MANY_REQUESTS;
  }

bool PlacePending(const ENUM_ORDER_TYPE type, const double volume, const double price,
                  const double sl, const double tp, const string comment, ulong &ticket)
  {
   ticket = 0;
   ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_RETURN;
   for(int attempt = 0; attempt < 3; attempt++)
     {
      g_trade.SetTypeFilling(filling);
      bool ok = g_trade.OrderOpen(_Symbol, type, volume, 0.0, price, sl, tp, PendingTimeType(), 0, comment);
      uint rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_PLACED))
        {
         ticket = g_trade.ResultOrder();
         Log(StringFormat("Placed %s %.2f @ %s SL %s TP %s [%s]", EnumToString(type), volume,
                          DoubleToString(price, g_digits), DoubleToString(sl, g_digits),
                          DoubleToString(tp, g_digits), comment));
         return true;
        }
      if(rc == TRADE_RETCODE_INVALID_FILL)
        {
         filling = (filling == ORDER_FILLING_RETURN) ? g_marketFilling : NextFilling(filling);
         continue;
        }
      if(!IsRetryable(rc))
        {
         Log(StringFormat("Pending rejected (%u %s) [%s]", rc, g_trade.ResultRetcodeDescription(), comment));
         break;
        }
     }
   g_trade.SetTypeFilling(g_marketFilling);
   return false;
  }

bool ClosePositionTicket(const ulong ticket, const string reason)
  {
   for(int attempt = 0; attempt < 3; attempt++)
     {
      g_trade.SetTypeFilling(g_marketFilling);
      bool ok = g_trade.PositionClose(ticket, (ulong)InpSlippagePoints);
      uint rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
        {
         Log(StringFormat("Closed position #%I64u (%s)", ticket, reason));
         return true;
        }
      if(rc == TRADE_RETCODE_INVALID_FILL)
        {
         g_marketFilling = NextFilling(g_marketFilling);
         continue;
        }
      if(!IsRetryable(rc))
        {
         Log(StringFormat("Close #%I64u failed (%u %s)", ticket, rc, g_trade.ResultRetcodeDescription()));
         break;
        }
     }
   return false;
  }

bool ModifyPosition(const ulong ticket, const double sl, const double tp)
  {
   for(int attempt = 0; attempt < 3; attempt++)
     {
      bool ok = g_trade.PositionModify(ticket, sl, tp);
      uint rc = g_trade.ResultRetcode();
      if((ok && rc == TRADE_RETCODE_DONE) || rc == TRADE_RETCODE_NO_CHANGES)
         return true;
      if(!IsRetryable(rc))
        {
         Log(StringFormat("Modify #%I64u failed (%u %s)", ticket, rc, g_trade.ResultRetcodeDescription()));
         break;
        }
     }
   return false;
  }

void CancelAllPendings(const string reason)
  {
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !SelectedOrderIsOurs())
         continue;
      if(g_trade.OrderDelete(t))
         n++;
     }
   if(n > 0)
      Log(StringFormat("Cancelled %d pending order(s): %s", n, reason));
  }

void CancelExpiredPendings(const int maxAgeSec)
  {
   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !SelectedOrderIsOurs())
         continue;
      datetime setup = (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(TimeCurrent() - setup >= maxAgeSec && g_trade.OrderDelete(t))
         Log(StringFormat("Pending #%I64u expired", t));
     }
  }

void CloseAllAndCancel(const string reason)
  {
   CancelAllPendings(reason);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !SelectedPositionIsOurs())
         continue;
      ClosePositionTicket(t, reason);
     }
  }

//====================================================================
// 8. BASKET LIFECYCLE + PORTFOLIO GUARDS
//====================================================================
void BeginBasket(const int type, const int dir, const double equity, const double riskMoney,
                 const double r, const double low, const double high)
  {
   g_basket.active      = true;
   g_basket.type        = type;
   g_basket.dir         = dir;
   datetime start = TimeCurrent();
   if(start <= g_lastBasketEnd)
      start = g_lastBasketEnd + 1; // keep the previous basket's closing deals out of this one
   g_basket.start       = start;
   g_basket.startEquity = equity;
   g_basket.riskMoney   = riskMoney;
   g_basket.r           = r;
   g_basket.rangeLow    = low;
   g_basket.rangeHigh   = high;
   g_basket.frozen      = false;
   g_realized           = 0.0;
   g_historyDirty       = true;
   SaveBasket();
   if(type >= 0 && type < 3)
      g_statBaskets[type]++;
   Log(StringFormat("Basket START %s dir %d | X = %.2f (%.2f%%) | target %.2f | R = %s",
                    BasketName(type), dir, riskMoney, g_basketPct, RR_RATIO * riskMoney,
                    DoubleToString(r, g_digits)));
  }

void EndBasket(const bool cooldown, const string reason)
  {
   if(!g_basket.active)
      return;
   RefreshRealized();
   Log(StringFormat("Basket END %s (%s) | realized %.2f", BasketName(g_basket.type), reason, g_realized));
   ResetBasketStruct();
   SaveBasket();
   g_lastBasketEnd = TimeCurrent();
   g_realized      = 0.0;
   g_historyDirty  = true;
   if(cooldown)
     {
      g_cooldownUntil = TimeCurrent() + InpCooldownBars * PeriodSeconds(InpSignalTF);
      SaveGuards();
     }
  }

void RequestCloseAll(const string reason, const bool cooldown)
  {
   if(!g_closing)
      Log("Close-all requested: " + reason);
   g_closing         = true;
   g_closingReason   = reason;
   g_closingCooldown = cooldown;
  }

// Retries every tick until flat, then ends the basket.
void ProcessClosing()
  {
   if(!g_closing)
      return;
   CloseAllAndCancel(g_closingReason);
   if(CountPositions() == 0 && CountPendings() == 0)
     {
      g_closing = false;
      EndBasket(g_closingCooldown, g_closingReason);
     }
  }

void RefreshDayAndPeak(const double equity)
  {
   datetime today = DayStart(TimeCurrent());
   if(today != g_dayStamp)
     {
      g_dayStamp       = today;
      g_dayStartEquity = equity;
      g_dailyHalt      = false;
      SaveGuards();
      Log(StringFormat("New trading day, start equity %.2f", equity));
     }
   if(equity > g_peakEquity)
     {
      g_peakEquity = equity;
      GVSet("peak", g_peakEquity);
     }
  }

bool CheckHardStop(const double equity)
  {
   if(!g_hardHalt && g_peakEquity > 0.0 && equity <= g_peakEquity * (1.0 - g_maxDDPct / 100.0))
     {
      g_hardHalt = true;
      SaveGuards();
      Notify(StringFormat("EQUITY HARD-STOP: equity %.2f <= %.1f%% below peak %.2f. Trading halted until reset.",
                          equity, g_maxDDPct, g_peakEquity));
      RequestCloseAll("equity hard-stop", false);
     }
   if(g_hardHalt && (CountPositions() > 0 || CountPendings() > 0))
      RequestCloseAll("equity hard-stop", false);
   return g_hardHalt;
  }

bool CheckDailyLoss(const double equity)
  {
   if(!g_dailyHalt && g_dayStartEquity > 0.0 && equity <= g_dayStartEquity * (1.0 - g_dailyPct / 100.0))
     {
      g_dailyHalt = true;
      SaveGuards();
      Notify(StringFormat("DAILY LOSS LIMIT: equity %.2f, day start %.2f (-%.1f%%). Paused until next day.",
                          equity, g_dayStartEquity, g_dailyPct));
      RequestCloseAll("daily loss limit", false);
     }
   if(g_dailyHalt && (CountPositions() > 0 || CountPendings() > 0))
      RequestCloseAll("daily loss limit", false);
   return g_dailyHalt;
  }

void CheckBasket()
  {
   if(!g_basket.active || g_closing)
      return;
   RefreshRealized();
   double net = g_realized + FloatingPL();
   if(net <= -g_basket.riskMoney)
     {
      Notify(StringFormat("Basket STOP: net %.2f <= -%.2f", net, g_basket.riskMoney));
      RequestCloseAll("basket stop", true);
     }
   else if(net >= RR_RATIO * g_basket.riskMoney)
     {
      Notify(StringFormat("Basket TARGET: net %.2f >= %.2f", net, RR_RATIO * g_basket.riskMoney));
      RequestCloseAll("basket target", true);
     }
  }

// SL repair (every position must carry SL/TP at 1:3) and break-even.
void ManagePositions(const MqlTick &tk)
  {
   double minDist = MinStopDistance();
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !SelectedPositionIsOurs())
         continue;
      int    dir  = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      double open = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl   = PositionGetDouble(POSITION_SL);
      double tp   = PositionGetDouble(POSITION_TP);
      double px   = dir > 0 ? tk.bid : tk.ask;

      if(sl <= 0.0)
        {
         double r = (g_basket.active && g_basket.r > 0.0) ? g_basket.r
                    : ClampR(InpBreakoutSLATR * g_atr, minDist);
         double nsl = NormPrice(open - dir * r);
         double ntp = NormPrice(open + dir * RR_RATIO * MathAbs(open - nsl));
         bool beyond = dir > 0 ? (px <= nsl + minDist) : (px >= nsl - minDist);
         if(beyond || !ModifyPosition(ticket, nsl, ntp))
            ClosePositionTicket(ticket, "missing SL could not be set");
         else
            Log(StringFormat("Repaired missing SL on #%I64u", ticket));
         continue;
        }
      if(tp <= 0.0)
        {
         double ntp = NormPrice(open + dir * RR_RATIO * MathAbs(open - sl));
         if(ModifyPosition(ticket, sl, ntp))
            Log(StringFormat("Repaired missing TP on #%I64u", ticket));
         continue;
        }
      if(InpUseBreakEven)
        {
         double r        = MathAbs(open - sl);
         bool   lossSide = dir > 0 ? (sl < open) : (sl > open);
         if(lossSide && r > 0.0 && dir * (px - open) >= r)
           {
            double nsl = NormPrice(open + dir * InpBreakEvenBufferR * r);
            bool   ok  = dir > 0 ? (px - nsl >= minDist) : (nsl - px >= minDist);
            if(ok && ModifyPosition(ticket, nsl, tp))
               Log(StringFormat("Break-even on #%I64u -> %s", ticket, DoubleToString(nsl, g_digits)));
           }
        }
     }
  }

//====================================================================
// 9. FILTERS
//====================================================================
bool InSession(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;
   if(InpAvoidRollover && (dt.hour >= 23 || dt.hour < 1))
      return false;
   if(dt.day_of_week == 5 && dt.hour >= InpFridayCutoffHour)
      return false;
   if(InpSessionStartHour <= InpSessionEndHour)
      return dt.hour >= InpSessionStartHour && dt.hour < InpSessionEndHour;
   return dt.hour >= InpSessionStartHour || dt.hour < InpSessionEndHour; // overnight session
  }

bool IsFridayCutoff(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week == 5 && dt.hour >= InpFridayCutoffHour;
  }

bool NewsWindowActive()
  {
   if(!InpUseNewsFilter || MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
      return false;
   datetime now = TimeTradeServer();
   if(now - g_newsCheckedAt < 60)
      return g_newsActive;
   g_newsCheckedAt = now;
   g_newsActive    = false;
   MqlCalendarValue values[];
   datetime from = now - InpNewsAfterMin * 60;
   datetime to   = now + InpNewsBeforeMin * 60;
   if(!CalendarValueHistory(values, from, to, NULL, "USD"))
      return false;
   for(int i = 0; i < ArraySize(values); i++)
     {
      MqlCalendarEvent ev;
      if(CalendarEventById(values[i].event_id, ev) && ev.importance == CALENDAR_IMPORTANCE_HIGH)
        {
         g_newsActive = true;
         break;
        }
     }
   return g_newsActive;
  }

bool EntryFiltersOk(const MqlTick &tk)
  {
   g_blockReason = "";
   if(g_hardHalt)
      g_blockReason = "hard-stop";
   else if(g_dailyHalt)
      g_blockReason = "daily limit";
   else if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
      g_blockReason = "algo trading disabled";
   else if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_FULL)
      g_blockReason = "symbol not fully tradable";
   else if(tk.ask - tk.bid > InpMaxSpread)
      g_blockReason = "spread";
   else if(!InSession(TimeCurrent()))
      g_blockReason = "outside session";
   else if(NewsWindowActive())
      g_blockReason = "news";
   return g_blockReason == "";
  }

//====================================================================
// 10. REGIME DETECTOR
//====================================================================
bool ReadRegimeMetrics(RegimeMetrics &m)
  {
   int atrBars = MathMax(InpATRAvgBars, 2);
   int lb      = MathMax(InpBBWidthLookback, 3);
   if(BarsCalculated(g_hATR) < atrBars + 2 || BarsCalculated(g_hBB) < lb + 2 || BarsCalculated(g_hADX) < 3)
      return false;
   if(Bars(_Symbol, InpSignalTF) < InpDonchianBars + 3)
      return false;

   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(g_hATR, 0, 1, atrBars, atr) < atrBars)
      return false;
   double sum = 0.0;
   for(int i = 0; i < atrBars; i++)
      sum += atr[i];
   m.atr    = atr[0];
   m.atrAvg = sum / atrBars;

   double adx[];
   ArraySetAsSeries(adx, true);
   if(CopyBuffer(g_hADX, 0, 1, 2, adx) < 2)
      return false;
   m.adx     = adx[0];
   m.adxPrev = adx[1];

   double mid[], up[], lo[];
   ArraySetAsSeries(mid, true);
   ArraySetAsSeries(up, true);
   ArraySetAsSeries(lo, true);
   if(CopyBuffer(g_hBB, 0, 1, lb, mid) < lb || CopyBuffer(g_hBB, 1, 1, lb, up) < lb ||
      CopyBuffer(g_hBB, 2, 1, lb, lo) < lb)
      return false;
   double w0 = mid[0] > 0.0 ? (up[0] - lo[0]) / mid[0] : 0.0;
   int    le = 0;
   for(int i = 0; i < lb; i++)
     {
      double wi = mid[i] > 0.0 ? (up[i] - lo[i]) / mid[i] : 0.0;
      if(wi <= w0)
         le++;
     }
   m.bbw     = w0;
   m.bbwPrev = mid[2] > 0.0 ? (up[2] - lo[2]) / mid[2] : 0.0; // two bars earlier
   m.bbwPct  = 100.0 * le / lb;

   int hiD = iHighest(_Symbol, InpSignalTF, MODE_HIGH, InpDonchianBars, 2);
   int loD = iLowest(_Symbol, InpSignalTF, MODE_LOW, InpDonchianBars, 2);
   int hiR = iHighest(_Symbol, InpSignalTF, MODE_HIGH, InpDonchianBars, 1);
   int loR = iLowest(_Symbol, InpSignalTF, MODE_LOW, InpDonchianBars, 1);
   if(hiD < 0 || loD < 0 || hiR < 0 || loR < 0)
      return false;
   m.donchHigh = iHigh(_Symbol, InpSignalTF, hiD);
   m.donchLow  = iLow(_Symbol, InpSignalTF, loD);
   m.rangeHigh = iHigh(_Symbol, InpSignalTF, hiR);
   m.rangeLow  = iLow(_Symbol, InpSignalTF, loR);
   m.close     = iClose(_Symbol, InpSignalTF, 1);
   m.news      = NewsWindowActive();
   return m.atr > 0.0 && m.close > 0.0;
  }

// Mirrors rgg.classify_regime().
ENUM_RGG_REGIME ClassifyRegime(const RegimeMetrics &m)
  {
   if(m.news || m.atr > InpVolatileATRMult * m.atrAvg)
      return REGIME_VOLATILE;
   bool   trendOk = (m.adx >= InpADXTrend && m.adx > m.adxPrev) || (m.bbw > m.bbwPrev);
   double buf     = InpBreakoutBufferATR * m.atr;
   if(trendOk && m.close > m.donchHigh + buf)
      return REGIME_BREAKOUT_UP;
   if(trendOk && m.close < m.donchLow - buf)
      return REGIME_BREAKOUT_DOWN;
   double width = m.rangeHigh - m.rangeLow;
   if(m.adx < InpADXTrend && m.bbwPct <= InpBBWidthPctRange &&
      width >= InpRangeMinWidthATR * m.atr && width <= InpRangeMaxWidthATR * m.atr &&
      m.close >= m.rangeLow && m.close <= m.rangeHigh)
      return REGIME_RANGE;
   return REGIME_NEUTRAL;
  }

// Mirrors rgg.RegimeTracker.update(): VOLATILE/BREAKOUT immediate, breakout sticky,
// RANGE/NEUTRAL need InpConfirmBars consecutive bars.
bool UpdateRegime()
  {
   RegimeMetrics m;
   if(!ReadRegimeMetrics(m))
      return false;
   g_atr     = m.atr;
   g_boxHigh = m.rangeHigh;
   g_boxLow  = m.rangeLow;
   datetime barTime = iTime(_Symbol, InpSignalTF, 0);
   if(barTime == g_regimeBarTime)
      return true; // already advanced on this bar (e.g. right after a restart)
   g_regimeBarTime = barTime;
   ENUM_RGG_REGIME cand = ClassifyRegime(m);
   ENUM_RGG_REGIME prev = g_regime;
   if(g_barsSinceBO < 1000000)
      g_barsSinceBO++;

   if(cand == REGIME_VOLATILE)
     {
      g_regime    = cand;
      g_candidate = cand;
      g_candCount = 0;
     }
   else if(cand == REGIME_BREAKOUT_UP || cand == REGIME_BREAKOUT_DOWN)
     {
      g_regime      = cand;
      g_candidate   = cand;
      g_candCount   = 0;
      g_boLevel     = (cand == REGIME_BREAKOUT_UP) ? m.donchHigh : m.donchLow;
      g_barsSinceBO = 0;
      g_boTraded    = false;
     }
   else
     {
      bool sticky = false;
      if(g_regime == REGIME_BREAKOUT_UP)
         sticky = m.close > g_boLevel && g_barsSinceBO < InpBreakoutStickyBars;
      else if(g_regime == REGIME_BREAKOUT_DOWN)
         sticky = m.close < g_boLevel && g_barsSinceBO < InpBreakoutStickyBars;
      if(!sticky)
        {
         if(cand == g_candidate)
            g_candCount++;
         else
           {
            g_candidate = cand;
            g_candCount = 1;
           }
         if(g_candCount >= InpConfirmBars)
            g_regime = cand;
        }
     }
   SaveRegime();
   g_regimeBars[(int)g_regime]++;
   if(prev != g_regime)
      Log(StringFormat("Regime %s -> %s | ATR %.2f avg %.2f ADX %.1f BBW%% %.0f box %s-%s",
                       RegimeName(prev), RegimeName(g_regime), m.atr, m.atrAvg, m.adx, m.bbwPct,
                       DoubleToString(m.rangeLow, g_digits), DoubleToString(m.rangeHigh, g_digits)));
   return true;
  }

bool IsNewBar()
  {
   datetime t = iTime(_Symbol, InpSignalTF, 0);
   if(t == 0 || t == g_lastBarTime)
      return false;
   g_lastBarTime = t;
   return true;
  }

//====================================================================
// 11. GRID ENGINE
//====================================================================
bool PendingValid(const int dir, const bool isLimit, const double entry,
                  const MqlTick &tk, const double minDist)
  {
   if(dir > 0)
      return isLimit ? entry <= tk.ask - minDist : entry >= tk.ask + minDist;
   return isLimit ? entry >= tk.bid + minDist : entry <= tk.bid - minDist;
  }

bool PlaceGridOrder(const int basketType, const int dir, const int level, const double rawEntry,
                    const double r, const double riskMoney, const MqlTick &tk)
  {
   bool   isLimit = (basketType == BASKET_RANGE);
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!MakeOrder(dir, rawEntry, r, entry, sl, tp))
      return false;
   if(!PendingValid(dir, isLimit, entry, tk, MinStopDistance()))
      return false;
   double lots = LotForRisk(dir, entry, sl, riskMoney);
   if(lots <= 0.0)
     {
      g_statSkipLot++;
      Log(StringFormat("Level %d skipped: lot for %.2f risk is below the broker minimum", level, riskMoney));
      return false;
     }
   if(!MarginOk(dir, lots, entry))
     {
      g_statSkipMargin++;
      Log(StringFormat("Level %d skipped: not enough free margin for %.2f lots", level, lots));
      return false;
     }
   double plAtSl = 0.0;
   if(!ProfitAt(dir, lots, entry, sl, plAtSl))
      return false;
   if(!RiskBudgetAllows(plAtSl))
     {
      g_statSkipBudget++;
      Log(StringFormat("Level %d skipped: basket risk budget X = %.2f would be exceeded", level, g_basket.riskMoney));
      return false;
     }
   ENUM_ORDER_TYPE type = dir > 0 ? (isLimit ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_BUY_STOP)
                          : (isLimit ? ORDER_TYPE_SELL_LIMIT : ORDER_TYPE_SELL_STOP);
   ulong ticket = 0;
   if(!PlacePending(type, lots, entry, sl, tp, SlotComment(basketType, dir, level), ticket))
      return false;
   if(ticket > 0)
      AddRecent(ticket, dir, entry, plAtSl);
   return true;
  }

// Nothing could be placed (lot below minimum, margin, stop levels): end the empty
// basket and wait one signal bar instead of retrying every maintenance pass.
void AbortBasketStart(const string reason)
  {
   EndBasket(false, reason);
   g_cooldownUntil = TimeCurrent() + PeriodSeconds(InpSignalTF);
   SaveGuards();
  }

void StartBreakoutBasket(const int dir, const MqlTick &tk, const double equity, const double riskMoney)
  {
   if(g_atr <= 0.0)
      return;
   double minDist = MinStopDistance();
   double r       = ClampR(InpBreakoutSLATR * g_atr, minDist);
   BeginBasket(BASKET_BREAKOUT, dir, equity, riskMoney, r, 0.0, 0.0);
   g_boTraded = true;
   SaveRegime();
   double base = dir > 0 ? MathMax(tk.ask + InpBreakoutEntryATR * g_atr, tk.ask + minDist)
                 : MathMin(tk.bid - InpBreakoutEntryATR * g_atr, tk.bid - minDist);
   double each   = riskMoney / InpGridLevels;
   int    placed = 0;
   for(int i = 0; i < InpGridLevels; i++)
     {
      double entry = base + dir * i * InpBreakoutStepATR * g_atr;
      if(PlaceGridOrder(BASKET_BREAKOUT, dir, i, entry, r, each, tk))
         placed++;
     }
   if(placed == 0)
      AbortBasketStart("no breakout level could be placed");
  }

int RearmRange(const MqlTick &tk)
  {
   if(!g_basket.active || g_basket.type != BASKET_RANGE)
      return 0;
   double w = g_basket.rangeHigh - g_basket.rangeLow;
   if(w <= 0.0)
      return 0;
   // the box is broken: leave it to the regime detector
   if(tk.bid > g_basket.rangeHigh + g_basket.r || tk.ask < g_basket.rangeLow - g_basket.r)
      return 0;
   double each   = g_basket.riskMoney / (2.0 * InpGridLevels);
   int    placed = 0;
   for(int s = 0; s < 2; s++)
     {
      int dir = (s == 0) ? 1 : -1;
      for(int i = 0; i < InpGridLevels; i++)
        {
         double offset = (InpRangeFirstFrac - i * InpRangeStepFrac) * w;
         double entry  = dir > 0 ? g_basket.rangeLow + offset : g_basket.rangeHigh - offset;
         if(SlotTaken(BASKET_RANGE, dir, i, NormPrice(entry), 0.25 * g_basket.r))
            continue;
         if(PlaceGridOrder(BASKET_RANGE, dir, i, entry, g_basket.r, each, tk))
            placed++;
        }
     }
   return placed;
  }

void StartRangeBasket(const MqlTick &tk, const double equity, const double riskMoney)
  {
   double w = g_boxHigh - g_boxLow;
   if(w <= 0.0 || g_atr <= 0.0)
      return;
   if(tk.bid > g_boxHigh || tk.ask < g_boxLow)
      return; // price already outside the box
   double r = ClampR(MathMax(InpRangeRiskFrac * w, InpRangeMinSLATR * g_atr), MinStopDistance());
   BeginBasket(BASKET_RANGE, 0, equity, riskMoney, r, g_boxLow, g_boxHigh);
   if(RearmRange(tk) == 0)
      AbortBasketStart("no range level could be placed yet");
  }

void TryStartBasket(const MqlTick &tk)
  {
   if(g_basket.active || g_closing)
      return;
   if(TimeCurrent() < g_cooldownUntil)
     {
      g_blockReason = "cooldown";
      return;
     }
   if(!EntryFiltersOk(tk))
      return;
   bool boWindow = g_barsSinceBO < InpBreakoutEntryBars && !g_boTraded;
   int  boDir    = 0;
   if(g_regime == REGIME_BREAKOUT_UP && boWindow)
      boDir = 1;
   else if(g_regime == REGIME_BREAKOUT_DOWN && boWindow)
      boDir = -1;
   else if(g_regime != REGIME_RANGE)
      return;
   double equity    = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskMoney = BasketRiskBudget(equity);
   if(riskMoney <= 0.0)
      return;
   if(boDir != 0)
      StartBreakoutBasket(boDir, tk, equity, riskMoney);
   else
      StartRangeBasket(tk, equity, riskMoney);
  }

bool BasketMatchesRegime()
  {
   if(g_basket.type == BASKET_RANGE)
      return g_regime == REGIME_RANGE;
   if(g_basket.type == BASKET_BREAKOUT)
      return (g_basket.dir > 0 && g_regime == REGIME_BREAKOUT_UP) ||
             (g_basket.dir < 0 && g_regime == REGIME_BREAKOUT_DOWN);
   return false;
  }

void Maintain(const MqlTick &tk)
  {
   int positions = CountPositions();
   int pendings  = CountPendings();

   if(g_basket.active)
     {
      if(!BasketMatchesRegime())
        {
         if(!g_basket.frozen)
           {
            g_basket.frozen = true;
            SaveBasket();
           }
         if(pendings > 0)
            CancelAllPendings("regime changed to " + RegimeName(g_regime));
        }
      if(g_basket.type == BASKET_BREAKOUT)
         CancelExpiredPendings(InpPendingExpiryBars * PeriodSeconds(InpSignalTF));
     }

   if(IsFridayCutoff(TimeCurrent()) && InpCloseAllFriday && positions > 0)
     {
      RequestCloseAll("Friday close", false);
      return;
     }
   if(!InSession(TimeCurrent()) && CountPendings() > 0)
      CancelAllPendings("outside trading session");
   if(NewsWindowActive() && CountPendings() > 0)
      CancelAllPendings("high-impact news window");

   if(g_basket.active && CountPositions() == 0 && CountPendings() == 0 && InvisibleRecentCount() == 0)
      EndBasket(false, "flat");

   if(!g_basket.active)
      TryStartBasket(tk);
   else if(g_basket.type == BASKET_RANGE && InpRangeRearm && !g_basket.frozen && EntryFiltersOk(tk))
      RearmRange(tk);
  }

//====================================================================
// 12. DASHBOARD
//====================================================================
void UpdateDashboard(const MqlTick &tk)
  {
   if(!InpShowDashboard || MQLInfoInteger(MQL_OPTIMIZATION))
      return;
   uint now = GetTickCount();
   if(now - g_lastDashMs < 1000)
      return;
   g_lastDashMs = now;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   string status = g_hardHalt ? "HALTED (equity hard-stop) - set InpResetHardStop=true to resume"
                   : g_dailyHalt ? "PAUSED (daily loss limit) until next server day"
                   : g_closing ? "CLOSING (" + g_closingReason + ")"
                   : (g_blockReason == "" ? "ACTIVE" : "waiting: " + g_blockReason);
   string basket = "Basket: none";
   if(g_basket.active)
     {
      RefreshRealized();
      double floating = FloatingPL();
      basket = StringFormat("Basket: %s%s  R=%s  X=%.2f\n  Net %.2f (realized %.2f, floating %.2f)  stop %.2f / target %.2f",
                            BasketName(g_basket.type), g_basket.frozen ? " (frozen)" : "",
                            DoubleToString(g_basket.r, g_digits), g_basket.riskMoney,
                            g_realized + floating, g_realized, floating,
                            -g_basket.riskMoney, RR_RATIO * g_basket.riskMoney);
     }
   double dayPL = equity - g_dayStartEquity;
   double dd    = g_peakEquity > 0.0 ? 100.0 * (g_peakEquity - equity) / g_peakEquity : 0.0;
   double dayPct = g_dayStartEquity > 0.0 ? 100.0 * dayPL / g_dayStartEquity : 0.0;
   string text = StringFormat("%s v1.10 | %s | magic %I64d\n", EA_NAME, _Symbol, InpMagic);
   text += StringFormat("Preset %s: X %.1f%%  daily %.1f%%  max DD %.1f%%  RR 1:%.0f\n",
                        PresetName(), g_basketPct, g_dailyPct, g_maxDDPct, RR_RATIO);
   text += StringFormat("Regime: %s (candidate %s %d/%d)  ATR %.2f  spread %.2f\n",
                        RegimeName(g_regime), RegimeName(g_candidate), g_candCount, InpConfirmBars,
                        g_atr, tk.ask - tk.bid);
   text += basket + "\n";
   text += StringFormat("Positions %d  pendings %d\n", CountPositions(), CountPendings());
   text += StringFormat("Day P/L %.2f (%.2f%%)  peak %.2f  DD %.2f%%\n", dayPL, dayPct, g_peakEquity, dd);
   text += "Status: " + status;
   Comment(text);
  }

//====================================================================
// 13. EVENT HANDLERS
//====================================================================
bool ResolvePreset()
  {
   switch(InpRiskPreset)
     {
      case PRESET_CONSERVATIVE:
         g_basketPct = 1.5;
         g_dailyPct  = 3.0;
         g_maxDDPct  = 10.0;
         break;
      case PRESET_BALANCED:
         g_basketPct = 3.0;
         g_dailyPct  = 6.0;
         g_maxDDPct  = 15.0;
         break;
      case PRESET_ROBBINS:
         g_basketPct = 6.0;
         g_dailyPct  = 12.0;
         g_maxDDPct  = 30.0;
         break;
      default:
         g_basketPct = InpCustomBasketPct;
         g_dailyPct  = InpCustomDailyPct;
         g_maxDDPct  = InpCustomMaxDDPct;
         break;
     }
   return g_basketPct > 0.0 && g_basketPct <= 50.0 &&
          g_dailyPct >= g_basketPct && g_dailyPct <= 100.0 &&
          g_maxDDPct >= g_basketPct && g_maxDDPct < 100.0;
  }

bool InputsValid()
  {
   if(InpGridLevels < 1 || InpGridLevels > 10)
      return false;
   if(InpMinSL <= 0.0 || InpMaxSL < InpMinSL)
      return false;
   if(InpATRPeriod < 1 || InpATRAvgBars < 2 || InpADXPeriod < 1 || InpBBPeriod < 2)
      return false;
   if(InpBBWidthLookback < 10 || InpDonchianBars < 3 || InpConfirmBars < 1)
      return false;
   if(InpRangeMinWidthATR <= 0.0 || InpRangeMaxWidthATR < InpRangeMinWidthATR)
      return false;
   if(InpRangeRiskFrac <= 0.0 || InpRangeStepFrac < 0.0 || InpBreakoutSLATR <= 0.0)
      return false;
   if(InpSessionStartHour < 0 || InpSessionStartHour > 24 || InpSessionEndHour < 0 || InpSessionEndHour > 24)
      return false;
   if(InpPendingExpiryBars < 1 || InpBreakoutEntryBars < 1 || InpMaxSpread <= 0.0)
      return false;
   return true;
  }

int OnInit()
  {
   if(!ResolvePreset() || !InputsValid())
     {
      Print("[RGG] Invalid inputs: check risk percentages (0 < X <= daily, X <= max DD), levels 1-10, SL range and periods.");
      return INIT_PARAMETERS_INCORRECT;
     }
   if((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE) != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING)
     {
      Print("[RGG] This EA needs a HEDGING account (grid holds several positions). Netting/exchange accounts are not supported.");
      return INIT_FAILED;
     }
   if(!IsGoldSymbol() && !InpAllowNonGold)
     {
      PrintFormat("[RGG] %s does not look like gold (XAU/GOLD). Set InpAllowNonGold=true to override.", _Symbol);
      return INIT_FAILED;
     }

   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_tick   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(g_tick <= 0.0)
      g_tick = g_point;

   g_hATR = iATR(_Symbol, InpSignalTF, InpATRPeriod);
   g_hADX = iADX(_Symbol, InpContextTF, InpADXPeriod);
   g_hBB  = iBands(_Symbol, InpSignalTF, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
   if(g_hATR == INVALID_HANDLE || g_hADX == INVALID_HANDLE || g_hBB == INVALID_HANDLE)
     {
      Print("[RGG] Failed to create indicator handles.");
      return INIT_FAILED;
     }

   g_marketFilling = DetectMarketFilling();
   g_trade.SetExpertMagicNumber((ulong)InpMagic);
   g_trade.SetDeviationInPoints((ulong)InpSlippagePoints);
   g_trade.SetTypeFilling(g_marketFilling);
   g_trade.SetMarginMode();
   g_trade.LogLevel(LOG_LEVEL_ERRORS);

   bool tester = MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION);
   g_gvPrefix = StringFormat("%s.%s.%I64d.", tester ? "RGGT" : "RGG", _Symbol, InpMagic);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   LoadGuards();
   if(InpResetHardStop && g_hardHalt)
     {
      g_hardHalt   = false;
      g_peakEquity = equity;
      Log("Hard-stop reset by user; peak equity re-based to current equity. Set InpResetHardStop back to false.");
     }
   if(g_peakEquity <= 0.0)
      g_peakEquity = equity;
   if(g_dayStamp != DayStart(TimeCurrent()) || g_dayStartEquity <= 0.0)
     {
      g_dayStamp       = DayStart(TimeCurrent());
      g_dayStartEquity = equity;
      g_dailyHalt      = false;
     }
   SaveGuards();

   LoadRegime();
   ResetBasketStruct();
   LoadBasket();
   if(g_basket.active && CountPositions() == 0 && CountPendings() == 0)
     {
      Log("Stored basket has no live orders - closing it.");
      ResetBasketStruct();
      SaveBasket();
     }
   g_historyDirty = true;
   g_lastBarTime  = 0;
   ArrayInitialize(g_regimeBars, 0);
   ArrayInitialize(g_statBaskets, 0);

   PrintFormat("[RGG] %s started on %s | preset %s X=%.1f%% daily=%.1f%% maxDD=%.1f%% | RR 1:%.0f | levels %d | filling %s",
               EA_NAME, _Symbol, PresetName(), g_basketPct, g_dailyPct, g_maxDDPct, RR_RATIO,
               InpGridLevels, EnumToString(g_marketFilling));
   if(g_hardHalt)
      Print("[RGG] Equity hard-stop is ACTIVE from a previous session. No trading until InpResetHardStop=true.");
   return INIT_SUCCEEDED;
  }

//--- tester diagnostics: where does the P/L come from and how do trades exit?
int BasketTypeOfPosition(const ulong posId, const ulong &ids[], const int &types[])
  {
   for(int i = ArraySize(ids) - 1; i >= 0; i--)
      if(ids[i] == posId)
         return types[i];
   return BASKET_NONE;
  }

void PrintExitStats()
  {
   if(!HistorySelect(0, TimeCurrent() + 60))
      return;
   int   n = HistoryDealsTotal();
   ulong ids[];
   int   types[];
   // pass 1: entry deals -> grid type from the opening order's comment (RGG|R|.. / RGG|B|..)
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY) != DEAL_ENTRY_IN)
         continue;
      ulong  ord = (ulong)HistoryDealGetInteger(d, DEAL_ORDER);
      string c   = HistoryOrderGetString(ord, ORDER_COMMENT);
      if(c == "")
         c = HistoryDealGetString(d, DEAL_COMMENT);
      int k = ArraySize(ids);
      ArrayResize(ids, k + 1);
      ArrayResize(types, k + 1);
      ids[k]   = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      types[k] = (StringFind(c, EA_TAG + "|R|") == 0) ? BASKET_RANGE : BASKET_BREAKOUT;
     }
   // pass 2: exit deals, bucket = type * 4 + reason (0 TP, 1 SL loss, 2 SL >= 0 i.e. break-even, 3 EA close)
   int    cnt[12];
   double pl[12];
   ArrayInitialize(cnt, 0);
   ArrayInitialize(pl, 0.0);
   for(int i = 0; i < n; i++)
     {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || HistoryDealGetInteger(d, DEAL_MAGIC) != InpMagic || HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol)
         continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      double net = HistoryDealGetDouble(d, DEAL_PROFIT) + HistoryDealGetDouble(d, DEAL_SWAP) +
                   HistoryDealGetDouble(d, DEAL_COMMISSION) + HistoryDealGetDouble(d, DEAL_FEE);
      ENUM_DEAL_REASON why = (ENUM_DEAL_REASON)HistoryDealGetInteger(d, DEAL_REASON);
      int r = (why == DEAL_REASON_TP) ? 0 : (why == DEAL_REASON_SL) ? (net < 0.0 ? 1 : 2) : 3;
      int t = BasketTypeOfPosition((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID), ids, types);
      if(t != BASKET_RANGE && t != BASKET_BREAKOUT)
         t = BASKET_BREAKOUT;
      cnt[t * 4 + r]++;
      pl[t * 4 + r] += net;
     }
   Print("[RGG] ================= Exit statistics (excl. entry commission) =================");
   for(int t = BASKET_RANGE; t <= BASKET_BREAKOUT; t++)
     {
      int    total = cnt[t * 4] + cnt[t * 4 + 1] + cnt[t * 4 + 2] + cnt[t * 4 + 3];
      double net   = pl[t * 4] + pl[t * 4 + 1] + pl[t * 4 + 2] + pl[t * 4 + 3];
      PrintFormat("[RGG] %-8s baskets %d trades %d net %.2f | TP %d (%.2f) | SL %d (%.2f) | BE %d (%.2f) | EA-close %d (%.2f)",
                  BasketName(t), g_statBaskets[t], total, net, cnt[t * 4], pl[t * 4], cnt[t * 4 + 1], pl[t * 4 + 1],
                  cnt[t * 4 + 2], pl[t * 4 + 2], cnt[t * 4 + 3], pl[t * 4 + 3]);
     }
   int bars = 0;
   for(int i = 0; i < 5; i++)
      bars += g_regimeBars[i];
   if(bars > 0)
      PrintFormat("[RGG] Regime share of %d bars: RANGE %.1f%% | BREAKOUT %.1f%% | VOLATILE %.1f%% | NEUTRAL %.1f%%",
                  bars, 100.0 * g_regimeBars[REGIME_RANGE] / bars,
                  100.0 * (g_regimeBars[REGIME_BREAKOUT_UP] + g_regimeBars[REGIME_BREAKOUT_DOWN]) / bars,
                  100.0 * g_regimeBars[REGIME_VOLATILE] / bars, 100.0 * g_regimeBars[REGIME_NEUTRAL] / bars);
   PrintFormat("[RGG] Skipped levels: lot below minimum %d | margin %d | risk budget %d | throttled baskets %d",
               g_statSkipLot, g_statSkipMargin, g_statSkipBudget, g_statThrottled);
   PrintFormat("[RGG] Status at end: %s", g_hardHalt ? "HARD-STOP" : g_dailyHalt ? "daily pause" : "running");
  }

// Custom optimisation criterion ("Custom max"): net profit / max equity drawdown.
double OnTester()
  {
   PrintExitStats();
   double dd     = TesterStatistics(STAT_EQUITY_DD);
   double profit = TesterStatistics(STAT_PROFIT);
   return dd > 0.0 ? profit / dd : profit;
  }

void OnDeinit(const int reason)
  {
   if(g_hATR != INVALID_HANDLE)
      IndicatorRelease(g_hATR);
   if(g_hADX != INVALID_HANDLE)
      IndicatorRelease(g_hADX);
   if(g_hBB != INVALID_HANDLE)
      IndicatorRelease(g_hBB);
   Comment("");
  }

void OnTick()
  {
   MqlTick tk;
   if(!SymbolInfoTick(_Symbol, tk) || tk.bid <= 0.0 || tk.ask <= 0.0)
      return;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);

   RefreshDayAndPeak(equity);
   PurgeRecent();

   // portfolio guards first
   bool halted = CheckHardStop(equity);
   if(!halted)
      halted = CheckDailyLoss(equity);
   if(g_closing)
     {
      ProcessClosing();
      UpdateDashboard(tk);
      return;
     }
   if(halted)
     {
      UpdateDashboard(tk);
      return;
     }

   ManagePositions(tk);
   CheckBasket();
   if(g_closing)
     {
      ProcessClosing();
      UpdateDashboard(tk);
      return;
     }

   bool newBar = IsNewBar();
   if(newBar && !UpdateRegime())
      g_lastBarTime = 0; // data not ready: retry on the next tick

   if(newBar || g_tradeDirty || TimeCurrent() - g_lastMaintain >= 15)
     {
      g_tradeDirty   = false;
      g_lastMaintain = TimeCurrent();
      Maintain(tk);
     }
   UpdateDashboard(tk);
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
     {
      g_historyDirty = true;
      g_tradeDirty   = true;
     }
  }
//+------------------------------------------------------------------+
