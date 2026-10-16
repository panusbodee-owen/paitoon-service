//+------------------------------------------------------------------+
//|                                              RobbinsGoldGrid.mq5 |
//|  v2.00 - Trend + Pullback + Confirm grid for XAUUSD (MT5 hedge)  |
//|                                                                  |
//|  - H1 trend filter (EMA50 vs EMA200, EMA50 slope, ADX)           |
//|  - M15 pullback into the EMA20/EMA50 zone with an RSI dip,       |
//|    confirmed by an engulfing or pin-bar candle                   |
//|  - Grid: layer 1 at market after the confirmation bar, layers    |
//|    2..N as limits deeper in the pullback; shared structural SL;  |
//|    every layer TP = 3 x its own risk (RR 1:3)                    |
//|  - Fixed money risk per trade (e.g. lose 5 / win 15)             |
//|  - Stop for the day after N losing trades (default 3)            |
//|                                                                  |
//|  Design: .10x/specs/2026-10-16-gold-grid-ea-v2-design.md         |
//|  Python mirror of the pure logic: gold-grid-ea/sim/rgg.py        |
//+------------------------------------------------------------------+
#property copyright   "paitoon-service"
#property version     "2.00"
#property description "Robbins Gold Grid v2: H1 trend + M15 pullback + candle confirmation, layered entries."
#property description "Every trade SL=1R / TP=3R with a fixed money risk. Stops for the day after N losing trades."
#property description "Hedging accounts only."

#include <Trade\Trade.mqh>

#define RR_RATIO       3.0     // fixed by design - deliberately not an input
#define RR_TOLERANCE   0.01
#define EA_TAG         "RGG"
#define EA_NAME        "Robbins Gold Grid"
#define EA_VERSION     "2.00"
#define RECENT_TTL_SEC 10
#define MAX_LAYERS     5
#define REASONS        8

//====================================================================
// 1. CONFIG
//====================================================================
input group "=== Risk ==="
input double           InpRiskMoney          = 5.0;   // Max loss per trade (account currency); win = 3x
input int              InpMaxLossesPerDay    = 3;     // Stop for the day after this many losing trades
input int              InpGridLevels         = 3;     // Layers per setup (1-5)
input double           InpMaxDDPct           = 0.0;   // Equity hard-stop % from peak (0 = off)
input bool             InpResetHardStop      = false; // Reset a triggered hard-stop when the EA starts

input group "=== Trend filter ==="
input ENUM_TIMEFRAMES  InpTrendTF            = PERIOD_H1; // Trend timeframe
input int              InpTrendFastEMA       = 50;    // Fast EMA
input int              InpTrendSlowEMA       = 200;   // Slow EMA
input int              InpTrendSlopeBars     = 3;     // Fast EMA must rise/fall over N bars
input int              InpADXPeriod          = 14;    // ADX period
input double           InpADXMin             = 20.0;  // Minimum ADX (trend strength)

input group "=== Pullback + confirmation ==="
input ENUM_TIMEFRAMES  InpSignalTF           = PERIOD_M15; // Signal timeframe
input int              InpZoneFastEMA        = 20;    // Zone fast EMA (price must touch it)
input int              InpZoneSlowEMA        = 50;    // Zone slow EMA (close must hold beyond it)
input int              InpPullbackBars       = 6;     // Look-back for touch, RSI dip and swing (2-30)
input int              InpRSIPeriod          = 14;    // RSI period
input double           InpRSIPullback        = 40.0;  // Buy: RSI dipped <= this; sell: >= 100 - this
input double           InpPinWickRatio       = 2.0;   // Pin bar: wick >= ratio x body
input int              InpATRPeriod          = 14;    // ATR period
input int              InpATRAvgBars         = 96;    // Bars for the average ATR
input double           InpVolatileATRMult    = 2.0;   // Skip when ATR > mult x average ATR
input double           InpSLBufferATR        = 0.2;   // SL beyond the pullback swing by x ATR
input double           InpMaxSLATR           = 3.0;   // Skip setups with SL wider than x ATR
input int              InpSignalMaxDelaySec  = 120;   // Enter only this soon after the confirmation bar

input group "=== Grid layers ==="
input double           InpLayerStepR         = 0.3;   // Layer k entry = E1 -/+ k x step x R1
input int              InpLayerExpiryBars    = 8;     // Delete unfilled layers after N signal bars
input double           InpMinSL              = 1.0;   // Minimum SL distance per layer (price units)
input double           InpMaxSL              = 20.0;  // Maximum SL distance (price units)
input bool             InpUseBreakEven       = false; // Move SL to break-even after +1R (off = pure -1R/+3R)
input double           InpBreakEvenBufferR   = 0.05;  // Break-even buffer (x R)
input int              InpCooldownBars       = 1;     // Signal bars to wait after a setup ends

