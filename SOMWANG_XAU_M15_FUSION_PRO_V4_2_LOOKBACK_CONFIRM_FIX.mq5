//+------------------------------------------------------------------+
//| SOMWANG_XAU_M15_FUSION_PRO_V4_1_REVIEW_FIX.mq5                  |
//| One-chart dashboard V3: hybrid panel + V4/V5 + RSI/MACD/Stoch   |
//| + lot discipline advisor                                         |
//| For XAUUSD M15 calm manual trading                               |
//| - FINAL signal only on closed bar (no repaint)                   |
//| - PREVIEW near candle close                                      |
//| - Panel score 0-100, BUY/SELL/WAIT                               |
//|                                                                  |
//| v2 FIXES:                                                        |
//|  [FIX1] BarsBetween: iBarShift exact=false แก้ cooldown ไม่ทำงาน |
//|  [FIX2] DrawSignal: label TP/SL ตรงกับ mode ที่เลือก            |
//|  [FIX3] Score/Dir sync: dir=0 เมื่อ score ต่ำกว่า threshold     |
//|  [FIX4] CooldownBarsV3: implement ใน OnCalculate                 |
//|  [FIX5] Cache CalcDailyPL: เรียก HistorySelect ไม่เกิน 1x/นาที  |
//|  [FIX6] MacroTrendDir: shift=0 ใน preview mode                  |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_plots 0
#property version "4.11"

//============================== ENUMS ===============================
enum SW_ModePreset
{
   SW_SNIPER   = 0,
   SW_BALANCED = 1,
   SW_SAFE     = 2
};

//============================== INPUTS ==============================
input ENUM_TIMEFRAMES InpTradeTF = PERIOD_M15;
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;

// General mode
input bool   InpShowPreview           = true;
input int    InpPreviewSeconds        = 60;
input int    InpPreviewStableSec      = 10;
input int    InpMinBarsBetweenSignals = 3;
input int    InpMinScoreToSignal      = 85;   // 80=normal, 90=very strict
input bool   InpRequireSameV4V5       = true;
input bool   InpKeepOnlyLatest        = true;
input bool   InpAlerts                = true;
input bool   InpPushNotification      = false;

// V3 preset / fresh-market lookback
input SW_ModePreset InpModePreset        = SW_SAFE;
input bool          InpUsePresetLookback = true;
input int           InpEntryLookback_Custom = 24;
input int           InpMomentumBars_Custom  = 36; // legacy/deprecated: not used by signal logic
input int           InpSRBars_Custom        = 72; // legacy/deprecated: not used by signal logic
input ENUM_TIMEFRAMES InpTrendTF2 = PERIOD_H4;

// M15 calm filters
input bool   InpRequireMacroTrend      = true;   // H4 must agree with signal direction
input bool   InpBlockLongOppositeWick  = true;   // block obvious SL-hunt candle
input double InpOppositeWickMaxRatio   = 0.62;   // opposite wick > range*ratio = toxic
input int    InpExpiryBars             = 3;
input int    InpCooldownBarsV3         = 8;       // [FIX4] ใช้จริงแล้ว

// Lot discipline advisor - advisory only, never auto-trades
input bool   InpShowLotAdvisor         = true;
input double InpStartBalanceForLotPlan = 1000.0;
input double InpBalanceForLot_002      = 1300.0;
input double InpBalanceForLot_003      = 1800.0;
input double InpBaseLot                = 0.01;
input double InpCurrentLot             = 0.01;
input double InpDailyMaxLossUsd        = 15.0;
input double InpReduceDDPercent        = 5.0;
input int    InpLossStreakToReduce     = 2;
input int    InpTradeHistoryDays       = 14;

// Trend
input int InpTrendEMA_Fast = 50;
input int InpTrendEMA_Slow = 200;

// Shared indicators
input int InpEntryEMA   = 21;
input int InpRSIPeriod  = 14;
input int InpATRPeriod  = 14;
input int InpMACDFast   = 12;
input int InpMACDSlow   = 26;
input int InpMACDSignal = 9;
input int InpStochK     = 5;
input int InpStochD     = 3;
input int InpStochSlowing = 3;

// V4 engine params
input double V4_RSI_Buy_Min      = 48.0;
input double V4_RSI_Buy_Max      = 62.0;
input double V4_RSI_Sell_Min     = 38.0;
input double V4_RSI_Sell_Max     = 52.0;
input double V4_NearEma_ATR      = 0.85;
input double V4_RejectionWickMin = 0.38;
input int    V4_BreakoutLookback = 10;
input double V4_MomentumBody_ATR = 0.32;

// V5 engine params
input double V5_RSI_Buy_Min      = 50.0;
input double V5_RSI_Buy_Max      = 68.0;
input double V5_RSI_Sell_Min     = 32.0;
input double V5_RSI_Sell_Max     = 50.0;
input double V5_NearEma_ATR      = 0.95;
input double V5_RejectionWickMin = 0.35;
input int    V5_BreakoutLookback = 12;
input double V5_MomentumBody_ATR = 0.36;

// Breakout lookback source
// true  = use V4_BreakoutLookback / V5_BreakoutLookback for each engine
// false = use the shared preset/custom EffectiveEntryLookback() for both engines
input bool   InpUseEngineBreakoutLookbacks = true;

// Safety filters
input bool   InpUseATRSpikeFilter = true;
input int    InpATR_AvgBars       = 96;
input double InpATR_SpikeMult     = 1.75;
input bool   InpUseADXFilter      = true;
input int    InpADXPeriod         = 14;
input double InpADXMinLevel       = 18.0;
input bool   InpUseVolumeFilter   = true;
input int    InpVolumeAvgBars     = 20;
input double InpVolumeBoostMin    = 0.95;

// Extra confluence filters
input bool   InpUseRSI50Filter = true;   // soft score bonus: BUY RSI>50, SELL RSI<50
input bool   InpUseMACDFilter  = true;   // soft score bonus: BUY histogram positive, SELL negative
input bool   InpUseStochFilter = true;   // soft score bonus: timing only
input bool   InpRequireRSIConfirm   = false; // hard block when enabled and RSI confirmation fails
input bool   InpRequireMACDConfirm  = false; // hard block when enabled and MACD confirmation fails
input bool   InpRequireStochConfirm = false; // hard block when enabled and Stoch confirmation fails
input double InpStochOB        = 80.0;
input double InpStochOS        = 20.0;

