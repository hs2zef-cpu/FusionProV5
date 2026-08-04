#ifndef SW_V5_REGRESSION_CSV_WRITER_MQH
#define SW_V5_REGRESSION_CSV_WRITER_MQH

#include "..\\Regression\\SW_V5_TrendRegression.mqh"
#include "..\\Regression\\SW_V5_MomentumRegression.mqh"

class CRegressionCsvWriter
{
private:
   int    m_trendHandle;
   int    m_momentumHandle;
   ulong  m_lastTrendSequence;
   ulong  m_lastTrendGeneration;
   ulong  m_lastMomentumSequence;
   ulong  m_lastMomentumGeneration;
   bool   m_trendEnabled;
   bool   m_momentumEnabled;
   string m_lastError;

   string CsvField(const string value)
   {
      string escaped = value;
      StringReplace(escaped, "\"", "\"\"");
      return "\"" + escaped + "\"";
   }

   string EvidenceHeader(const string regressionHeader)
   {
      return regressionHeader +
             ",observed_history_generation,last_valid_history_generation,history_token_valid" +
             ",history_change_reason,snapshot_usable,final_action,final_decision_reason";
   }

   string EvidenceFields(const SWV5_EngineInput &engineInput,
                         const SWV5_DecisionResult &decision)
   {
      const SWV5_MarketSnapshot market = engineInput.market;
      return IntegerToString((int)market.observed_history_generation) + "," +
             IntegerToString((int)market.last_valid_history_generation) + "," +
             (market.history_token_valid ? "true" : "false") + "," +
             CsvField(SWV5_HistoryReasonText(market.history_reason)) + "," +
             (market.snapshot_usable ? "true" : "false") + "," +
             CsvField(SWV5_ActionText(decision.action)) + "," +
             CsvField(decision.header.reason_text);
   }

   int OpenEvidenceFile(const string fileName, const string header)
   {
      int handle = FileOpen(fileName, FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ);
      if(handle == INVALID_HANDLE)
      {
         if(m_lastError != "") m_lastError += "; ";
         m_lastError += "Cannot open regression CSV " + fileName + "; error=" + IntegerToString(GetLastError());
         return INVALID_HANDLE;
      }
      if(FileSize(handle) == 0)
         FileWriteString(handle, header + "\r\n");
      FileSeek(handle, 0, SEEK_END);
      return handle;
   }

   bool AppendRow(const int handle, const string row)
   {
      if(handle == INVALID_HANDLE)
         return false;
      if(FileWriteString(handle, row + "\r\n") <= 0)
      {
         m_lastError = "Regression CSV write failed; error=" + IntegerToString(GetLastError());
         return false;
      }
      FileFlush(handle);
      return true;
   }

public:
   CRegressionCsvWriter()
   {
      m_trendHandle = INVALID_HANDLE;
      m_momentumHandle = INVALID_HANDLE;
      m_lastTrendSequence = 0;
      m_lastTrendGeneration = 0;
      m_lastMomentumSequence = 0;
      m_lastMomentumGeneration = 0;
      m_trendEnabled = false;
      m_momentumEnabled = false;
      m_lastError = "";
   }

   bool Init(const bool trendEnabled,
             const bool momentumEnabled,
             const string trendHeader,
             const string momentumHeader)
   {
      m_trendEnabled = trendEnabled;
      m_momentumEnabled = momentumEnabled;
      m_lastError = "";
      bool ok = true;
      if(m_trendEnabled)
      {
         m_trendHandle = OpenEvidenceFile("SWV5_SPRINT3_2_1_TREND_REGRESSION.csv", EvidenceHeader(trendHeader));
         if(m_trendHandle == INVALID_HANDLE) ok = false;
      }
      if(m_momentumEnabled)
      {
         m_momentumHandle = OpenEvidenceFile("SWV5_SPRINT3_2_1_MOMENTUM_REGRESSION.csv", EvidenceHeader(momentumHeader));
         if(m_momentumHandle == INVALID_HANDLE) ok = false;
      }
      return ok;
   }

   void Deinit()
   {
      if(m_trendHandle != INVALID_HANDLE) FileClose(m_trendHandle);
      if(m_momentumHandle != INVALID_HANDLE) FileClose(m_momentumHandle);
      m_trendHandle = INVALID_HANDLE;
      m_momentumHandle = INVALID_HANDLE;
   }

   string LastError()
   {
      return m_lastError;
   }

   void ClearError()
   {
      m_lastError = "";
   }

   bool WriteTrend(const SWV5_TrendRegressionResult &result,
                   const SWV5_EngineInput &engineInput,
                   const SWV5_DecisionResult &decision)
   {
      if(!m_trendEnabled || m_trendHandle == INVALID_HANDLE)
         return false;
      if(result.snapshot_sequence == m_lastTrendSequence && result.history_generation == m_lastTrendGeneration)
         return true;
      if(!AppendRow(m_trendHandle, result.csv_row + "," + EvidenceFields(engineInput, decision)))
         return false;
      m_lastTrendSequence = result.snapshot_sequence;
      m_lastTrendGeneration = result.history_generation;
      return true;
   }

   bool WriteMomentum(const SWV5_MomentumRegressionResult &result,
                      const SWV5_EngineInput &engineInput,
                      const SWV5_DecisionResult &decision)
   {
      if(!m_momentumEnabled || m_momentumHandle == INVALID_HANDLE)
         return false;
      if(result.snapshot_sequence == m_lastMomentumSequence && result.history_generation == m_lastMomentumGeneration)
         return true;
      if(!AppendRow(m_momentumHandle, result.csv_row + "," + EvidenceFields(engineInput, decision)))
         return false;
      m_lastMomentumSequence = result.snapshot_sequence;
      m_lastMomentumGeneration = result.history_generation;
      return true;
   }
};

#endif