input group "=== Filters ==="
input double           InpMaxSpread          = 0.50;  // Max spread for new trades (price units)
input int              InpSessionStartHour   = 7;     // Trading session start (server hour, inclusive)
input int              InpSessionEndHour     = 21;    // Trading session end (server hour, exclusive)
input bool             InpAvoidRollover      = true;  // No new trades 23:00-01:00 server time
input int              InpFridayCutoffHour   = 20;    // Friday: no new trades from this hour
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
struct SetupState
  {
   bool              active;
   int               dir;         // +1 buy, -1 sell
   datetime          start;
   double            entry1;
   double            sl;          // shared structural SL
   double            r1;
   double            budget;      // worst case for the setup = layers x InpRiskMoney
   int               layers;
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
int                     g_hTrendFast = INVALID_HANDLE;
int                     g_hTrendSlow = INVALID_HANDLE;
int                     g_hADX       = INVALID_HANDLE;
int                     g_hZoneFast  = INVALID_HANDLE;
int                     g_hZoneSlow  = INVALID_HANDLE;
int                     g_hRSI       = INVALID_HANDLE;
int                     g_hATR       = INVALID_HANDLE;
string                  g_gvPrefix   = "";
double                  g_point      = 0.0;
double                  g_tick       = 0.0;
int                     g_digits     = 0;
ENUM_ORDER_TYPE_FILLING g_marketFilling = ORDER_FILLING_FOK;

// chart reading
int                     g_trend      = 0;
bool                    g_trendValid = false;
double                  g_adx        = 0.0;
double                  g_atr        = 0.0;
datetime                g_lastBarTime = 0;
datetime                g_lastEvalBar = 0;
string                  g_lastSignalNote = "-";

// guards (persisted)
double                  g_peakEquity     = 0.0;
double                  g_dayStartEquity = 0.0;
datetime                g_dayStamp       = 0;
bool                    g_dailyHalt      = false;
bool                    g_hardHalt       = false;
datetime                g_cooldownUntil  = 0;
int                     g_lossesToday    = 0;
bool                    g_lossesDirty    = true;

// setup (persisted)
SetupState              g_setup;
double                  g_realized      = 0.0;
int                     g_setupExits    = 0;
bool                    g_historyDirty  = true;
datetime                g_lastSetupEnd  = 0;

// closing state machine
bool                    g_closing         = false;
string                  g_closingReason   = "";
bool                    g_closingCooldown = false;

// misc
RecentOrder             g_recent[];
ulong                   g_rrChecked[];
bool                    g_tradeDirty    = true;
datetime                g_lastMaintain  = 0;
datetime                g_newsCheckedAt = 0;
bool                    g_newsActive    = false;
string                  g_blockReason   = "";
uint                    g_lastDashMs    = 0;

// tester statistics (printed by OnTester)
int                     g_statReasons[REASONS];
int                     g_statSetups     = 0;
int                     g_statLayers[MAX_LAYERS];
int                     g_statSkipR      = 0;
int                     g_statSkipLot    = 0;
int                     g_statSkipMargin = 0;
int                     g_statSkipBudget = 0;
int                     g_statLossDays   = 0;

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

// Round DOWN to the volume step. Below the broker minimum -> 0 (skip the trade, never round up).
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

string TrendName(const int t)
  {
   if(t > 0)
      return "UP";
   if(t < 0)
      return "DOWN";
   return "NONE";
  }

bool IsGoldSymbol()
  {
   string s = _Symbol;
   StringToUpper(s);
   return StringFind(s, "XAU") >= 0 || StringFind(s, "GOLD") >= 0;
  }

string LayerComment(const int dir, const int layer)
  {
   return StringFormat("%s|L|%s|%d", EA_TAG, dir > 0 ? "B" : "S", layer);
  }

int LayerOfComment(const string comment)
  {
   string parts[];
   if(StringSplit(comment, '|', parts) < 4 || parts[0] != EA_TAG)
      return -1;
   return (int)StringToInteger(parts[3]);
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

void SaveSetup()
  {
   GVSet("sAct", g_setup.active ? 1.0 : 0.0);
   GVSet("sDir", (double)g_setup.dir);
   GVSet("sStart", (double)g_setup.start);
   GVSet("sE1", g_setup.entry1);
   GVSet("sSL", g_setup.sl);
   GVSet("sR1", g_setup.r1);
   GVSet("sBud", g_setup.budget);
   GVSet("sLay", (double)g_setup.layers);
  }

void LoadSetup()
  {
   g_setup.active = GVGet("sAct", 0.0) > 0.5;
   g_setup.dir    = (int)GVGet("sDir", 0.0);
   g_setup.start  = (datetime)(long)GVGet("sStart", 0.0);
   g_setup.entry1 = GVGet("sE1", 0.0);
   g_setup.sl     = GVGet("sSL", 0.0);
   g_setup.r1     = GVGet("sR1", 0.0);
   g_setup.budget = GVGet("sBud", 0.0);
   g_setup.layers = (int)GVGet("sLay", 0.0);
  }

void ResetSetupStruct()
  {
   g_setup.active = false;
   g_setup.dir    = 0;
   g_setup.start  = 0;
   g_setup.entry1 = 0.0;
   g_setup.sl     = 0.0;
   g_setup.r1     = 0.0;
   g_setup.budget = 0.0;
   g_setup.layers = 0;
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

bool RrChecked(const ulong ticket)
  {
   for(int i = ArraySize(g_rrChecked) - 1; i >= 0; i--)
      if(g_rrChecked[i] == ticket)
         return true;
   return false;
  }

void MarkRrChecked(const ulong ticket)
  {
   int n = ArraySize(g_rrChecked);
   if(n >= 64)
     {
      ArrayRemove(g_rrChecked, 0, 1);
      n--;
     }
   ArrayResize(g_rrChecked, n + 1);
   g_rrChecked[n] = ticket;
  }

//====================================================================
// 6. RISK
//====================================================================
// Broker-exact money for a price move (contract size, tick value, account currency).
bool ProfitAt(const int dir, const double volume, const double openPrice,
              const double closePrice, double &profit)
  {
   profit = 0.0;
   ENUM_ORDER_TYPE t = dir > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   return OrderCalcProfit(t, _Symbol, volume, openPrice, closePrice, profit);
  }

// Layer with a fixed (structural) SL: TP = entry + 3 x own risk, ratio verified after
// normalization. Mirrors rgg.make_layer_order().
bool MakeLayerOrder(const int dir, const double rawEntry, const double rawSl, const double minRisk,
                    double &entry, double &sl, double &tp)
  {
   entry = NormPrice(rawEntry);
   sl    = NormPrice(rawSl);
   double risk = dir * (entry - sl);
   if(risk <= 0.0 || risk < minRisk)
      return false;
   tp = NormPrice(entry + dir * RR_RATIO * risk);
   return MathAbs(MathAbs(tp - entry) / risk - RR_RATIO) <= RR_TOLERANCE;
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

// Realized P/L and number of exits of the active setup (from deal history).
void RefreshRealized()
  {
   if(!g_historyDirty)
      return;
   g_realized   = 0.0;
   g_setupExits = 0;
   if(!g_setup.active)
     {
      g_historyDirty = false;
      return;
     }
   if(!HistorySelect(g_setup.start, TimeCurrent() + 60))
      return; // stays dirty, retried next call
   g_historyDirty = false;
   int n = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      g_realized += HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) +
                    HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
         g_setupExits++;
     }
  }

// Losing trades today = exit deals of the EA since server-day start with net < 0.
void RefreshDailyLosses()
  {
   if(!g_lossesDirty)
      return;
   if(!HistorySelect(g_dayStamp, TimeCurrent() + 60))
      return;
   g_lossesDirty = false;
   int losses = 0;
   int n      = HistoryDealsTotal();
   for(int i = 0; i < n; i++)
     {
      ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagic || HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY)
         continue;
      double net = HistoryDealGetDouble(deal, DEAL_PROFIT) + HistoryDealGetDouble(deal, DEAL_SWAP) +
                   HistoryDealGetDouble(deal, DEAL_COMMISSION) + HistoryDealGetDouble(deal, DEAL_FEE);
      if(net < 0.0)
         losses++;
     }
   g_lossesToday = losses;
  }

// Layers for a new setup never exceed the losing trades still allowed today
// (layers share one SL, so they usually lose together). Mirrors rgg.layers_allowed().
int LayersAllowed()
  {
   RefreshDailyLosses();
   return MathMax(0, MathMin(InpGridLevels, InpMaxLossesPerDay - g_lossesToday));
  }

// realized + P/L if every open position and pending order of the EA hits its SL.
bool WorstCaseSetup(double &worst)
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

// The setup can never be built to lose more than layers x InpRiskMoney.
bool RiskBudgetAllows(const double plAtSlNew)
  {
   if(!g_setup.active)
      return false;
   RefreshRealized();
   double worst = 0.0;
   if(!WorstCaseSetup(worst))
      return false;
   return worst + plAtSlNew >= -g_setup.budget * 1.0001;
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

bool PlaceMarket(const int dir, const double volume, const double sl, const double tp,
                 const string comment, ulong &ticket)
  {
   ticket = 0;
   for(int attempt = 0; attempt < 3; attempt++)
     {
      g_trade.SetTypeFilling(g_marketFilling);
      bool ok = dir > 0 ? g_trade.Buy(volume, _Symbol, 0.0, sl, tp, comment)
                : g_trade.Sell(volume, _Symbol, 0.0, sl, tp, comment);
      uint rc = g_trade.ResultRetcode();
      if(ok && (rc == TRADE_RETCODE_DONE || rc == TRADE_RETCODE_DONE_PARTIAL || rc == TRADE_RETCODE_PLACED))
        {
         ticket = g_trade.ResultOrder();
         Log(StringFormat("%s %.2f @ %s SL %s TP %s [%s]", dir > 0 ? "BUY" : "SELL", volume,
                          DoubleToString(g_trade.ResultPrice(), g_digits), DoubleToString(sl, g_digits),
                          DoubleToString(tp, g_digits), comment));
         return true;
        }
      if(rc == TRADE_RETCODE_INVALID_FILL)
        {
         g_marketFilling = NextFilling(g_marketFilling);
         continue;
        }
      if(!IsRetryable(rc))
        {
         Log(StringFormat("Market order rejected (%u %s) [%s]", rc, g_trade.ResultRetcodeDescription(), comment));
         break;
        }
     }
   return false;
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
         g_trade.SetTypeFilling(g_marketFilling);
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
      Log(StringFormat("Cancelled %d pending layer(s): %s", n, reason));
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
// 8. SETUP LIFECYCLE + GUARDS
//====================================================================
void BeginSetup(const int dir, const double e1, const double sl, const double r1, const int layers)
  {
   datetime start = TimeCurrent();
   if(start <= g_lastSetupEnd)
      start = g_lastSetupEnd + 1; // keep the previous setup's closing deals out of this one
   g_setup.active = true;
   g_setup.dir    = dir;
   g_setup.start  = start;
   g_setup.entry1 = e1;
   g_setup.sl     = sl;
   g_setup.r1     = r1;
   g_setup.layers = layers;
   g_setup.budget = layers * InpRiskMoney;
   g_realized     = 0.0;
   g_setupExits   = 0;
   g_historyDirty = true;
   g_statSetups++;
   SaveSetup();
   Log(StringFormat("Setup START %s | E1 %s SL %s R1 %s | layers %d | risk %.2f per trade (losses today %d/%d)",
                    dir > 0 ? "BUY" : "SELL", DoubleToString(e1, g_digits), DoubleToString(sl, g_digits),
                    DoubleToString(r1, g_digits), layers, InpRiskMoney, g_lossesToday, InpMaxLossesPerDay));
  }

void EndSetup(const bool cooldown, const string reason)
  {
   if(!g_setup.active)
      return;
   g_historyDirty = true;
   RefreshRealized();
   Log(StringFormat("Setup END (%s) | net %.2f", reason, g_realized));
   ResetSetupStruct();
   SaveSetup();
   g_lastSetupEnd = TimeCurrent();
   g_realized     = 0.0;
   g_setupExits   = 0;
   g_historyDirty = true;
   if(cooldown)
     {
      g_cooldownUntil = TimeCurrent() + InpCooldownBars * PeriodSeconds(InpSignalTF);
      SaveGuards();
     }
  }

// Nothing could be placed: end the empty setup and wait one bar.
void AbortSetup(const string reason)
  {
   EndSetup(false, reason);
   g_cooldownUntil = TimeCurrent() + PeriodSeconds(InpSignalTF);
   SaveGuards();
  }

void RequestCloseAll(const string reason, const bool cooldown)
  {
   if(!g_closing)
      Log("Close-all requested: " + reason);
   g_closing         = true;
   g_closingReason   = reason;
   g_closingCooldown = cooldown;
  }

// Retries every tick until flat, then ends the setup.
void ProcessClosing()
  {
   if(!g_closing)
      return;
   CloseAllAndCancel(g_closingReason);
   if(CountPositions() == 0 && CountPendings() == 0)
     {
      g_closing = false;
      EndSetup(g_closingCooldown, g_closingReason);
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
      g_lossesToday    = 0;
      g_lossesDirty    = true;
      SaveGuards();
      Log(StringFormat("New trading day, start equity %.2f", equity));
     }
   if(equity > g_peakEquity)
     {
      g_peakEquity = equity;
      GVSet("peak", g_peakEquity);
     }
  }

// Optional (InpMaxDDPct > 0): stop for good at a drawdown from the equity peak.
bool CheckHardStop(const double equity)
  {
   if(InpMaxDDPct <= 0.0)
      return false;
   if(!g_hardHalt && g_peakEquity > 0.0 && equity <= g_peakEquity * (1.0 - InpMaxDDPct / 100.0))
     {
      g_hardHalt = true;
      SaveGuards();
      Notify(StringFormat("EQUITY HARD-STOP: equity %.2f is %.1f%% below peak %.2f. Trading halted until reset.",
                          equity, InpMaxDDPct, g_peakEquity));
      RequestCloseAll("equity hard-stop", false);
     }
   if(g_hardHalt && (CountPositions() > 0 || CountPendings() > 0))
      RequestCloseAll("equity hard-stop", false);
   return g_hardHalt;
  }

// User rule: after InpMaxLossesPerDay losing trades, stop until the next server day.
bool CheckDailyLosses()
  {
   RefreshDailyLosses();
   if(!g_dailyHalt && g_lossesToday >= InpMaxLossesPerDay)
     {
      g_dailyHalt = true;
      g_statLossDays++;
      SaveGuards();
      Notify(StringFormat("%d losing trades today - stopped until the next server day.", g_lossesToday));
      RequestCloseAll("daily losing-trade limit", false);
     }
   if(g_dailyHalt && (CountPositions() > 0 || CountPendings() > 0))
      RequestCloseAll("daily losing-trade limit", false);
   return g_dailyHalt;
  }

// Backstop for gaps/slippage beyond the SLs (10% slack for commissions).
void CheckSetupBackstop()
  {
   if(!g_setup.active || g_closing || g_setup.budget <= 0.0)
      return;
   RefreshRealized();
   double net = g_realized + FloatingPL();
   if(net <= -g_setup.budget * 1.10)
     {
      Notify(StringFormat("Setup backstop: net %.2f below -%.2f (gap/slippage). Closing the setup.", net, g_setup.budget));
      RequestCloseAll("setup backstop", true);
     }
  }

// Every position keeps SL + TP at exactly 1:3 (SL repair, TP re-aligned after slippage),
// plus the optional break-even.
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
         double nsl = (g_setup.active && g_setup.dir == dir && dir * (open - g_setup.sl) > 0.0)
                      ? g_setup.sl : NormPrice(open - dir * MathMax(InpMinSL, minDist));
         double ntp = NormPrice(open + dir * RR_RATIO * MathAbs(open - nsl));
         bool beyond = dir > 0 ? (px <= nsl + minDist) : (px >= nsl - minDist);
         if(beyond || !ModifyPosition(ticket, nsl, ntp))
            ClosePositionTicket(ticket, "missing SL could not be set");
         else
            Log(StringFormat("Repaired missing SL on #%I64u", ticket));
         continue;
        }

      double risk = dir * (open - sl);
      if(risk > 0.0 && !RrChecked(ticket))
        {
         // RR integrity: TP = open + 3 x (open - SL) from the ACTUAL fill price (mirrors rgg.rr_repair_tp)
         double want = NormPrice(open + dir * RR_RATIO * risk);
         if(tp <= 0.0 || MathAbs(tp - want) > MathMax(g_tick, 0.005 * risk))
           {
            if(ModifyPosition(ticket, sl, want))
               Log(StringFormat("RR re-aligned on #%I64u: TP %s -> %s", ticket,
                                DoubleToString(tp, g_digits), DoubleToString(want, g_digits)));
           }
         MarkRrChecked(ticket);
         continue;
        }

      if(InpUseBreakEven && risk > 0.0 && dir * (px - open) >= risk)
        {
         double nsl = NormPrice(open + dir * InpBreakEvenBufferR * risk);
         bool   ok  = dir > 0 ? (px - nsl >= minDist) : (nsl - px >= minDist);
         if(ok && ModifyPosition(ticket, nsl, tp))
            Log(StringFormat("Break-even on #%I64u -> %s", ticket, DoubleToString(nsl, g_digits)));
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
      g_blockReason = "daily losing-trade limit";
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
// 10. CHART READING
//====================================================================
// H1 trend: +1 up, -1 down, 0 none. Mirrors rgg.trend_state().
int TrendState(const double emaFast, const double emaSlow, const double emaFastPrev, const double adx)
  {
   if(adx < InpADXMin)
      return 0;
   if(emaFast > emaSlow && emaFast > emaFastPrev)
      return 1;
   if(emaFast < emaSlow && emaFast < emaFastPrev)
      return -1;
   return 0;
  }

bool UpdateTrend()
  {
   int    need = InpTrendSlopeBars + 1;
   double fast[], slow[], adx[];
   ArraySetAsSeries(fast, true);
   ArraySetAsSeries(slow, true);
   ArraySetAsSeries(adx, true);
   if(CopyBuffer(g_hTrendFast, 0, 1, need, fast) < need || CopyBuffer(g_hTrendSlow, 0, 1, 1, slow) < 1 ||
      CopyBuffer(g_hADX, 0, 1, 1, adx) < 1)
      return false;
   int prev = g_trend;
   g_adx        = adx[0];
   g_trend      = TrendState(fast[0], slow[0], fast[need - 1], g_adx);
   g_trendValid = true;
   if(prev != g_trend)
      Log(StringFormat("H1 trend %s -> %s (ADX %.1f)", TrendName(prev), TrendName(g_trend), g_adx));
   return true;
  }

// Engulfing or pin bar (hammer). Mirrors rgg.bullish_confirm().
bool BullishConfirm(const MqlRates &c, const MqlRates &p)
  {
   double range = c.high - c.low;
   if(range <= 0.0)
      return false;
   double body      = MathAbs(c.close - c.open);
   bool   engulf    = c.close > c.open && p.close < p.open && c.close >= p.open && c.open <= p.close;
   double lowerWick = MathMin(c.open, c.close) - c.low;
   bool   pin       = lowerWick >= InpPinWickRatio * body && lowerWick >= 0.5 * range &&
                      c.close >= c.low + 0.6 * range;
   return engulf || pin;
  }

// Engulfing or pin bar (shooting star). Mirrors rgg.bearish_confirm().
bool BearishConfirm(const MqlRates &c, const MqlRates &p)
  {
   double range = c.high - c.low;
   if(range <= 0.0)
      return false;
   double body      = MathAbs(c.close - c.open);
   bool   engulf    = c.close < c.open && p.close > p.open && c.close <= p.open && c.open >= p.close;
   double upperWick = c.high - MathMax(c.open, c.close);
   bool   pin       = upperWick >= InpPinWickRatio * body && upperWick >= 0.5 * range &&
                      c.close <= c.high - 0.6 * range;
   return engulf || pin;
  }

int ReasonIndex(const string why)
  {
   if(why == "no trend")
      return 0;
   if(why == "volatile")
      return 1;
   if(why == "no pullback to zone")
      return 2;
   if(why == "rsi")
      return 3;
   if(why == "zone broken")
      return 4;
   if(why == "no confirmation candle")
      return 5;
   if(why == "signal")
      return 6;
   return 7; // data
  }

// Pullback in the trend direction confirmed by the last CLOSED bar.
// Series newest first: index 0 = shift 1. Mirrors rgg.detect_signal().
bool DetectSignal(const int trend, double &sl, double &atrNow, string &why)
  {
   sl     = 0.0;
   atrNow = 0.0;
   if(trend == 0)
     {
      why = "no trend";
      return false;
     }
   int n       = InpPullbackBars;
   int atrBars = MathMax(InpATRAvgBars, 2);
   MqlRates r[];
   double   emaF[], emaS[], rsi[], atr[];
   ArraySetAsSeries(r, true);
   ArraySetAsSeries(emaF, true);
   ArraySetAsSeries(emaS, true);
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(atr, true);
   if(CopyRates(_Symbol, InpSignalTF, 1, n, r) < n || CopyBuffer(g_hZoneFast, 0, 1, n, emaF) < n ||
      CopyBuffer(g_hZoneSlow, 0, 1, n, emaS) < n || CopyBuffer(g_hRSI, 0, 1, n, rsi) < n ||
      CopyBuffer(g_hATR, 0, 1, atrBars, atr) < atrBars)
     {
      why = "data";
      return false;
     }
   double sum = 0.0;
   for(int i = 0; i < atrBars; i++)
      sum += atr[i];
   atrNow = atr[0];
   g_atr  = atrNow;
   if(atrNow > InpVolatileATRMult * (sum / atrBars))
     {
      why = "volatile";
      return false;
     }

   bool   touched = false;
   bool   rsiOk   = false;
   bool   held    = false;
   bool   candle  = false;
   double extreme = 0.0;
   if(trend > 0)
     {
      extreme       = r[0].low;
      double rsiMin = rsi[0];
      for(int k = 0; k < n; k++)
        {
         if(r[k].low <= emaF[k])
            touched = true;
         extreme = MathMin(extreme, r[k].low);
         rsiMin  = MathMin(rsiMin, rsi[k]);
        }
      rsiOk  = rsiMin <= InpRSIPullback && rsi[0] > rsi[1];
      held   = r[0].close > emaS[0];
      candle = BullishConfirm(r[0], r[1]);
      sl     = extreme - InpSLBufferATR * atrNow;
     }
   else
     {
      extreme       = r[0].high;
      double rsiMax = rsi[0];
      for(int k = 0; k < n; k++)
        {
         if(r[k].high >= emaF[k])
            touched = true;
         extreme = MathMax(extreme, r[k].high);
         rsiMax  = MathMax(rsiMax, rsi[k]);
        }
      rsiOk  = rsiMax >= 100.0 - InpRSIPullback && rsi[0] < rsi[1];
      held   = r[0].close < emaS[0];
      candle = BearishConfirm(r[0], r[1]);
      sl     = extreme + InpSLBufferATR * atrNow;
     }
   if(!touched)
      why = "no pullback to zone";
   else if(!rsiOk)
      why = "rsi";
   else if(!held)
      why = "zone broken";
   else if(!candle)
      why = "no confirmation candle";
   else
      why = "signal";
   return why == "signal";
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
bool PendingValid(const int dir, const double entry, const MqlTick &tk, const double minDist)
  {
   return dir > 0 ? entry <= tk.ask - minDist : entry >= tk.bid + minDist;
  }

// Layer 0 = market order, layers 1..N-1 = limit orders; each risks at most InpRiskMoney.
bool PlaceLayer(const int layer, const int dir, const double rawEntry, const double rawSl, const MqlTick &tk)
  {
   double minDist = MinStopDistance();
   double entry = 0.0, sl = 0.0, tp = 0.0;
   if(!MakeLayerOrder(dir, rawEntry, rawSl, MathMax(InpMinSL, minDist), entry, sl, tp))
      return false;
   bool isMarket = (layer == 0);
   if(!isMarket && !PendingValid(dir, entry, tk, minDist))
      return false;
   double lots = LotForRisk(dir, entry, sl, InpRiskMoney);
   if(lots <= 0.0)
     {
      g_statSkipLot++;
      Log(StringFormat("Layer %d skipped: the minimum lot would lose more than %.2f with SL %s away",
                       layer, InpRiskMoney, DoubleToString(MathAbs(entry - sl), g_digits)));
      return false;
     }
   if(!MarginOk(dir, lots, entry))
     {
      g_statSkipMargin++;
      Log(StringFormat("Layer %d skipped: not enough free margin for %.2f lots", layer, lots));
      return false;
     }
   double plAtSl = 0.0;
   if(!ProfitAt(dir, lots, entry, sl, plAtSl))
      return false;
   if(!RiskBudgetAllows(plAtSl))
     {
      g_statSkipBudget++;
      Log(StringFormat("Layer %d skipped: setup risk budget %.2f would be exceeded", layer, g_setup.budget));
      return false;
     }
   ulong  ticket  = 0;
   string comment = LayerComment(dir, layer);
   bool   ok      = isMarket ? PlaceMarket(dir, lots, sl, tp, comment, ticket)
                    : PlacePending(dir > 0 ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT, lots, entry, sl, tp, comment, ticket);
   if(!ok)
      return false;
   if(layer >= 0 && layer < MAX_LAYERS)
      g_statLayers[layer]++;
   if(ticket > 0)
      AddRecent(ticket, dir, entry, plAtSl);
   return true;
  }

void StartSetup(const int dir, const double rawSl, const double atr, const MqlTick &tk)
  {
   double e1      = dir > 0 ? tk.ask : tk.bid;
   double sl      = NormPrice(rawSl);
   double r1      = dir * (e1 - sl);
   double minDist = MinStopDistance();
   if(r1 < MathMax(InpMinSL, minDist) || r1 > InpMaxSL || r1 > InpMaxSLATR * atr)
     {
      g_statSkipR++;
      Log(StringFormat("Signal %s skipped: SL distance %.2f outside [%.2f, min(%.2f, %.1f x ATR %.2f)]",
                       dir > 0 ? "BUY" : "SELL", r1, MathMax(InpMinSL, minDist), InpMaxSL, InpMaxSLATR, atr));
      return;
     }
   int layers = LayersAllowed();
   if(layers <= 0)
      return;
   BeginSetup(dir, e1, sl, r1, layers);
   int placed = 0;
   for(int k = 0; k < layers; k++)
     {
      double entry = e1 - dir * k * InpLayerStepR * r1;
      if(PlaceLayer(k, dir, entry, sl, tk))
         placed++;
     }
   if(placed == 0)
      AbortSetup("no layer fits the risk per trade");
  }

// Each closed signal bar is evaluated once, within InpSignalMaxDelaySec of its close.
void TryStartSetup(const MqlTick &tk)
  {
   if(g_setup.active || g_closing)
      return;
   datetime bar0 = iTime(_Symbol, InpSignalTF, 0);
   if(bar0 == 0 || bar0 == g_lastEvalBar)
      return;
   if(TimeCurrent() - bar0 > InpSignalMaxDelaySec)
     {
      g_lastEvalBar = bar0; // too late in the bar: wait for the next one
      return;
     }
   if(TimeCurrent() < g_cooldownUntil)
     {
      g_blockReason = "cooldown";
      return;
     }
   if(!EntryFiltersOk(tk))
      return; // retried while still inside the delay window
   if(!g_trendValid && !UpdateTrend())
      return;
   g_lastEvalBar = bar0;
   double sl  = 0.0;
   double atr = 0.0;
   string why = "";
   bool   sig = DetectSignal(g_trend, sl, atr, why);
   g_lastSignalNote = why;
   g_statReasons[ReasonIndex(why)]++;
   if(why == "data")
      g_lastEvalBar = 0; // indicators not ready: retry
   if(sig)
      StartSetup(g_trend, sl, atr, tk);
  }

void Maintain(const MqlTick &tk)
  {
   if(g_setup.active && CountPendings() > 0)
     {
      RefreshRealized();
      string reason = "";
      if(g_setupExits > 0)
         reason = "a layer of the setup closed";
      else if(TimeCurrent() - g_setup.start >= InpLayerExpiryBars * PeriodSeconds(InpSignalTF))
         reason = "layers expired";
      else if(g_trendValid && g_trend != g_setup.dir)
         reason = "H1 trend changed";
      if(reason != "")
         CancelAllPendings(reason);
     }

   if(IsFridayCutoff(TimeCurrent()) && InpCloseAllFriday && CountPositions() > 0)
     {
      RequestCloseAll("Friday close", false);
      return;
     }
   if(!InSession(TimeCurrent()) && CountPendings() > 0)
      CancelAllPendings("outside trading session");
   if(NewsWindowActive() && CountPendings() > 0)
      CancelAllPendings("high-impact news window");

   if(g_setup.active && CountPositions() == 0 && CountPendings() == 0 && InvisibleRecentCount() == 0)
      EndSetup(true, "flat");

   if(!g_setup.active)
      TryStartSetup(tk);
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
   double dayPL  = equity - g_dayStartEquity;
   double dayPct = g_dayStartEquity > 0.0 ? 100.0 * dayPL / g_dayStartEquity : 0.0;
   string status = g_hardHalt ? "HALTED (equity hard-stop) - set InpResetHardStop=true to resume"
                   : g_dailyHalt ? "STOPPED FOR TODAY (losing-trade limit)"
                   : g_closing ? "CLOSING (" + g_closingReason + ")"
                   : (g_blockReason == "" ? "ACTIVE" : "waiting: " + g_blockReason);
   string setup = "Setup: none (last bar: " + g_lastSignalNote + ")";
   if(g_setup.active)
     {
      RefreshRealized();
      setup = StringFormat("Setup: %s  E1 %s  SL %s  R1 %s | layers %d | net %.2f",
                           g_setup.dir > 0 ? "BUY" : "SELL", DoubleToString(g_setup.entry1, g_digits),
                           DoubleToString(g_setup.sl, g_digits), DoubleToString(g_setup.r1, g_digits),
                           g_setup.layers, g_realized + FloatingPL());
     }
   string text = StringFormat("%s v%s | %s | magic %I64d\n", EA_NAME, EA_VERSION, _Symbol, InpMagic);
   text += StringFormat("Risk %.2f per trade (win %.2f) | layers %d | stop after %d losses/day\n",
                        InpRiskMoney, RR_RATIO * InpRiskMoney, InpGridLevels, InpMaxLossesPerDay);
   text += StringFormat("%s trend: %s (ADX %.1f) | ATR %.2f | spread %.2f\n",
                        EnumToString(InpTrendTF), TrendName(g_trend), g_adx, g_atr, tk.ask - tk.bid);
   text += setup + "\n";
   text += StringFormat("Positions %d  pendings %d\n", CountPositions(), CountPendings());
   text += StringFormat("Today: losses %d/%d | P/L %.2f (%.2f%%)\n", g_lossesToday, InpMaxLossesPerDay, dayPL, dayPct);
   text += "Status: " + status;
   Comment(text);
  }

//====================================================================
// 13. TESTER DIAGNOSTICS
//====================================================================
int LayerOfPosition(const ulong posId, const ulong &ids[], const int &layers[])
  {
   for(int i = ArraySize(ids) - 1; i >= 0; i--)
      if(ids[i] == posId)
         return layers[i];
   return 0;
  }

void PrintExitStats()
  {
   string names[REASONS] = {"no trend", "volatile", "no pullback", "rsi", "zone broken", "no candle", "SIGNAL", "data"};
   string line = "[RGG] Bars evaluated:";
   for(int i = 0; i < REASONS; i++)
      line += StringFormat(" %s %d |", names[i], g_statReasons[i]);
   Print(line);
   PrintFormat("[RGG] Setups %d | signals skipped for SL distance %d | layers placed L1 %d L2 %d L3 %d L4 %d L5 %d",
               g_statSetups, g_statSkipR, g_statLayers[0], g_statLayers[1], g_statLayers[2], g_statLayers[3], g_statLayers[4]);
   PrintFormat("[RGG] Layers skipped: lot above risk %d | margin %d | budget %d | days stopped by loss limit %d",
               g_statSkipLot, g_statSkipMargin, g_statSkipBudget, g_statLossDays);

   if(!HistorySelect(0, TimeCurrent() + 60))
      return;
   int   n = HistoryDealsTotal();
   ulong ids[];
   int   layers[];
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
      ArrayResize(layers, k + 1);
      ids[k]    = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      layers[k] = MathMax(0, MathMin(MAX_LAYERS - 1, LayerOfComment(c)));
     }
   // bucket = layer * 3 + reason (0 TP, 1 SL, 2 other)
   int    cnt[MAX_LAYERS * 3];
   double pl[MAX_LAYERS * 3];
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
      int r = (why == DEAL_REASON_TP) ? 0 : (why == DEAL_REASON_SL) ? 1 : 2;
      int k = LayerOfPosition((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID), ids, layers);
      cnt[k * 3 + r]++;
      pl[k * 3 + r] += net;
     }
   for(int k = 0; k < MathMin(InpGridLevels, MAX_LAYERS); k++)
     {
      int total = cnt[k * 3] + cnt[k * 3 + 1] + cnt[k * 3 + 2];
      if(total == 0)
         continue;
      PrintFormat("[RGG] Layer %d: trades %d | TP %d (%.2f) | SL %d (%.2f) | other %d (%.2f) | TP rate %.1f%% (break-even 25%%)",
                  k + 1, total, cnt[k * 3], pl[k * 3], cnt[k * 3 + 1], pl[k * 3 + 1], cnt[k * 3 + 2], pl[k * 3 + 2],
                  100.0 * cnt[k * 3] / total);
     }
  }

// Custom optimisation criterion ("Custom max"): net profit / max equity drawdown.
double OnTester()
  {
   PrintExitStats();
   double dd     = TesterStatistics(STAT_EQUITY_DD);
   double profit = TesterStatistics(STAT_PROFIT);
   return dd > 0.0 ? profit / dd : profit;
  }

//====================================================================
// 14. EVENT HANDLERS
//====================================================================
bool InputsValid()
  {
   if(InpRiskMoney <= 0.0 || InpMaxLossesPerDay < 1 || InpMaxLossesPerDay > 50)
      return false;
   if(InpGridLevels < 1 || InpGridLevels > MAX_LAYERS)
      return false;
   if(InpLayerStepR <= 0.0 || (InpGridLevels - 1) * InpLayerStepR >= 0.95)
      return false;
   if(InpMaxDDPct < 0.0 || InpMaxDDPct >= 100.0)
      return false;
   if(InpTrendFastEMA < 1 || InpTrendSlowEMA <= InpTrendFastEMA || InpTrendSlopeBars < 1 || InpADXPeriod < 1)
      return false;
   if(InpZoneFastEMA < 1 || InpZoneSlowEMA <= InpZoneFastEMA || InpRSIPeriod < 2)
      return false;
   if(InpPullbackBars < 2 || InpPullbackBars > 30 || InpRSIPullback <= 0.0 || InpRSIPullback >= 50.0)
      return false;
   if(InpATRPeriod < 1 || InpATRAvgBars < 2 || InpPinWickRatio <= 0.0 || InpMaxSLATR <= 0.0)
      return false;
   if(InpMinSL <= 0.0 || InpMaxSL < InpMinSL || InpLayerExpiryBars < 1 || InpSignalMaxDelaySec < 10)
      return false;
   if(InpSessionStartHour < 0 || InpSessionStartHour > 24 || InpSessionEndHour < 0 || InpSessionEndHour > 24)
      return false;
   if(InpMaxSpread <= 0.0 || InpCooldownBars < 0)
      return false;
   return true;
  }

int OnInit()
  {
   if(!InputsValid())
     {
      Print("[RGG] Invalid inputs: check risk money > 0, losses/day >= 1, layers 1-5 with (layers-1) x step < 0.95, ",
            "fast EMA < slow EMA, pullback bars 2-30, RSI level 0-50 and the SL range.");
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

   g_hTrendFast = iMA(_Symbol, InpTrendTF, InpTrendFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hTrendSlow = iMA(_Symbol, InpTrendTF, InpTrendSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hADX       = iADX(_Symbol, InpTrendTF, InpADXPeriod);
   g_hZoneFast  = iMA(_Symbol, InpSignalTF, InpZoneFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hZoneSlow  = iMA(_Symbol, InpSignalTF, InpZoneSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   g_hRSI       = iRSI(_Symbol, InpSignalTF, InpRSIPeriod, PRICE_CLOSE);
   g_hATR       = iATR(_Symbol, InpSignalTF, InpATRPeriod);
   if(g_hTrendFast == INVALID_HANDLE || g_hTrendSlow == INVALID_HANDLE || g_hADX == INVALID_HANDLE ||
      g_hZoneFast == INVALID_HANDLE || g_hZoneSlow == INVALID_HANDLE || g_hRSI == INVALID_HANDLE ||
      g_hATR == INVALID_HANDLE)
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
   g_gvPrefix  = StringFormat("%s.%s.%I64d.", tester ? "RGG2T" : "RGG2", _Symbol, InpMagic);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   LoadGuards();
   if(InpResetHardStop && g_hardHalt)
     {
      g_hardHalt   = false;
      g_peakEquity = equity;
      Log("Hard-stop reset by user; peak equity re-based to current equity. Set InpResetHardStop back to false.");
     }
   if(InpMaxDDPct <= 0.0)
      g_hardHalt = false;
   if(g_peakEquity <= 0.0)
      g_peakEquity = equity;
   if(g_dayStamp != DayStart(TimeCurrent()) || g_dayStartEquity <= 0.0)
     {
      g_dayStamp       = DayStart(TimeCurrent());
      g_dayStartEquity = equity;
      g_dailyHalt      = false;
     }
   SaveGuards();

   ResetSetupStruct();
   LoadSetup();
   if(g_setup.active && CountPositions() == 0 && CountPendings() == 0)
     {
      Log("Stored setup has no live orders - closing it.");
      ResetSetupStruct();
      SaveSetup();
     }
   g_historyDirty = true;
   g_lossesDirty  = true;
   g_lastBarTime  = 0;
   g_trendValid   = false;
   ArrayInitialize(g_statReasons, 0);
   ArrayInitialize(g_statLayers, 0);

   PrintFormat("[RGG] %s v%s started on %s | risk %.2f per trade (win %.2f) | layers %d | stop after %d losses/day | hard-stop %s",
               EA_NAME, EA_VERSION, _Symbol, InpRiskMoney, RR_RATIO * InpRiskMoney, InpGridLevels,
               InpMaxLossesPerDay, InpMaxDDPct > 0.0 ? DoubleToString(InpMaxDDPct, 1) + "%" : "off");
   if(g_hardHalt)
      Print("[RGG] Equity hard-stop is ACTIVE from a previous session. No trading until InpResetHardStop=true.");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   int handles[7];
   handles[0] = g_hTrendFast;
   handles[1] = g_hTrendSlow;
   handles[2] = g_hADX;
   handles[3] = g_hZoneFast;
   handles[4] = g_hZoneSlow;
   handles[5] = g_hRSI;
   handles[6] = g_hATR;
   for(int i = 0; i < 7; i++)
      if(handles[i] != INVALID_HANDLE)
         IndicatorRelease(handles[i]);
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

   // account guards first
   bool halted = CheckHardStop(equity);
   if(!halted)
      halted = CheckDailyLosses();
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
   CheckSetupBackstop();
   if(g_closing)
     {
      ProcessClosing();
      UpdateDashboard(tk);
      return;
     }

   bool newBar = IsNewBar();
   if(newBar && !UpdateTrend())
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
      g_lossesDirty  = true;
      g_tradeDirty   = true;
     }
  }
//+------------------------------------------------------------------+
