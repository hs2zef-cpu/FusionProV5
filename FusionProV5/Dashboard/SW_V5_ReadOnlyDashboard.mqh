#ifndef SW_V5_READ_ONLY_DASHBOARD_MQH
#define SW_V5_READ_ONLY_DASHBOARD_MQH

#include "..\\Core\\SW_V5_Types.mqh"
#include "..\\Regression\\SW_V5_TrendRegression.mqh"
#include "..\\Regression\\SW_V5_MomentumRegression.mqh"

class CReadOnlyDashboard
{
private:
   string           m_prefix;
   ENUM_BASE_CORNER m_corner;
   int              m_x;
   int              m_y;
   int              m_width;
   int              m_height;
   int              m_manual_height;
   int              m_font_size;
   int              m_row_gap;
   bool             m_auto_height;
   bool             m_created;
   bool             m_dirty;

   string ObjectName(const string id)
   {
      return m_prefix + id;
   }

   ENUM_ANCHOR_POINT LabelAnchor()
   {
      if(m_corner == CORNER_RIGHT_UPPER) return ANCHOR_RIGHT_UPPER;
      if(m_corner == CORNER_LEFT_LOWER) return ANCHOR_LEFT_LOWER;
      if(m_corner == CORNER_RIGHT_LOWER) return ANCHOR_RIGHT_LOWER;
      return ANCHOR_LEFT_UPPER;
   }

   int LabelX(const int local_x)
   {
      if(m_corner == CORNER_RIGHT_UPPER || m_corner == CORNER_RIGHT_LOWER)
         return m_x + m_width - local_x;
      return m_x + local_x;
   }

   int LabelY(const int local_y)
   {
      if(m_corner == CORNER_LEFT_LOWER || m_corner == CORNER_RIGHT_LOWER)
         return m_y + m_height - local_y;
      return m_y + local_y;
   }

   int RectangleX(const int local_x, const int width)
   {
      if(m_corner == CORNER_RIGHT_UPPER || m_corner == CORNER_RIGHT_LOWER)
         return m_x + m_width - local_x - width;
      return m_x + local_x;
   }

   int RectangleY(const int local_y, const int height)
   {
      if(m_corner == CORNER_LEFT_LOWER || m_corner == CORNER_RIGHT_LOWER)
         return m_y + m_height - local_y - height;
      return m_y + local_y;
   }

   bool SetIntegerIfChanged(const string name,
                            const ENUM_OBJECT_PROPERTY_INTEGER property,
                            const long value)
   {
      if(ObjectGetInteger(0, name, property) == value)
         return false;
      if(!ObjectSetInteger(0, name, property, value))
         return false;
      m_dirty = true;
      return true;
   }

   bool SetStringIfChanged(const string name,
                           const ENUM_OBJECT_PROPERTY_STRING property,
                           const string value)
   {
      if(ObjectGetString(0, name, property) == value)
         return false;
      if(!ObjectSetString(0, name, property, value))
         return false;
      m_dirty = true;
      return true;
   }

   bool EnsureObject(const string name, const ENUM_OBJECT type)
   {
      if(ObjectFind(0, name) >= 0)
         return true;
      if(!ObjectCreate(0, name, type, 0, 0, 0))
         return false;
      m_dirty = true;
      return true;
   }

   void CommonObjectProperties(const string name, const int z_order)
   {
      SetIntegerIfChanged(name, OBJPROP_SELECTABLE, false);
      SetIntegerIfChanged(name, OBJPROP_SELECTED, false);
      SetIntegerIfChanged(name, OBJPROP_HIDDEN, true);
      SetIntegerIfChanged(name, OBJPROP_BACK, false);
      SetIntegerIfChanged(name, OBJPROP_ZORDER, z_order);
   }