// TP/SL drawing
input double InpTP_ATR_Mult      = 1.80; // reviewed default: reward > risk
input double InpSL_ATR_Mult      = 1.30;
input bool   InpDrawLines        = true;
input bool   InpExtendLinesRight = true;
input bool   InpUseDollarTP_SL   = false;
input double InpTP1_Dollars      = 10.0;
input double InpTP2_Dollars      = 30.0;
input double InpSL_Dollars       = 15.0;

// Risk-based lot advisor (advisory only)
input bool   InpUseRiskBasedLot    = true;
input double InpRiskPerTradePct    = 0.35; // percent of equity per trade
input double InpMaxSuggestedLot    = 0.10;

// Performance
input int    InpPreviewThrottleMs  = 750;  // 0 = every tick

// Panel
input bool InpShowPanel    = true;
input int  InpPanelX       = 12;
input int  InpPanelY       = 28;
input int  InpPanelFont    = 11;
input int  InpPanelLineGap = 17;
input int  InpPanelWidth   = 290;
input int  InpPanelHeight  = 290;

//============================== HANDLES =============================
int hEmaEntry   = INVALID_HANDLE;
int hRsi        = INVALID_HANDLE;
int hAtr        = INVALID_HANDLE;
int hTrendFast  = INVALID_HANDLE;
int hTrendSlow  = INVALID_HANDLE;
int hTrend2Fast = INVALID_HANDLE;
int hTrend2Slow = INVALID_HANDLE;
int hAdx        = INVALID_HANDLE;
int hMacd       = INVALID_HANDLE;
int hStoch      = INVALID_HANDLE;

//============================== STATE ===============================
string   PREFIX       = "SWFUSION_";
datetime g_lastClosed = 0;
datetime g_lastSignal = 0;
int      g_prevDir    = 0;
int      g_prevScore  = 0;
datetime g_prevFirst  = 0;
ulong    g_lastPreviewMs = 0;

// [FIX4] cooldown ใช้ InpCooldownBarsV3 แทน InpMinBarsBetweenSignals ใน final signal
// ทั้งสองค่าถูกใช้ตามวัตถุประสงค์ที่แตกต่างกัน:
//   InpMinBarsBetweenSignals = cooldown ใน preview
//   InpCooldownBarsV3        = cooldown หลัก ใน final signal

// [FIX5] Cache สำหรับ CalcDailyPL — อัปเดตไม่เกิน 1 ครั้งต่อนาที
datetime g_lotCacheTime   = 0;
double   g_cachedDailyPL  = 0.0;
int      g_cachedLossStreak = 0;

enum FusionState { ST_WAIT=0, ST_BUY=1, ST_SELL=-1, ST_BLOCK=9, ST_COOLDOWN=8 };

//============================== HELPERS =============================
bool GetBufVal(const int handle, const int buffer, const int shift, double &outVal)
{
   double a[]; ArraySetAsSeries(a, true);
   if(CopyBuffer(handle, buffer, shift, 1, a) != 1) return false;
   outVal = a[0];
   return true;
}

bool GetRatesTF(ENUM_TIMEFRAMES tf, int startShift, int count, MqlRates &outRates[])
{
   MqlRates r[]; ArraySetAsSeries(r, true);
   int got = CopyRates(_Symbol, tf, startShift, count, r);
   if(got != count) return false;
   ArrayResize(outRates, count);
   for(int i = 0; i < count; i++) outRates[i] = r[i];
   return true;
}

void DeleteByPrefix(const string pref)
{
   int total = ObjectsTotal(0, 0, -1);
   for(int i = total - 1; i >= 0; i--)
   {
      string n = ObjectName(0, i, 0, -1);
      if(StringFind(n, pref) == 0) ObjectDelete(0, n);
   }
}

string DirTxt(int d)  { if(d > 0) return "BUY"; if(d < 0) return "SELL"; return "NONE"; }
string YesNo(bool v)  { return v ? "OK" : "NO"; }
string Stars(int r)   { if(r >= 5) return "★★★★★"; if(r == 4) return "★★★★"; if(r == 3) return "★★★"; return "-"; }

color StateColor(int dir, int score, bool blocked)
{
   if(blocked)    return clrRed;
   if(score >= 90) return (dir > 0 ? clrGold : clrOrangeRed);
   if(score >= 80) return (dir > 0 ? clrLime : clrDarkOrange);
   if(score >= 60) return clrSilver;
   return clrGray;
}

//+------------------------------------------------------------------+
// [FIX1] BarsBetween: เปลี่ยน exact=true → false
//         exact=true คืนค่า -1 ถ้า datetime ไม่ตรง bar พอดี
//         ทำให้ cooldown คืนค่า 999999 เสมอ = cooldown ไม่มีวันหมด
//+------------------------------------------------------------------+
int BarsBetween(datetime a, datetime b)
{
   int s1 = iBarShift(_Symbol, InpTradeTF, a, false); // [FIX1] false = nearest bar
   int s2 = iBarShift(_Symbol, InpTradeTF, b, false); // [FIX1] false = nearest bar
   if(s1 < 0 || s2 < 0) return 999999;
   return MathAbs(s1 - s2);
}

double WickRejectionScore(const MqlRates &b, bool isBuy)
{
   double range = b.high - b.low; if(range <= 0.0) return 0.0;
   double upper = b.high - MathMax(b.open, b.close);
   double lower = MathMin(b.open, b.close) - b.low;
   return isBuy ? lower / range : upper / range;
}

bool BreakoutSignal(const MqlRates &barX, bool isCurrentBar, bool allowBuy, bool allowSell, int lookback)
{
   MqlRates rb[]; int start = isCurrentBar ? 1 : 2;
   if(!GetRatesTF(InpTradeTF, start, lookback, rb)) return false;
   double hi = -DBL_MAX, lo = DBL_MAX;
   for(int i = 0; i < ArraySize(rb); i++) { hi = MathMax(hi, rb[i].high); lo = MathMin(lo, rb[i].low); }
   if(allowBuy  && barX.close > hi) return true;
   if(allowSell && barX.close < lo) return true;
   return false;
}

bool MomentumSignal(const MqlRates &barX, bool allowBuy, bool allowSell, double atr, double bodyMult)
{
   double body = MathAbs(barX.close - barX.open);
   if(body < atr * bodyMult) return false;
   if(allowBuy  && barX.close > barX.open) return true;
   if(allowSell && barX.close < barX.open) return true;
   return false;
}

