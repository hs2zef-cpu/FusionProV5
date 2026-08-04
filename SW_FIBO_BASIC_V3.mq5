//+------------------------------------------------------------------+
//| SW_FIBO_BASIC_V3.mq5                                             |
//| Based on original SW_Fibo618_Reversal_Indicator_MT5              |
//| Added simple Fibo lines: 50 / 61.8 / 70 / 100                    |
//| Keep original small dashboard at bottom-left                     |
//+------------------------------------------------------------------+
#property strict
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2
#property indicator_label1  "BUY Signal"

#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2
#property indicator_label2  "SELL Signal"

input int    EMA_Fast = 100;
input int    EMA_Slow = 200;
input int    SwingLookback = 120;
input int    TolerancePoints = 1200;
input bool   UseEngulfing = false;

input bool   ShowFiboLines = true;
input bool   ShowSwingLines = true;
input bool   ShowDashboard = true;
input bool   ShowArrows = true;
input bool   ShowFiboLabels = true;
input int    ArrowOffsetPoints = 500;

double BuyBuffer[];
double SellBuffer[];

int hEmaFast;
int hEmaSlow;

string prefix    = "SW_FIBO_BASIC_V3_";
string dashName  = "SW_FIBO_BASIC_V3_DASH";

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 233);
   PlotIndexSetInteger(1, PLOT_ARROW, 234);
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);

   hEmaFast = iMA(_Symbol, _Period, EMA_Fast, 0, MODE_EMA, PRICE_CLOSE);
   hEmaSlow = iMA(_Symbol, _Period, EMA_Slow, 0, MODE_EMA, PRICE_CLOSE);

   if(hEmaFast == INVALID_HANDLE || hEmaSlow == INVALID_HANDLE)
      return INIT_FAILED;

   // ล้าง object ของตัวเก่า ๆ ที่ชื่อชนกัน
   ObjectsDeleteAll(0, "SW_FIBO_BASIC_V2_");
   ObjectsDeleteAll(0, "SW_FIBO_BASIC_V3_");
   ObjectDelete(0, "SW_FIBO_618_LINE");

   IndicatorSetString(INDICATOR_SHORTNAME, "SW Fibo Basic V3");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, prefix);
   ObjectDelete(0, dashName);
}

//+------------------------------------------------------------------+
bool IsBullishEngulfing(const double &open[], const double &close[], int i)
{
   return close[i] > open[i] &&
          close[i+1] < open[i+1] &&
          close[i] > open[i+1] &&
          open[i] < close[i+1];
}

//+------------------------------------------------------------------+
bool IsBearishEngulfing(const double &open[], const double &close[], int i)
{
   return close[i] < open[i] &&
          close[i+1] > open[i+1] &&
          close[i] < open[i+1] &&
          open[i] > close[i+1];
}

//+------------------------------------------------------------------+
void DrawDash(string text, color clr)
{
   if(!ShowDashboard) return;

   if(ObjectFind(0, dashName) < 0)
   {
      ObjectCreate(0, dashName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, dashName, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, dashName, OBJPROP_XDISTANCE, 15);
      ObjectSetInteger(0, dashName, OBJPROP_YDISTANCE, 25);
      ObjectSetInteger(0, dashName, OBJPROP_FONTSIZE, 12);
      ObjectSetString(0, dashName, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, dashName, OBJPROP_BACK, false);
      ObjectSetInteger(0, dashName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, dashName, OBJPROP_HIDDEN, false);
   }

   ObjectSetString(0, dashName, OBJPROP_TEXT, text);
   ObjectSetInteger(0, dashName, OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
void DrawLine(string id, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   string name = prefix + id;

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   }

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
}

//+------------------------------------------------------------------+
void DrawPriceLabel(string id, string txt, double price, color clr)
{
   if(!ShowFiboLabels) return;

   string name = prefix + "TXT_" + id;
   datetime t = iTime(_Symbol, _Period, 0);
   if(t <= 0) t = TimeCurrent();
   t = t + PeriodSeconds(_Period) * 6;

   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price);

   ObjectMove(0, name, 0, t, price);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
}

//+------------------------------------------------------------------+
double BuyFibo(double swingLow, double swingHigh, double percent)
{
   return swingHigh - ((swingHigh - swingLow) * percent / 100.0);
}

//+------------------------------------------------------------------+
double SellFibo(double swingLow, double swingHigh, double percent)
{
   return swingLow + ((swingHigh - swingLow) * percent / 100.0);
}

//+------------------------------------------------------------------+
void DrawFiboSet(bool isBuy, double sLow, double sHigh)
{
   if(!ShowFiboLines) return;

   double f50, f618, f70, f100;

   if(isBuy)
   {
      f50  = BuyFibo(sLow, sHigh, 50.0);
      f618 = BuyFibo(sLow, sHigh, 61.8);
      f70  = BuyFibo(sLow, sHigh, 70.0);
      f100 = sLow;
   }
   else
   {
      f50  = SellFibo(sLow, sHigh, 50.0);
      f618 = SellFibo(sLow, sHigh, 61.8);
      f70  = SellFibo(sLow, sHigh, 70.0);
      f100 = sHigh;
   }

   // สีแยกชัด ๆ กันมองไม่เห็นบนกริด/เส้นออเดอร์
   DrawLine("FIBO_50",  f50,  clrAqua,    STYLE_DOT,     2);
   DrawLine("FIBO_618", f618, clrGold,    STYLE_DASH,    2);
   DrawLine("FIBO_70",  f70,  clrMagenta, STYLE_DOT,     2);
   DrawLine("FIBO_100", f100, clrRed,     STYLE_DASHDOT, 2);

   DrawPriceLabel("FIBO_50",  "50",   f50,  clrAqua);
   DrawPriceLabel("FIBO_618", "61.8", f618, clrGold);
   DrawPriceLabel("FIBO_70",  "70",   f70,  clrMagenta);
   DrawPriceLabel("FIBO_100", "100",  f100, clrRed);
}