   void Rectangle(const string id,
                  const int local_x,
                  const int local_y,
                  const int width,
                  const int height,
                  const color background,
                  const color border,
                  const int z_order)
   {
      string name = ObjectName(id);
      if(!EnsureObject(name, OBJ_RECTANGLE_LABEL))
         return;

      SetIntegerIfChanged(name, OBJPROP_CORNER, m_corner);
      SetIntegerIfChanged(name, OBJPROP_XDISTANCE, RectangleX(local_x, width));
      SetIntegerIfChanged(name, OBJPROP_YDISTANCE, RectangleY(local_y, height));
      SetIntegerIfChanged(name, OBJPROP_XSIZE, width);
      SetIntegerIfChanged(name, OBJPROP_YSIZE, height);
      SetIntegerIfChanged(name, OBJPROP_BGCOLOR, background);
      SetIntegerIfChanged(name, OBJPROP_COLOR, border);
      SetIntegerIfChanged(name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      CommonObjectProperties(name, z_order);
   }

   void Label(const string id,
              const int local_x,
              const int local_y,
              const string text,
              const color text_color,
              const int font_size,
              const string font,
              const int z_order)
   {
      string name = ObjectName(id);
      if(!EnsureObject(name, OBJ_LABEL))
         return;

      SetIntegerIfChanged(name, OBJPROP_CORNER, m_corner);
      SetIntegerIfChanged(name, OBJPROP_ANCHOR, LabelAnchor());
      SetIntegerIfChanged(name, OBJPROP_XDISTANCE, LabelX(local_x));
      SetIntegerIfChanged(name, OBJPROP_YDISTANCE, LabelY(local_y));
      SetIntegerIfChanged(name, OBJPROP_FONTSIZE, font_size);
      SetIntegerIfChanged(name, OBJPROP_COLOR, text_color);
      SetStringIfChanged(name, OBJPROP_FONT, font);
      SetStringIfChanged(name, OBJPROP_TEXT, text);
      CommonObjectProperties(name, z_order);
   }

   void Separator(const string id, const int local_y)
   {
      Rectangle(id, 12, local_y, m_width - 24, 1, C'58,66,78', C'58,66,78', 202);
   }

   void Row(const string id,
            const int local_y,
            const string label,
            const string value,
            const color value_color)
   {
      Label(id + "_LABEL", 16, local_y, label, C'158,168,181', m_font_size, "Segoe UI", 220);
      Label(id + "_VALUE", 146, local_y, value, value_color, m_font_size, "Segoe UI Semibold", 221);
   }

   void RowLabel(const string id, const int local_y, const string label)
   {
      Label(id + "_LABEL", 16, local_y, label, C'158,168,181', m_font_size, "Segoe UI", 220);
   }

   string HealthDisplay(const SWV5_EngineHealth health)
   {
      if(health == SWV5_HEALTH_HEALTHY) return "Healthy";
      if(health == SWV5_HEALTH_DEGRADED) return "DEGRADED";
      if(health == SWV5_HEALTH_UNAVAILABLE) return "UNAVAILABLE";
      if(health == SWV5_HEALTH_INVALID) return "INVALID";
      return "UNKNOWN";
   }

   color HealthColor(const SWV5_EngineHealth health)
   {
      if(health == SWV5_HEALTH_HEALTHY) return clrLime;
      if(health == SWV5_HEALTH_DEGRADED) return clrGold;
      if(health == SWV5_HEALTH_UNAVAILABLE) return clrOrange;
      return clrTomato;
   }

   string DataQualityDisplay(const SWV5_EngineInput &engineInput)
   {
      ulong market_flags = engineInput.market.header.data_quality_flags;
      ulong indicator_flags = engineInput.indicators.header.data_quality_flags;
      if(market_flags == SWV5_DQ_NONE && indicator_flags == SWV5_DQ_NONE)
         return "OK";
      return "CHECK " + IntegerToString((int)market_flags) + "/" + IntegerToString((int)indicator_flags);
   }

   color DataQualityColor(const SWV5_EngineInput &engineInput)
   {
      if(engineInput.market.header.data_quality_flags == SWV5_DQ_NONE &&
         engineInput.indicators.header.data_quality_flags == SWV5_DQ_NONE)
         return clrLime;
      return clrGold;
   }

   string AdviceDisplay(const SWV5_DecisionResult &decision)
   {
      if(decision.action == SWV5_ACTION_BLOCKED) return "BLOCKED";
      if(decision.action == SWV5_ACTION_BUY || decision.action == SWV5_ACTION_SELL) return "LEGACY SIGNAL";
      return "WAIT";
   }

   color ActionColor(const SWV5_DecisionAction action)
   {
      if(action == SWV5_ACTION_BUY) return clrLime;
      if(action == SWV5_ACTION_SELL) return clrTomato;
      if(action == SWV5_ACTION_BLOCKED) return clrRed;
      return C'210,217,226';
   }

   color BiasColor(const SWV5_Bias bias)
   {
      if(bias == SWV5_BIAS_BULLISH) return clrLime;
      if(bias == SWV5_BIAS_BEARISH) return clrTomato;
      return C'210,217,226';
   }

   string PriceActionBlockDisplay(const SWV5_PriceActionResult &priceAction,
                                  const SWV5_DecisionResult &decision)
   {
      if(decision.action != SWV5_ACTION_BLOCKED || decision.blocking_engine != SWV5_ENGINE_PRICE_ACTION)
         return "--";
      string reason = decision.header.reason_text;
      if(reason == "") reason = priceAction.header.reason_text;
      if(StringLen(reason) > 25) reason = StringSubstr(reason, 0, 25);
      return reason;
   }

   string LegacyScoreContractDisplay(const SWV5_LegacyResult &legacy)
   {
      if(!legacy.score_comparable_to_execution_threshold)
         return "NOT COMPARABLE";
      return SWV5_ScoreSemanticsText(legacy.score_semantics);
   }

   color RegressionColor(const SWV5_TrendRegressionStatus status)
   {
      if(status == SWV5_REGRESSION_PASS) return clrLime;
      if(status == SWV5_REGRESSION_EXPECTED_DIFFERENCE) return clrGold;
      if(status == SWV5_REGRESSION_FAIL) return clrTomato;
      return clrOrange;
   }

   color MomentumRegressionColor(const SWV5_MomentumRegressionStatus status)
   {
      if(status == SWV5_MOMENTUM_REGRESSION_PASS) return clrLime;
      if(status == SWV5_MOMENTUM_REGRESSION_EXPECTED_DIFFERENCE) return clrGold;
      if(status == SWV5_MOMENTUM_REGRESSION_FAIL) return clrTomato;
      return clrOrange;
   }

   int RowStep()
   {
      return MathMax(m_row_gap, m_font_size + 6);
   }

   int CalculateRequiredHeight()
   {
      int row_step = RowStep();
      int health_first = 92;
      int health_separator = health_first + (5 * row_step) + 22;
      int market_title = health_separator + 12;
      int market_first = market_title + 22;
      int market_separator = market_first + (8 * row_step) + 22;
      int decision_title = market_separator + 12;
      int decision_first = decision_title + 22;
      int decision_separator = decision_first + row_step + 22;
      int system_title = decision_separator + 12;
      int system_first = system_title + 22;
      int last_row = system_first + (9 * row_step);
      int bottom_padding = MathMax(16, m_font_size + 7);
      return last_row + bottom_padding;
   }

   void UpdatePanelHeight()
   {
      int required_height = CalculateRequiredHeight();
      int target_height = (m_auto_height ? required_height : MathMax(m_manual_height, required_height));
      if(m_height != target_height)
      {
         m_height = target_height;
         m_dirty = true;
      }
   }

   void BuildLayout()
   {
      int row_step = RowStep();
      int health_first = 92;
      int health_separator = health_first + (5 * row_step) + 22;
      int market_title = health_separator + 12;
      int market_first = market_title + 22;
      int market_separator = market_first + (8 * row_step) + 22;
      int decision_title = market_separator + 12;
      int decision_first = decision_title + 22;
      int decision_separator = decision_first + row_step + 22;
      int system_title = decision_separator + 12;

      Rectangle("PANEL_BG", 0, 0, m_width, m_height, C'18,22,28', C'74,84,98', 200);
      Rectangle("HEADER_BG", 1, 1, m_width - 2, 57, C'29,36,46', C'29,36,46', 201);
      Rectangle("LIVE_DOT", m_width - 66, 17, 8, 8, C'53,210,158', C'53,210,158', 222);

      Label("TITLE", 16, 11, "FUSION PRO V5", C'239,243,248', m_font_size + 2, "Segoe UI Semibold", 221);
      Label("LIVE", m_width - 50, 10, "LIVE", C'102,226,184', m_font_size, "Segoe UI Semibold", 221);
      Label("SUBTITLE", 16, 35, "Read Only Dashboard", C'151,162,177', m_font_size, "Segoe UI", 221);

      Separator("SEP_HEADER", 58);
      int section_font = (m_font_size > 7 ? m_font_size - 1 : 7);
      Label("HEALTH_TITLE", 16, 70, "ENGINE HEALTH", C'111,196,255', section_font, "Segoe UI Semibold", 221);
      Label("MARKET_TITLE", 16, market_title, "MARKET STATE", C'111,196,255', section_font, "Segoe UI Semibold", 221);
      Label("DECISION_TITLE", 16, decision_title, "FINAL DECISION", C'111,196,255', section_font, "Segoe UI Semibold", 221);
      Label("SYSTEM_TITLE", 16, system_title, "SYSTEM", C'111,196,255', section_font, "Segoe UI Semibold", 221);

      Separator("SEP_HEALTH", health_separator);
      Separator("SEP_MARKET", market_separator);
      Separator("SEP_DECISION", decision_separator);

      RowLabel("HEALTH_DECISION", health_first, "Decision");
      RowLabel("HEALTH_TREND", health_first + row_step, "Trend");
      RowLabel("HEALTH_MOMENTUM", health_first + (2 * row_step), "Momentum");
      RowLabel("HEALTH_PRICE_ACTION", health_first + (3 * row_step), "Price Action");
      RowLabel("HEALTH_LEGACY", health_first + (4 * row_step), "Legacy");
      RowLabel("HEALTH_DATA", health_first + (5 * row_step), "Data Quality");

      RowLabel("MARKET_STATE", market_first, "Market");
      RowLabel("MARKET_TREND", market_first + row_step, "Trend");
      RowLabel("MARKET_SCORE", market_first + (2 * row_step), "Trend Score");
      RowLabel("MARKET_MOMENTUM", market_first + (3 * row_step), "Momentum");
      RowLabel("MARKET_MOMENTUM_SCORE", market_first + (4 * row_step), "Momentum Score");
      RowLabel("MARKET_PA_STATE", market_first + (5 * row_step), "PA State");
      RowLabel("MARKET_PA_BIAS", market_first + (6 * row_step), "PA Bias");
      RowLabel("MARKET_PA_SCORE", market_first + (7 * row_step), "PA Score");
      RowLabel("MARKET_PA_CONFIDENCE", market_first + (8 * row_step), "PA Confidence");

      RowLabel("DECISION_ACTION", decision_first, "Action");
      RowLabel("DECISION_ADVICE", decision_first + row_step, "Advice");

      int system_first = system_title + 22;
      RowLabel("SYSTEM_TREND_REGRESSION", system_first, "Trend Reg");
      RowLabel("SYSTEM_MOMENTUM_REGRESSION", system_first + row_step, "Momentum Reg");
      RowLabel("SYSTEM_MOMENTUM_REASON", system_first + (2 * row_step), "Reg Reason");
      RowLabel("SYSTEM_PA_BLOCK", system_first + (3 * row_step), "PA Block Reason");
      RowLabel("SYSTEM_SCORE_CONTRACT", system_first + (4 * row_step), "Score Contract");
      RowLabel("SYSTEM_HISTORY_STATE", system_first + (5 * row_step), "History State");
      RowLabel("SYSTEM_STALE_STATE", system_first + (6 * row_step), "Stale State");
      RowLabel("SYSTEM_MODE", system_first + (7 * row_step), "Mode");
      RowLabel("SYSTEM_SNAPSHOT", system_first + (8 * row_step), "Snapshot");
      RowLabel("SYSTEM_HISTORY", system_first + (9 * row_step), "History Gen");

      m_created = true;
   }

public:
   CReadOnlyDashboard()
   {
      m_prefix = "SWV5_S32_DASH_";
      m_corner = CORNER_LEFT_UPPER;
      m_x = 14;
      m_y = 150;
      m_width = 344;
      m_height = 736;
      m_manual_height = 536;
      m_font_size = 9;
      m_row_gap = 20;
      m_auto_height = true;
      m_created = false;
      m_dirty = false;
   }

   void Configure(const string prefix, const int x, const int y)
   {
      Configure(prefix, CORNER_LEFT_UPPER, x, y, 344, true, 536, 9, 20);
   }

   void Configure(const string prefix,
                  const ENUM_BASE_CORNER corner,
                  const int x,
                  const int y,
                  const int width,
                  const int height,
                  const int row_gap)
   {
      Configure(prefix, corner, x, y, width, false, height, 9, row_gap);
   }

   void Configure(const string prefix,
                  const ENUM_BASE_CORNER corner,
                  const int x,
                  const int y,
                  const int width,
                  const int height,
                  const int font_size,
                  const int row_gap)
   {
      Configure(prefix, corner, x, y, width, false, height, font_size, row_gap);
   }

   void Configure(const string prefix,
                  const ENUM_BASE_CORNER corner,
                  const int x,
                  const int y,
                  const int width,
                  const bool auto_height,
                  const int manual_height,
                  const int font_size,
                  const int row_gap)
   {
      m_prefix = prefix;
      m_corner = corner;
      m_x = x;
      m_y = y;
      m_width = width;
      m_auto_height = auto_height;
      m_manual_height = manual_height;
      m_height = manual_height;
      m_font_size = font_size;
      m_row_gap = row_gap;
      m_created = false;
   }

   void Clear()
   {
      ObjectsDeleteAll(0, m_prefix);
      m_created = false;
      ChartRedraw(0);
   }

   void RefreshLayout()
   {
      if(!m_created)
         return;
      m_dirty = false;
      UpdatePanelHeight();
      BuildLayout();
      if(m_dirty)
         ChartRedraw(0);
   }

   void Render(const SWV5_EngineInput &engineInput,
               const SWV5_PriceActionResult &priceAction,
               const SWV5_TrendResult &trend,
               const SWV5_MomentumResult &momentum,
               const SWV5_LegacyResult &legacy,
               const SWV5_DecisionResult &decision,
               const SWV5_TrendRegressionResult &trendRegression,
               const SWV5_MomentumRegressionResult &momentumRegression)
   {
      m_dirty = false;
      UpdatePanelHeight();
      BuildLayout();

      int row_step = RowStep();
      int health_first = 92;
      int health_separator = health_first + (5 * row_step) + 22;
      int market_title = health_separator + 12;
      int market_first = market_title + 22;
      int market_separator = market_first + (8 * row_step) + 22;
      int decision_title = market_separator + 12;
      int decision_first = decision_title + 22;
      int decision_separator = decision_first + row_step + 22;
      int system_first = decision_separator + 34;

      Row("HEALTH_DECISION", health_first, "Decision", HealthDisplay(decision.header.health), HealthColor(decision.header.health));
      Row("HEALTH_TREND", health_first + row_step, "Trend", HealthDisplay(trend.header.health), HealthColor(trend.header.health));
      Row("HEALTH_MOMENTUM", health_first + (2 * row_step), "Momentum", HealthDisplay(momentum.header.health), HealthColor(momentum.header.health));
      Row("HEALTH_PRICE_ACTION", health_first + (3 * row_step), "Price Action", HealthDisplay(priceAction.header.health), HealthColor(priceAction.header.health));
      Row("HEALTH_LEGACY", health_first + (4 * row_step), "Legacy", HealthDisplay(legacy.header.health), HealthColor(legacy.header.health));
      Row("HEALTH_DATA", health_first + (5 * row_step), "Data Quality", DataQualityDisplay(engineInput), DataQualityColor(engineInput));

      Row("MARKET_STATE", market_first, "Market", decision.state, ActionColor(decision.action));
      Row("MARKET_TREND", market_first + row_step, "Trend", SWV5_BiasText(trend.bias), BiasColor(trend.bias));
      Row("MARKET_SCORE", market_first + (2 * row_step), "Trend Score", DoubleToString(trend.header.score, 1), C'210,217,226');
      Row("MARKET_MOMENTUM", market_first + (3 * row_step), "Momentum", momentum.momentum_state, BiasColor(momentum.bias));
      Row("MARKET_MOMENTUM_SCORE", market_first + (4 * row_step), "Momentum Score", DoubleToString(momentum.header.score, 1), C'210,217,226');
      Row("MARKET_PA_STATE", market_first + (5 * row_step), "PA State", priceAction.state, BiasColor(priceAction.bias));
      Row("MARKET_PA_BIAS", market_first + (6 * row_step), "PA Bias", SWV5_BiasText(priceAction.bias), BiasColor(priceAction.bias));
      Row("MARKET_PA_SCORE", market_first + (7 * row_step), "PA Score", "--", C'210,217,226');
      Row("MARKET_PA_CONFIDENCE", market_first + (8 * row_step), "PA Confidence",
          (priceAction.header.valid ? DoubleToString(priceAction.header.confidence, 2) : "--"), C'210,217,226');

      Row("DECISION_ACTION", decision_first, "Action", SWV5_ActionText(decision.action), ActionColor(decision.action));
      Row("DECISION_ADVICE", decision_first + row_step, "Advice", AdviceDisplay(decision), ActionColor(decision.action));

      Row("SYSTEM_TREND_REGRESSION", system_first, "Trend Reg", SWV5_TrendRegressionStatusText(trendRegression.status), RegressionColor(trendRegression.status));
      Row("SYSTEM_MOMENTUM_REGRESSION", system_first + row_step, "Momentum Reg", SWV5_MomentumRegressionStatusText(momentumRegression.status), MomentumRegressionColor(momentumRegression.status));
      Row("SYSTEM_MOMENTUM_REASON", system_first + (2 * row_step), "Reg Reason", momentumRegression.diagnostic_text, MomentumRegressionColor(momentumRegression.status));
      Row("SYSTEM_PA_BLOCK", system_first + (3 * row_step), "PA Block Reason", PriceActionBlockDisplay(priceAction, decision), ActionColor(decision.action));
      Row("SYSTEM_SCORE_CONTRACT", system_first + (4 * row_step), "Score Contract", LegacyScoreContractDisplay(legacy),
          (legacy.score_comparable_to_execution_threshold ? clrLime : clrTomato));
      Row("SYSTEM_HISTORY_STATE", system_first + (5 * row_step), "History State", SWV5_HistoryChangeText(engineInput.market.history_change_state),
          ((engineInput.market.header.data_quality_flags & SWV5_DQ_HISTORY_CHANGED) != 0 ? clrTomato : C'210,217,226'));
      Row("SYSTEM_STALE_STATE", system_first + (6 * row_step), "Stale State", SWV5_StaleStateText(engineInput.market.stale_state),
          ((engineInput.market.header.data_quality_flags & SWV5_DQ_STALE_DATA) != 0 ? clrTomato : C'210,217,226'));
      Row("SYSTEM_MODE", system_first + (7 * row_step), "Mode", SWV5_ExecutionModeText(engineInput.market.header.execution_mode), C'210,217,226');
      Row("SYSTEM_SNAPSHOT", system_first + (8 * row_step), "Snapshot",
          "V" + IntegerToString(engineInput.market.header.schema_version) + " #" + IntegerToString((int)engineInput.market.header.sequence), C'210,217,226');
      Row("SYSTEM_HISTORY", system_first + (9 * row_step), "History Gen",
          IntegerToString((int)engineInput.market.header.history_generation), C'210,217,226');

      if(m_dirty)
         ChartRedraw(0);
   }
};

#endif