int ComputeCoreRating(const MqlRates &barX, bool isCurrentBar, bool trendUp, bool trendDn,
                      double ema20, double rsi, double atr, int &dirOut,
                      double rsiBuyMin, double rsiBuyMax, double rsiSellMin, double rsiSellMax,
                      double nearEmaAtr, double wickMin, int breakoutLookback, double momoBodyAtr,
                      bool requireAdxVol, bool adxOK, bool volOK)
{
   dirOut = 0;
   bool allowBuy = trendUp, allowSell = trendDn;
   if(!(allowBuy || allowSell)) return 0;

   bool bull    = (barX.close > barX.open);
   bool bear    = (barX.close < barX.open);
   bool nearEma = (MathAbs(barX.close - ema20) <= atr * nearEmaAtr);
   bool buyRSI  = (rsi >= rsiBuyMin  && rsi <= rsiBuyMax);
   bool sellRSI = (rsi >= rsiSellMin && rsi <= rsiSellMax);

   bool godBuy  = allowBuy  && nearEma && buyRSI  && bull && (WickRejectionScore(barX, true)  >= wickMin);
   bool godSell = allowSell && nearEma && sellRSI && bear && (WickRejectionScore(barX, false) >= wickMin);

   bool sniperReady = true;
   if(requireAdxVol && (!adxOK || !volOK)) sniperReady = false;
   bool sniper = false;
   if(sniperReady)
      sniper = BreakoutSignal(barX, isCurrentBar, allowBuy, allowSell, breakoutLookback) ||
               MomentumSignal(barX, allowBuy, allowSell, atr, momoBodyAtr);

   bool sniperBuy  = sniper && allowBuy;
   bool sniperSell = sniper && allowSell;

   if(godBuy  && sniperBuy)  { dirOut = +1; return 5; }
   if(godSell && sniperSell) { dirOut = -1; return 5; }
   if(godBuy)                { dirOut = +1; return 4; }
   if(godSell)               { dirOut = -1; return 4; }
   if(sniperBuy)             { dirOut = +1; return 3; }
   if(sniperSell)            { dirOut = -1; return 3; }
   return 0;
}

bool ATRSpike(bool useClosed, double &atrAvgOut)
{
   atrAvgOut = 0.0;
   if(!InpUseATRSpikeFilter) return false;

   const int shiftNow = useClosed ? 1 : 0;
   const int avgStart = shiftNow + 1; // exclude current/test ATR from its own baseline
   double a[]; ArraySetAsSeries(a, true);
   int got = CopyBuffer(hAtr, 0, avgStart, InpATR_AvgBars, a);
   if(got < InpATR_AvgBars) return false;

   double sum = 0.0;
   for(int i = 0; i < InpATR_AvgBars; i++) sum += a[i];
   atrAvgOut = sum / (double)InpATR_AvgBars;

   double atrNow = 0.0;
   if(!GetBufVal(hAtr, 0, shiftNow, atrNow)) return false;
   return (atrNow >= atrAvgOut * InpATR_SpikeMult);
}

bool VolumeConfirm(bool useClosed, double &ratioOut)
{
   ratioOut = 0.0; if(!InpUseVolumeFilter) return true;
   long vol[]; ArraySetAsSeries(vol, true);
   int need = InpVolumeAvgBars + 1;
   int start = useClosed ? 1 : 0;
   if(CopyTickVolume(_Symbol, InpTradeTF, start, need, vol) < need) return false;
   double sum = 0.0; for(int i = 1; i < need; i++) sum += (double)vol[i];
   double avg = sum / (double)InpVolumeAvgBars; if(avg <= 0.0) return false;
   ratioOut = (double)vol[0] / avg;
   return (ratioOut >= InpVolumeBoostMin);
}

bool ADXConfirm(bool useClosed, double &adxOut)
{
   adxOut = 0.0; if(!InpUseADXFilter) return true;
   int sh = useClosed ? 1 : 0;
   if(!GetBufVal(hAdx, 0, sh, adxOut)) return false;
   return (adxOut >= InpADXMinLevel);
}

bool MACDConfirm(int dir, bool useClosed, double &histOut)
{
   histOut = 0.0; if(!InpUseMACDFilter) return true;
   int sh = useClosed ? 1 : 0;
   double main = 0.0, sig = 0.0;
   if(!GetBufVal(hMacd, 0, sh, main) || !GetBufVal(hMacd, 1, sh, sig)) return false;
   histOut = main - sig;
   if(dir > 0) return (main > sig || histOut > 0.0);
   if(dir < 0) return (main < sig || histOut < 0.0);
   return false;
}

bool StochConfirm(int dir, bool useClosed, double &kOut, double &dOut)
{
   kOut = 0.0; dOut = 0.0; if(!InpUseStochFilter) return true;
   int sh = useClosed ? 1 : 0;
   if(!GetBufVal(hStoch, 0, sh, kOut) || !GetBufVal(hStoch, 1, sh, dOut)) return false;
   if(dir > 0) return (kOut > dOut && kOut > InpStochOS);
   if(dir < 0) return (kOut < dOut && kOut < InpStochOB);
   return false;
}

bool RSI50Confirm(int dir, double rsi)
{
   if(!InpUseRSI50Filter) return true;
   if(dir > 0) return rsi > 50.0;
   if(dir < 0) return rsi < 50.0;
   return false;
}

//============================== STRUCTS =============================
struct EvalResult
{
   int    dir;
   int    score;
   int    v4Rating;
   int    v4Dir;
   int    v5Rating;
   int    v5Dir;
   bool   trendUp;
   bool   trendDn;
   bool   adxOK;
   bool   volOK;
   bool   rsiOK;
   bool   macdOK;
   bool   stochOK;
   bool   spike;
   bool   same;
   bool   macroOK;
   bool   toxicWick;
   bool   hardConfirmFailed;
   bool   hardRSIFailed;
   bool   hardMACDFailed;
   bool   hardStochFailed;
   double rsi;
   double atr;
   double adx;
   double volRatio;
   double macdHist;
   double stochK;
   double stochD;
};