//+------------------------------------------------------------------+
void DrawSwingLines(double sLow, double sHigh)
{
   if(!ShowSwingLines) return;

   DrawLine("SWING_HIGH", sHigh, clrDodgerBlue, STYLE_SOLID, 1);
   DrawLine("SWING_LOW",  sLow,  clrDodgerBlue, STYLE_SOLID, 1);
}

//+------------------------------------------------------------------+
string ZoneStatus(bool isBuy, double price, double sLow, double sHigh)
{
   double f50, f70, f100;

   if(isBuy)
   {
      f50  = BuyFibo(sLow, sHigh, 50.0);
      f70  = BuyFibo(sLow, sHigh, 70.0);
      f100 = sLow;
   }
   else
   {
      f50  = SellFibo(sLow, sHigh, 50.0);
      f70  = SellFibo(sLow, sHigh, 70.0);
      f100 = sHigh;
   }

   double top = MathMax(f50, f70);
   double bot = MathMin(f50, f70);

   if(price <= top && price >= bot)
      return isBuy ? "IN BUY ZONE 50-70" : "IN SELL ZONE 50-70";

   if(isBuy)
   {
      if(price > top) return "WAIT PULLBACK";
      if(price < f100) return "BROKE 100";
      return "BELOW ZONE";
   }

   if(price < bot) return "WAIT PULLBACK";
   if(price > f100) return "BROKE 100";
   return "ABOVE ZONE";
}

//+------------------------------------------------------------------+
int OnCalculate(
   const int rates_total,
   const int prev_calculated,
   const datetime &time[],
   const double &open[],
   const double &high[],
   const double &low[],
   const double &close[],
   const long &tick_volume[],
   const long &volume[],
   const int &spread[]
)
{
   if(rates_total < EMA_Slow + SwingLookback + 10)
      return 0;

   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   double emaFast[];
   double emaSlow[];

   ArraySetAsSeries(emaFast, true);
   ArraySetAsSeries(emaSlow, true);

   if(CopyBuffer(hEmaFast, 0, 0, rates_total, emaFast) <= 0) return 0;
   if(CopyBuffer(hEmaSlow, 0, 0, rates_total, emaSlow) <= 0) return 0;

   int limit = rates_total - SwingLookback - 5;
   if(limit > 500) limit = 500;

   for(int i = limit; i >= 1; i--)
   {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;

      bool upTrend = emaFast[i] > emaSlow[i];
      bool downTrend = emaFast[i] < emaSlow[i];

      int swingLowIndex = iLowest(_Symbol, _Period, MODE_LOW, SwingLookback, i);
      int swingHighIndex = iHighest(_Symbol, _Period, MODE_HIGH, SwingLookback, i);

      if(swingLowIndex < 0 || swingHighIndex < 0) continue;

      double swingLow = low[swingLowIndex];
      double swingHigh = high[swingHighIndex];

      if(swingHigh <= swingLow) continue;

      double fibBuy = BuyFibo(swingLow, swingHigh, 61.8);
      double fibSell = SellFibo(swingLow, swingHigh, 61.8);

      double tol = TolerancePoints * _Point;

      bool priceNearBuyFibo = MathAbs(close[i] - fibBuy) <= tol || MathAbs(low[i] - fibBuy) <= tol;
      bool priceNearSellFibo = MathAbs(close[i] - fibSell) <= tol || MathAbs(high[i] - fibSell) <= tol;

      bool bullOK = !UseEngulfing || IsBullishEngulfing(open, close, i);
      bool bearOK = !UseEngulfing || IsBearishEngulfing(open, close, i);

      if(ShowArrows && upTrend && swingLowIndex > swingHighIndex && priceNearBuyFibo && bullOK)
      {
         BuyBuffer[i] = low[i] - ArrowOffsetPoints * _Point;
      }

      if(ShowArrows && downTrend && swingHighIndex > swingLowIndex && priceNearSellFibo && bearOK)
      {
         SellBuffer[i] = high[i] + ArrowOffsetPoints * _Point;
      }
   }

   int now = 1;

   bool nowUp = emaFast[now] > emaSlow[now];
   bool nowDown = emaFast[now] < emaSlow[now];

   int lowIdx = iLowest(_Symbol, _Period, MODE_LOW, SwingLookback, now);
   int highIdx = iHighest(_Symbol, _Period, MODE_HIGH, SwingLookback, now);

   if(lowIdx < 0 || highIdx < 0)
      return rates_total;

   double sLow = low[lowIdx];
   double sHigh = high[highIdx];

   string status = "WAIT";
   color dashColor = clrSilver;

   if(sHigh > sLow)
   {
      if(nowUp)
      {
         DrawFiboSet(true, sLow, sHigh);
         DrawSwingLines(sLow, sHigh);

         status = "TREND BUY | " + ZoneStatus(true, close[0], sLow, sHigh);
         dashColor = clrLime;
      }
      else if(nowDown)
      {
         DrawFiboSet(false, sLow, sHigh);
         DrawSwingLines(sLow, sHigh);

         status = "TREND SELL | " + ZoneStatus(false, close[0], sLow, sHigh);
         dashColor = clrRed;
      }
   }

   DrawDash("SW Fibo Basic V3 : " + status, dashColor);

   return rates_total;
}
//+------------------------------------------------------------------+