bool ToxicOppositeWick(const MqlRates &b, int dir)
{
   if(!InpBlockLongOppositeWick || dir == 0) return false;
   double range = b.high - b.low;
   if(range <= 0.0) return false;
   double upper = b.high - MathMax(b.open, b.close);
   double lower = MathMin(b.open, b.close) - b.low;
   if(dir > 0) return (upper / range >= InpOppositeWickMaxRatio);
   if(dir < 0) return (lower / range >= InpOppositeWickMaxRatio);
   return false;
}

//+------------------------------------------------------------------+
// [FIX6] MacroTrendDir รับ parameter useClosed
//         preview mode ใช้ shift=0 (realtime H4)
//         final mode ใช้ shift=1 (closed H4 bar)
//+------------------------------------------------------------------+
int MacroTrendDir(bool useClosed = true)
{
   double f = 0.0, s = 0.0;
   if(hTrend2Fast == INVALID_HANDLE || hTrend2Slow == INVALID_HANDLE) return 0;
   int sh = useClosed ? 1 : 0;
   if(!GetBufVal(hTrend2Fast, 0, sh, f) || !GetBufVal(hTrend2Slow, 0, sh, s)) return 0;
   if(f > s) return  1;
   if(f < s) return -1;
   return 0;
}

bool Evaluate(bool useClosed, const MqlRates &barX, EvalResult &e)
{
   ZeroMemory(e);
   int sh = useClosed ? 1 : 0;
   bool isCurrent = !useClosed;

   double ema20 = 0.0, emaFast = 0.0, emaSlow = 0.0;
   if(!GetBufVal(hEmaEntry,  0, sh, ema20)   ||
      !GetBufVal(hRsi,       0, sh, e.rsi)   ||
      !GetBufVal(hAtr,       0, sh, e.atr)   ||
      !GetBufVal(hTrendFast, 0, 1,  emaFast) ||
      !GetBufVal(hTrendSlow, 0, 1,  emaSlow))
      return false;

   e.trendUp = (emaFast > emaSlow);
   e.trendDn = (emaFast < emaSlow);
   e.adxOK   = ADXConfirm(useClosed, e.adx);
   e.volOK   = VolumeConfirm(useClosed, e.volRatio);
   double atrAvg = 0.0;
   e.spike = ATRSpike(useClosed, atrAvg);

   int v4Lookback = InpUseEngineBreakoutLookbacks ? MathMax(3, V4_BreakoutLookback) : EffectiveEntryLookback();
   int v5Lookback = InpUseEngineBreakoutLookbacks ? MathMax(3, V5_BreakoutLookback) : EffectiveEntryLookback();

   e.v4Rating = ComputeCoreRating(barX, isCurrent, e.trendUp, e.trendDn, ema20, e.rsi, e.atr, e.v4Dir,
                                  V4_RSI_Buy_Min, V4_RSI_Buy_Max, V4_RSI_Sell_Min, V4_RSI_Sell_Max,
                                  V4_NearEma_ATR, V4_RejectionWickMin, v4Lookback, V4_MomentumBody_ATR,
                                  false, e.adxOK, e.volOK);

   e.v5Rating = ComputeCoreRating(barX, isCurrent, e.trendUp, e.trendDn, ema20, e.rsi, e.atr, e.v5Dir,
                                  V5_RSI_Buy_Min, V5_RSI_Buy_Max, V5_RSI_Sell_Min, V5_RSI_Sell_Max,
                                  V5_NearEma_ATR, V5_RejectionWickMin, v5Lookback, V5_MomentumBody_ATR,
                                  true, e.adxOK, e.volOK);

   e.same = (e.v4Dir != 0 && e.v4Dir == e.v5Dir);
   if(InpRequireSameV4V5)
   {
      e.dir = e.same ? e.v4Dir : 0;
   }
   else
   {
      if(e.v5Dir != 0)      e.dir = e.v5Dir;
      else if(e.v4Dir != 0) e.dir = e.v4Dir;
   }

   // [FIX6] ส่ง useClosed ให้ MacroTrendDir ด้วย
   int macroDir = MacroTrendDir(useClosed);
   e.macroOK   = (!InpRequireMacroTrend || e.dir == 0 || macroDir == 0 || macroDir == e.dir);
   e.toxicWick = ToxicOppositeWick(barX, e.dir);
   if(!e.macroOK || e.toxicWick) e.dir = 0;

   // Evaluate confirmations against the candidate direction.
   // They remain soft score bonuses unless the corresponding Require input is enabled.
   int candidateDir = e.dir;
   e.rsiOK   = RSI50Confirm(candidateDir, e.rsi);
   e.macdOK  = MACDConfirm(candidateDir, useClosed, e.macdHist);
   e.stochOK = StochConfirm(candidateDir, useClosed, e.stochK, e.stochD);

   e.hardRSIFailed   = (candidateDir != 0 && InpRequireRSIConfirm   && !e.rsiOK);
   e.hardMACDFailed  = (candidateDir != 0 && InpRequireMACDConfirm  && !e.macdOK);
   e.hardStochFailed = (candidateDir != 0 && InpRequireStochConfirm && !e.stochOK);
   e.hardConfirmFailed = (e.hardRSIFailed || e.hardMACDFailed || e.hardStochFailed);
   if(e.hardConfirmFailed) e.dir = 0;

   // คำนวณ score
   int score = 0;
   if(e.v4Rating > 0) score += 20 + (e.v4Rating - 3) * 5;
   if(e.v5Rating > 0) score += 25 + (e.v5Rating - 3) * 5;
   if(e.same)         score += 15;
   if(e.adxOK)        score += 10;
   if(e.volOK)        score +=  5;
   if(e.rsiOK)        score += 10;
   if(e.macdOK)       score += 10;
   if(e.stochOK)      score +=  5;
   if(e.spike)        score -= 30;
   if(!e.macroOK)     score -= 25;
   if(e.toxicWick)    score -= 25;
   if(score < 0)   score = 0;
   if(score > 100) score = 100;
   e.score = score;

   // [FIX3] sync dir กับ score: ถ้า score ต่ำเกินไปหลัง penalty ให้ dir = 0
   //         ป้องกัน Panel แสดง "BUY/SELL WEAK" ที่ score = 0
   if(e.dir != 0 && e.score < 30) e.dir = 0;

   return true;
}

//============================== PRESET HELPERS ======================
int EffectiveEntryLookback()
{
   if(!InpUsePresetLookback) return MathMax(3, InpEntryLookback_Custom);
   if(InpModePreset == SW_SNIPER) return 12;
   if(InpModePreset == SW_SAFE)   return 24;
   return 18;
}

int EffectiveMomentumBars()
{
   if(!InpUsePresetLookback) return MathMax(6, InpMomentumBars_Custom);
   if(InpModePreset == SW_SNIPER) return 18;
   if(InpModePreset == SW_SAFE)   return 36;
   return 24;
}

int EffectiveSRBars()
{
   if(!InpUsePresetLookback) return MathMax(12, InpSRBars_Custom);
   if(InpModePreset == SW_SNIPER) return 36;
   if(InpModePreset == SW_SAFE)   return 72;
   return 48;
}

string PresetTxt()
{
   if(InpModePreset == SW_SNIPER) return "SNIPER";
   if(InpModePreset == SW_SAFE)   return "SAFE";
   return "BALANCED";
}

//============================== LOT ADVISOR =========================
struct LotAdvisorResult
{
   string action;
   string reason;
   double suggestedLot;
   double balance;
   double equity;
   double ddPct;
   double dailyPL;
   int    lossStreak;
};

//+------------------------------------------------------------------+
// [FIX5] Cache CalcDailyPLAndLossStreak ทุก 60 วินาที
//         เดิมเรียก HistorySelect ทุก tick ซึ่งหนักมาก
//+------------------------------------------------------------------+
void CalcDailyPLAndLossStreak(double &dailyPL, int &lossStreak)
{
   datetime now = TimeCurrent();

   // คืนค่า cache ถ้ายังไม่ถึง 60 วินาที
   if(now - g_lotCacheTime < 60 && g_lotCacheTime > 0)
   {
      dailyPL    = g_cachedDailyPL;
      lossStreak = g_cachedLossStreak;
      return;
   }

   dailyPL = 0.0; lossStreak = 0;
   MqlDateTime dt; TimeToStruct(now, dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);
   datetime from     = now - (InpTradeHistoryDays * 86400);

   if(!HistorySelect(from, now))
   {
      g_lotCacheTime    = now;
      g_cachedDailyPL   = dailyPL;
      g_cachedLossStreak = lossStreak;
      return;
   }

   int  total     = HistoryDealsTotal();
   bool streakOpen = true;

   for(int i = total - 1; i >= 0; i--)
   {
      ulong tk = HistoryDealGetTicket(i);
      if(tk == 0) continue;
      string sym = HistoryDealGetString(tk, DEAL_SYMBOL);
      if(sym != _Symbol) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;
      datetime t      = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
      double   profit = HistoryDealGetDouble(tk, DEAL_PROFIT)
                      + HistoryDealGetDouble(tk, DEAL_SWAP)
                      + HistoryDealGetDouble(tk, DEAL_COMMISSION);
      if(t >= dayStart) dailyPL += profit;
      if(streakOpen)
      {
         if(profit < 0.0)      lossStreak++;
         else if(profit > 0.0) streakOpen = false;
      }
   }

   // บันทึก cache
   g_lotCacheTime     = now;
   g_cachedDailyPL    = dailyPL;
   g_cachedLossStreak = lossStreak;
}

double NormalizeLotDown(double lot)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step <= 0.0) step = 0.01;
   lot = MathFloor(lot / step + 1e-9) * step;
   lot = MathMax(minLot, MathMin(maxLot, lot));
   if(InpMaxSuggestedLot > 0.0) lot = MathMin(lot, InpMaxSuggestedLot);
   return lot;
}

double CalcRiskBasedLot(int dir, double atr)
{
   if(dir == 0 || atr <= 0.0 || InpRiskPerTradePct <= 0.0)
      return NormalizeLotDown(InpBaseLot);

   double entry = (dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                            : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return NormalizeLotDown(InpBaseLot);

   double slDistance = atr * InpSL_ATR_Mult;
   double sl = (dir > 0) ? entry - slDistance : entry + slDistance;
   ENUM_ORDER_TYPE orderType = (dir > 0) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   double lossOneLot = 0.0;
   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entry, sl, lossOneLot))
      return NormalizeLotDown(InpBaseLot);

   lossOneLot = MathAbs(lossOneLot);
   if(lossOneLot <= 0.0) return NormalizeLotDown(InpBaseLot);

   double riskMoney = AccountInfoDouble(ACCOUNT_EQUITY) * InpRiskPerTradePct / 100.0;
   return NormalizeLotDown(riskMoney / lossOneLot);
}

LotAdvisorResult GetLotAdvisor(int signalScore, int dir, double atr)
{
   LotAdvisorResult r;
   r.action       = "LOT: HOLD";
   r.reason       = "Keep discipline";
   r.suggestedLot = InpBaseLot;
   r.balance      = AccountInfoDouble(ACCOUNT_BALANCE);
   r.equity       = AccountInfoDouble(ACCOUNT_EQUITY);
   r.ddPct        = 0.0; r.dailyPL = 0.0; r.lossStreak = 0;

   if(r.balance > 0.0)
      r.ddPct = MathMax(0.0, (r.balance - r.equity) / r.balance * 100.0);

   CalcDailyPLAndLossStreak(r.dailyPL, r.lossStreak);

   bool reduce = false;
   if(r.ddPct >= InpReduceDDPercent)
      { reduce = true; r.reason = "DD >= " + DoubleToString(InpReduceDDPercent, 1) + "%"; }
   else if(r.dailyPL <= -InpDailyMaxLossUsd)
      { reduce = true; r.reason = "Daily loss hit"; }
   else if(r.lossStreak >= InpLossStreakToReduce)
      { reduce = true; r.reason = "Loss streak " + IntegerToString(r.lossStreak); }

   if(reduce)
   {
      r.action       = "REDUCE / PAUSE";
      r.suggestedLot = NormalizeLotDown(InpBaseLot);
      return r;
   }

   if(InpUseRiskBasedLot)
   {
      r.suggestedLot = CalcRiskBasedLot(dir, atr);
      r.action = "RISK " + DoubleToString(InpRiskPerTradePct, 2) + "%";
      r.reason = "ATR SL " + DoubleToString(InpSL_ATR_Mult, 2) + "x";
      return r;
   }

   if(r.balance >= InpBalanceForLot_003)
   {
      r.suggestedLot = (signalScore >= 90 ? 0.03 : 0.02);
      r.action       = (signalScore >= 90 ? "A+ MAY 0.03" : "NORMAL 0.02");
      r.reason       = "Balance >= " + DoubleToString(InpBalanceForLot_003, 0);
   }
   else if(r.balance >= InpBalanceForLot_002)
   {
      r.suggestedLot = (signalScore >= 90 ? 0.02 : 0.01);
      r.action       = (signalScore >= 90 ? "A+ MAY 0.02" : "NORMAL 0.01");
      r.reason       = "Balance >= " + DoubleToString(InpBalanceForLot_002, 0);
   }
   else
   {
      r.suggestedLot = 0.01;
      r.action       = "STAY 0.01";
      r.reason       = "Build record first";
   }
   return r;
}

//============================== PANEL ===============================
void PanelLabel(const string suffix, int row, const string text, color c, int fontSize = 0, bool bold = false)
{
   string name = PREFIX + "PANEL_" + suffix;
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER,   CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, InpPanelX + 12);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, InpPanelY + InpPanelHeight - 24 - (row * InpPanelLineGap));
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE,  (fontSize > 0 ? fontSize : InpPanelFont));
   ObjectSetInteger(0, name, OBJPROP_COLOR,     c);
   ObjectSetString (0, name, OBJPROP_FONT,      bold ? "Arial Bold" : "Consolas");
   ObjectSetString (0, name, OBJPROP_TEXT,      text);
}

void DrawPanel(const EvalResult &e, string state, bool preview = false)
{
   if(!InpShowPanel) return;

   string bg = PREFIX + "PANEL_BG";
   if(ObjectFind(0, bg) < 0) ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_CORNER,      CORNER_LEFT_LOWER);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE,   InpPanelX);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE,   InpPanelY);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE,       InpPanelWidth);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE,       InpPanelHeight);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR,     clrBlack);
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR,       clrDimGray);
   ObjectSetInteger(0, bg, OBJPROP_BACK,        false);

   color  mainC  = StateColor(e.dir, e.score, e.spike);
   string trend  = e.trendUp ? "UP" : (e.trendDn ? "DOWN" : "FLAT");
   string action = preview ? ("PREVIEW " + state) : state;

   // [FIX6] MacroTrendDir ส่ง useClosed=!preview เพื่อให้ panel ใน preview ใช้ H4 realtime
   int    macro    = MacroTrendDir(!preview);
   string macroTxt = (macro > 0 ? "UP" : (macro < 0 ? "DOWN" : "FLAT"));

   PanelLabel("L00", 0,  "SOMWANG FUSION PRO V4 M15  [" + PresetTxt() + "]", clrWhite, InpPanelFont+1, true);
   PanelLabel("L01", 1,  "ACTION : " + action,                                mainC,  InpPanelFont+2, true);
   PanelLabel("L02", 2,  "SCORE  : " + IntegerToString(e.score) + " / 100",   mainC,  InpPanelFont+1, true);
   PanelLabel("L03", 3,  "TREND  : H1 " + trend + " | H4 " + macroTxt,       (e.trendUp ? clrLime : (e.trendDn ? clrTomato : clrSilver)), 0, false);
   PanelLabel("L04", 4,  "V4/V5  : " + DirTxt(e.v4Dir) + " " + Stars(e.v4Rating) + "  |  " + DirTxt(e.v5Dir) + " " + Stars(e.v5Rating), clrWhite, 0, false);
   PanelLabel("L05", 5,  "RSI    : " + DoubleToString(e.rsi, 1) + "  " + YesNo(e.rsiOK),   (e.rsiOK   ? clrLime : clrTomato), 0, false);
   PanelLabel("L06", 6,  "MACD   : " + YesNo(e.macdOK) + "  Hist " + DoubleToString(e.macdHist, 2), (e.macdOK  ? clrLime : clrTomato), 0, false);
   PanelLabel("L07", 7,  "STO    : " + YesNo(e.stochOK) + "  " + DoubleToString(e.stochK, 0) + "/" + DoubleToString(e.stochD, 0), (e.stochOK ? clrLime : clrTomato), 0, false);
   PanelLabel("L08", 8,  "ADX/VOL: " + YesNo(e.adxOK) + " " + DoubleToString(e.adx, 1) + " | " + YesNo(e.volOK) + " " + DoubleToString(e.volRatio, 2) + "x", (e.adxOK && e.volOK ? clrLime : clrSilver), 0, false);
   PanelLabel("L09", 9,  "SPIKE  : " + (e.spike ? "YES - NO TRADE" : "NO"),  (e.spike ? clrTomato : clrLime), 0, false);
   PanelLabel("L10X", 10,"M15 SAFE: Macro " + YesNo(e.macroOK) + " | Wick " + (e.toxicWick ? "TOXIC" : "OK"), (e.macroOK && !e.toxicWick ? clrLime : clrTomato), 0, false);
   string lookbackTxt = InpUseEngineBreakoutLookbacks
                        ? ("V4 " + IntegerToString(MathMax(3, V4_BreakoutLookback)) + " | V5 " + IntegerToString(MathMax(3, V5_BreakoutLookback)))
                        : ("Shared " + IntegerToString(EffectiveEntryLookback()));
   PanelLabel("L10", 11, "BARS   : Breakout " + lookbackTxt + " | Mo/SR legacy not used", clrSilver, 0, false);

   if(InpShowLotAdvisor)
   {
      LotAdvisorResult la = GetLotAdvisor(e.score, e.dir, e.atr);
      color lc = (StringFind(la.action, "REDUCE") >= 0 ? clrTomato : (StringFind(la.action, "MAY") >= 0 ? clrGold : clrLime));
      PanelLabel("L11", 12, "LOT    : " + la.action + " | suggest " + DoubleToString(la.suggestedLot, 2), lc, 0, true);
      PanelLabel("L12", 13, "RISK   : DD " + DoubleToString(la.ddPct, 1) + "% | Day " + DoubleToString(la.dailyPL, 2) + " | L" + IntegerToString(la.lossStreak), lc, 0, false);
      PanelLabel("L13", 14, "WHY    : " + la.reason, clrSilver, 0, false);
   }
}

//============================== DRAWING =============================
void RayLine(const string name, datetime t1, double p1, datetime t2, double p2, color c, ENUM_LINE_STYLE st)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, InpExtendLinesRight);
   ObjectSetInteger(0, name, OBJPROP_COLOR,     c);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,     1);
   ObjectSetInteger(0, name, OBJPROP_STYLE,     st);
   ObjectMove(0, name, 0, t1, p1);
   ObjectMove(0, name, 1, t2, p2);
}

double MoneyToPriceDelta(double money, double lot)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0 || lot <= 0.0) return 0.0;
   return (money * tickSize) / (tickValue * lot);
}

void PriceLabel(const string name, datetime t, double p, string text, color c)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_TEXT, 0, t, p);
   ObjectSetString (0, name, OBJPROP_TEXT,     text);
   ObjectSetInteger(0, name, OBJPROP_COLOR,    c);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString (0, name, OBJPROP_FONT,     "Consolas");
   ObjectMove(0, name, 0, t, p);
}

//+------------------------------------------------------------------+
// [FIX2] DrawSignal: label TP/SL แสดงค่าตรงตาม mode ที่เลือก
//         - InpUseDollarTP_SL=true  → แสดง "$"
//         - InpUseDollarTP_SL=false → แสดงราคาจริง (Digits)
//+------------------------------------------------------------------+
void DrawSignal(const string base, const MqlRates &barX, const MqlRates &bar0, const EvalResult &e, bool preview)
{
   bool isBuy = (e.dir > 0);
   double y   = isBuy ? barX.low - e.atr * 0.25 : barX.high + e.atr * 0.25;

   string ar = base + "_AR";
   if(ObjectFind(0, ar) < 0) ObjectCreate(0, ar, OBJ_ARROW, 0, barX.time, y);
   ObjectSetInteger(0, ar, OBJPROP_ARROWCODE, isBuy ? 233 : 234);
   ObjectSetInteger(0, ar, OBJPROP_WIDTH,     e.score >= 90 ? 3 : 2);
   ObjectSetInteger(0, ar, OBJPROP_COLOR,     preview ? clrSilver : (isBuy ? clrLime : clrOrangeRed));
   ObjectMove(0, ar, 0, barX.time, y);

   if(!InpDrawLines) return;

   double entry = barX.close;
   double tp1, tp2, sl;

   if(InpUseDollarTP_SL)
   {
      double d1 = MoneyToPriceDelta(InpTP1_Dollars, InpCurrentLot);
      double d2 = MoneyToPriceDelta(InpTP2_Dollars, InpCurrentLot);
      double ds = MoneyToPriceDelta(InpSL_Dollars,  InpCurrentLot);
      if(d1 <= 0.0 || d2 <= 0.0 || ds <= 0.0)
      { d1 = e.atr * InpTP_ATR_Mult * 0.5; d2 = e.atr * InpTP_ATR_Mult; ds = e.atr * InpSL_ATR_Mult; }
      tp1 = isBuy ? entry + d1 : entry - d1;
      tp2 = isBuy ? entry + d2 : entry - d2;
      sl  = isBuy ? entry - ds : entry + ds;
   }
   else
   {
      tp1 = isBuy ? entry + e.atr * InpTP_ATR_Mult * 0.5 : entry - e.atr * InpTP_ATR_Mult * 0.5;
      tp2 = isBuy ? entry + e.atr * InpTP_ATR_Mult       : entry - e.atr * InpTP_ATR_Mult;
      sl  = isBuy ? entry - e.atr * InpSL_ATR_Mult       : entry + e.atr * InpSL_ATR_Mult;
   }

   ENUM_LINE_STYLE st = preview ? STYLE_DASH : STYLE_SOLID;
   RayLine(base + "_EN",  barX.time, entry, bar0.time, entry, clrWhite, st);
   RayLine(base + "_TP1", barX.time, tp1,   bar0.time, tp1,   clrLime,  st);
   RayLine(base + "_TP2", barX.time, tp2,   bar0.time, tp2,   clrGreen, st);
   RayLine(base + "_SL",  barX.time, sl,    bar0.time, sl,    clrRed,   st);

   PriceLabel(base + "_EN_TXT",  bar0.time, entry, "Entry " + DoubleToString(entry, _Digits), clrWhite);

   // [FIX2] label ตรงกับ mode จริง
   if(InpUseDollarTP_SL)
   {
      PriceLabel(base + "_TP1_TXT", bar0.time, tp1, "TP1 +" + DoubleToString(InpTP1_Dollars, 0) + "$", clrLime);
      PriceLabel(base + "_TP2_TXT", bar0.time, tp2, "TP2 +" + DoubleToString(InpTP2_Dollars, 0) + "$", clrGreen);
      PriceLabel(base + "_SL_TXT",  bar0.time, sl,  "SL -"  + DoubleToString(InpSL_Dollars,  0) + "$", clrRed);
   }
   else
   {
      PriceLabel(base + "_TP1_TXT", bar0.time, tp1, "TP1 " + DoubleToString(tp1, _Digits), clrLime);
      PriceLabel(base + "_TP2_TXT", bar0.time, tp2, "TP2 " + DoubleToString(tp2, _Digits), clrGreen);
      PriceLabel(base + "_SL_TXT",  bar0.time, sl,  "SL  " + DoubleToString(sl,  _Digits), clrRed);
   }
}

void NotifySignal(const EvalResult &e)
{
   string msg = _Symbol + " " + EnumToString(InpTradeTF) + " FUSION " + DirTxt(e.dir) + " Score " + IntegerToString(e.score);
   if(InpAlerts)          Alert(msg);
   if(InpPushNotification) SendNotification(msg);
}

//============================== INIT ================================
int OnInit()
{
   if(InpEntryEMA < 1 || InpRSIPeriod < 2 || InpATRPeriod < 2 ||
      InpTrendEMA_Fast < 1 || InpTrendEMA_Slow <= InpTrendEMA_Fast ||
      InpMACDFast < 1 || InpMACDSlow <= InpMACDFast || InpMACDSignal < 1 ||
      InpStochK < 1 || InpStochD < 1 || InpStochSlowing < 1 ||
      InpADXPeriod < 2 || InpATR_AvgBars < 2 || InpVolumeAvgBars < 2 ||
      V4_BreakoutLookback < 3 || V5_BreakoutLookback < 3 || InpEntryLookback_Custom < 3 ||
      InpMinScoreToSignal < 0 || InpMinScoreToSignal > 100 ||
      InpTP_ATR_Mult <= 0.0 || InpSL_ATR_Mult <= 0.0 ||
      InpRiskPerTradePct < 0.0 || InpRiskPerTradePct > 5.0)
   {
      Print("SOMWANG FUSION init failed: invalid input parameters");
      return INIT_PARAMETERS_INCORRECT;
   }

   hEmaEntry   = iMA        (_Symbol, InpTradeTF, InpEntryEMA,   0, MODE_EMA, PRICE_CLOSE);
   hRsi        = iRSI       (_Symbol, InpTradeTF, InpRSIPeriod,     PRICE_CLOSE);
   hAtr        = iATR       (_Symbol, InpTradeTF, InpATRPeriod);
   hTrendFast  = iMA        (_Symbol, InpTrendTF, InpTrendEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hTrendSlow  = iMA        (_Symbol, InpTrendTF, InpTrendEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hTrend2Fast = iMA        (_Symbol, InpTrendTF2, InpTrendEMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hTrend2Slow = iMA        (_Symbol, InpTrendTF2, InpTrendEMA_Slow, 0, MODE_EMA, PRICE_CLOSE);
   hAdx        = iADX       (_Symbol, InpTradeTF, InpADXPeriod);
   hMacd       = iMACD      (_Symbol, InpTradeTF, InpMACDFast, InpMACDSlow, InpMACDSignal, PRICE_CLOSE);
   hStoch      = iStochastic(_Symbol, InpTradeTF, InpStochK, InpStochD, InpStochSlowing, MODE_SMA, STO_LOWHIGH);

   if(hEmaEntry   == INVALID_HANDLE || hRsi       == INVALID_HANDLE || hAtr        == INVALID_HANDLE ||
      hTrendFast  == INVALID_HANDLE || hTrendSlow == INVALID_HANDLE || hTrend2Fast == INVALID_HANDLE ||
      hTrend2Slow == INVALID_HANDLE || hAdx       == INVALID_HANDLE || hMacd       == INVALID_HANDLE ||
      hStoch      == INVALID_HANDLE)
   {
      Print("SOMWANG FUSION init failed: indicator handle error");
      return INIT_FAILED;
   }

   // reset cache
   g_lotCacheTime    = 0;
   g_cachedDailyPL   = 0.0;
   g_cachedLossStreak = 0;

   IndicatorSetString(INDICATOR_SHORTNAME, "SOMWANG XAU M15 FUSION PRO V4.2 LOOKBACK + CONFIRM FIX");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) { DeleteByPrefix(PREFIX); }

//============================== MAIN ================================
int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[], const double &low[],
                const double &close[], const long &tick_volume[], const long &volume[], const int &spread[])
{
   MqlRates rr[];
   if(!GetRatesTF(InpTradeTF, 0, 2, rr)) return rates_total;
   MqlRates bar0 = rr[0], bar1 = rr[1];

   // --- Preview mode (throttled to reduce CPU load) ---
   ulong nowMs = GetTickCount64();
   bool previewDue = (InpPreviewThrottleMs <= 0 || g_lastPreviewMs == 0 ||
                      nowMs - g_lastPreviewMs >= (ulong)InpPreviewThrottleMs);
   if(InpShowPreview && previewDue)
   {
      g_lastPreviewMs = nowMs;
      int secTf     = PeriodSeconds(InpTradeTF);
      int remaining = (int)((bar0.time + secTf) - TimeCurrent());
      if(remaining < 0) remaining = 0;

      if(remaining <= InpPreviewSeconds)
      {
         EvalResult ep;
         if(Evaluate(false, bar0, ep) && ep.dir != 0 && ep.score >= InpMinScoreToSignal && !ep.spike)
         {
            if(ep.dir != g_prevDir || ep.score != g_prevScore)
            {
               g_prevDir   = ep.dir;
               g_prevScore = ep.score;
               g_prevFirst = TimeCurrent();
               DeleteByPrefix(PREFIX + "PREV_");
            }
            if((TimeCurrent() - g_prevFirst) >= InpPreviewStableSec)
            {
               DrawSignal(PREFIX + "PREV_SIG", bar0, bar0, ep, true);
               DrawPanel(ep, DirTxt(ep.dir) + " READY", true);
            }
         }
         else
         {
            DeleteByPrefix(PREFIX + "PREV_");
            g_prevDir = 0; g_prevScore = 0; g_prevFirst = 0;
         }
      }
   }

   // --- Final signal: เรียกครั้งเดียวต่อ bar ที่ปิดแล้ว ---
   if(bar1.time != g_lastClosed)
   {
      g_lastClosed = bar1.time;
      DeleteByPrefix(PREFIX + "PREV_");
      g_prevDir = 0; g_prevScore = 0; g_prevFirst = 0;

      EvalResult e;
      if(!Evaluate(true, bar1, e)) return rates_total;

      // [FIX4] ใช้ InpCooldownBarsV3 สำหรับ final signal
      //        InpMinBarsBetweenSignals ยังคงใช้ใน preview logic (บรรทัดด้านบน)
      bool coolOK = (g_lastSignal == 0 || BarsBetween(bar1.time, g_lastSignal) >= InpCooldownBarsV3);

      string state = "WAIT";
      if(e.spike)          state = "NO TRADE - ATR SPIKE";
      else if(e.toxicWick) state = "NO TRADE - TOXIC WICK";
      else if(!e.macroOK)  state = "WAIT - H4 NOT SUPPORT";
      else if(e.hardConfirmFailed)
      {
         string why = "";
         if(e.hardRSIFailed)   why += (why == "" ? "RSI"   : "/RSI");
         if(e.hardMACDFailed)  why += (why == "" ? "MACD"  : "/MACD");
         if(e.hardStochFailed) why += (why == "" ? "STOCH" : "/STOCH");
         state = "WAIT - CONFIRM BLOCK (" + why + ")";
      }
      else if(!coolOK)     state = "COOLDOWN (" + IntegerToString(InpCooldownBarsV3) + " bars)";
      else if(e.dir != 0 && e.score >= InpMinScoreToSignal) state = DirTxt(e.dir) + " STRONG";
      else if(e.dir != 0 && e.score >= 60)                  state = DirTxt(e.dir) + " WEAK";

      DrawPanel(e, state, false);

      if(!e.spike && coolOK && e.dir != 0 && e.score >= InpMinScoreToSignal)
      {
         if(InpKeepOnlyLatest) DeleteByPrefix(PREFIX + "SIG_");
         string base = PREFIX + "SIG_" + IntegerToString((int)bar1.time);
         DrawSignal(base, bar1, bar0, e, false);
         g_lastSignal = bar1.time;
         NotifySignal(e);
      }
   }

   return rates_total;
}
//+------------------------------------------------------------------+
