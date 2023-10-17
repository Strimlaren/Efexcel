//+------------------------------------------------------------------+
//|                                                 EEDFunctions.mqh |
//|                                                              MMC |
//|                                                   www.efexia.com |
//+------------------------------------------------------------------+
#property copyright "Copyright Efexia 2022"
#property link      "www.efexia.com"
#property version   "1.0"

double         current_drawdown, current_equity, highest_equity, margin, max_dd, margin_free, margin_level, profit, total_size, daily_drawdown;
int            L_A_D, symbolscount, log_handle;
long           local_account_number = AccountInfoInteger(ACCOUNT_LOGIN);
datetime       memory_array[1], ltime[87000], lltime[87000];
datetime       currenttime = TimeCurrent();
double         memory_array2[1], lequity[87000];
string         c[256], mw_symbol[];
string         A_N, S_N, ptype, otype;
MqlDateTime    time;
MqlDateTime    old_time;


void     SVN()
{
   for(int i = 0; i < 256; i++) c[i] = CharToString(i);

   L_A_D = (int)StringToTime( c[50]+c[48]+c[50]+c[50]      +c[46]
                             +c[49]+c[50]                  +c[46]
                             +c[51]+c[49]                  +c[32]

                             +c[50]+c[51]                  +c[58]
                             +c[53]+c[57]                  +c[58]
                             +c[48]+c[48]                         );

   //       1     0     2     5     4                       
   //A_N = c[49]+c[48]+c[50]+c[53]+c[52];
   //       F     C     I     M     a      r      k      e      t      s     -     L      i      v      e
   //S_N = c[70]+c[67]+c[73]+c[77]+c[97]+c[114]+c[107]+c[101]+c[116]+c[115]+c[45]+c[76]+c[105]+c[118]+c[101];

    //      4     9     9     9     1     2     9     8     8     8    
   //A_N = c[52]+c[57]+c[57]+c[57]+c[49]+c[50]+c[57]+c[56]+c[56]+c[56];
   //       M      e      t     a     Q      u      o      t      e      s     -     D      e      m      o
   //S_N = c[77]+c[101]+c[116]+c[97]+c[81]+c[117]+c[111]+c[116]+c[101]+c[115]+c[45]+c[68]+c[101]+c[109]+c[111];
}

int      EOnInit()
{
   if(TimeCurrent() >= L_A_D) 
   {
      MessageBox("License has expired! " + TimeToString(L_A_D,TIME_DATE|TIME_SECONDS),"License Expired!",MB_OK|MB_ICONSTOP);
      return(1);
   }
  
  Print("License valid until "+ TimeToString(L_A_D,TIME_DATE|TIME_SECONDS));
  return(0);
}

void     EOnTimer()
{
   if(TimeCurrent() >= L_A_D) 
   {
      MessageBox(("License has expired! " + TimeToString(L_A_D,TIME_DATE|TIME_SECONDS)),"License Expired!",MB_OK|MB_ICONSTOP);
      ExpertRemove();
   }
}

void     Calc()
{
   margin            = AccountInfoDouble(ACCOUNT_MARGIN);
   margin_free       = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   current_equity    = NormalizeDouble(AccountInfoDouble(ACCOUNT_EQUITY),2);
   profit            = AccountInfoDouble(ACCOUNT_PROFIT);
}

void     ExtractAccount(int filehandle, double y_equity)
{
   FileWrite(filehandle,  "ACCOUNT #", local_account_number);
   FileWrite(filehandle,  "EQUITY",      AccountInfoDouble(ACCOUNT_EQUITY),      "YESTERDAYS EQUITY", y_equity);
   FileWrite(filehandle,  "USED MARGIN", AccountInfoDouble(ACCOUNT_MARGIN),      "HIGHEST EQUITY",    GlobalVariableGet("highest_eq"));
   FileWrite(filehandle,  "FREE MARGIN", AccountInfoDouble(ACCOUNT_MARGIN_FREE), "DAILY DD",          daily_drawdown);
   FileWrite(filehandle,  "ACCOUNT P/L", AccountInfoDouble(ACCOUNT_PROFIT),      "PEAK DD",           max_dd);
}

void     ExtractSymbols(int filehandle, bool option)
{
   ArrayResize(mw_symbol,SymbolsTotal(option),SymbolsTotal(option));
   for(int i = 0; i < SymbolsTotal(option); i++) 
   {
      mw_symbol[i] = SymbolName(i, option);
      SymbolSelect(mw_symbol[i], true);
   }

   FileWrite(filehandle, "MARKET WATCH", local_account_number);
   FileWrite(filehandle, "SYMBOL", "BID", "ASK", "TOTAL SIZE");

   for(int i = 0; i < ArraySize(mw_symbol); i++)  
   {
   for(int u = 0; u < PositionsTotal(); u++)
   {
      ulong ticket = PositionGetTicket(u);
      PositionSelectByTicket(ticket);
      if(mw_symbol[i] == PositionGetString(POSITION_SYMBOL)) total_size = total_size + PositionGetDouble(POSITION_VOLUME);
   }

    FileWrite(filehandle, mw_symbol[i], SymbolInfoDouble(mw_symbol[i],SYMBOL_BID), SymbolInfoDouble(mw_symbol[i],SYMBOL_ASK), total_size);
    total_size = 0;
   }     
}

void     ExtractPositions(int filehandle)
{
   FileWrite(filehandle, "POSITIONS", local_account_number);
   FileWrite(filehandle, "SYMBOL", "TYPE", "VOLUME", "PRICE", "P/L", "STOP LOSS", "TAKE PROFIT");

   for(int i = 0; PositionsTotal() - 1 >= i; i++)
   {
      ulong ticket = PositionGetTicket(i);
      PositionSelectByTicket(ticket);
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         ptype = "Buy";
      else
         ptype = "Sell";

      FileWrite(filehandle, PositionGetString(POSITION_SYMBOL), ptype, PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN), PositionGetDouble(POSITION_PROFIT), PositionGetDouble(POSITION_SL), PositionGetDouble(POSITION_TP));
     }
}

void     ExtractOrders(int filehandle)
{
   FileWrite(filehandle, "PENDING ORDERS", local_account_number);
   FileWrite(filehandle, "SYMBOL", "TYPE", "VOLUME", "PRICE", "STOP LOSS", "TAKE PROFIT");

   for(int i = 0; OrdersTotal() - 1 >= i; i++)
   {
      ulong ticket = OrderGetTicket(i);
      if(OrderGetInteger(ORDER_TYPE) == 2) otype = "Buy Limit";
      if(OrderGetInteger(ORDER_TYPE) == 3) otype = "Sell Limit";
      if(OrderGetInteger(ORDER_TYPE) == 4) otype = "Buy Stop";
      if(OrderGetInteger(ORDER_TYPE) == 5) otype = "Sell Stop";
      if(OrderGetInteger(ORDER_TYPE) == 6) otype = "Buy Stop Limit";
      if(OrderGetInteger(ORDER_TYPE) == 7) otype = "Sell Stop Limit";
      
      if(OrderSelect(ticket)) FileWrite(filehandle, OrderGetString(ORDER_SYMBOL), otype, OrderGetDouble(ORDER_VOLUME_CURRENT), OrderGetDouble(ORDER_PRICE_OPEN), OrderGetDouble(ORDER_SL), OrderGetDouble(ORDER_TP));
   }
}

void     DeleteFiles(int option)
{
   if(option == 0)
   {
      if(FileIsExist((string)local_account_number + " Account Data.csv", FILE_COMMON))    FileDelete((string)local_account_number + " Account Data.csv", FILE_COMMON);
      if(FileIsExist((string)local_account_number + " Market Watch.csv", FILE_COMMON))    FileDelete((string)local_account_number + " Market Watch.csv", FILE_COMMON);
      if(FileIsExist((string)local_account_number + " Position Data.csv", FILE_COMMON))   FileDelete((string)local_account_number + " Position Data.csv", FILE_COMMON);
      if(FileIsExist((string)local_account_number + " Orders.csv", FILE_COMMON))          FileDelete((string)local_account_number + " Orders.csv", FILE_COMMON);
   }

   if(option == 1 && FileIsExist((string)local_account_number + " All Data.csv", FILE_COMMON)) FileDelete((string)local_account_number + " All Data.csv", FILE_COMMON);
}

void     ChartInfo()
{
  Comment("Licensed for " + (string)S_N + " to " + TimeToString(L_A_D,TIME_DATE)
      + "\n© Efexia Tech 2022"
      + "\n"
      + "\nLondon Time: " + TimeToString(TimeGMT() - TimeDaylightSavings(), TIME_DATE|TIME_MINUTES));
}

void     SaveEquity()
{
   memory_array[0] = TimeGMT() - TimeDaylightSavings();
   memory_array2[0] = AccountInfoDouble(ACCOUNT_EQUITY);
   FileSave((string)local_account_number + " time.bin", memory_array);
   FileSave((string)local_account_number + " eq.bin", memory_array2);
   Print("Local Time: " + TimeToString(TimeLocal(), TIME_DATE|TIME_MINUTES) + " London Time: " + TimeToString(TimeGMT() - TimeDaylightSavings(), TIME_DATE|TIME_MINUTES) + " Equity is: " + (string)AccountInfoDouble(ACCOUNT_EQUITY));
}

double   LoadEquity()
{
   FileLoad((string)local_account_number + " time.bin", memory_array);
   FileLoad((string)local_account_number + " eq.bin", memory_array2);
   TimeToStruct(TimeGMT() - TimeDaylightSavings(), time);
   TimeToStruct(memory_array[0], old_time);
  
   if(old_time.day_of_week == 5 && time.day_of_week == 1)
   {
   datetime tm = TimeGMT() - TimeDaylightSavings();
   datetime today = ((tm / 86400) * 86400);
   datetime saturday = today - 172800;
   datetime thursday = today - 259201;
   MqlDateTime mql_saturday;
   MqlDateTime mql_thursday;
   TimeToStruct(saturday, mql_saturday);
   TimeToStruct(thursday, mql_thursday);
   if(old_time.day_of_week > mql_thursday.day_of_week && old_time.day_of_week < mql_saturday.day_of_week) return(memory_array2[0]);
   }

   if(time.day_of_week > 0 && time.day_of_week < 6 && old_time.day_of_week != 5)
   {
   datetime tm = TimeGMT() - TimeDaylightSavings();
   datetime today = ((tm / 86400) * 86400);
   datetime dbyesterday = today - 86401;
   MqlDateTime mql_today;
   MqlDateTime mql_dby;
   TimeToStruct(today, mql_today);
   TimeToStruct(dbyesterday, mql_dby);
   if(old_time.day_of_week > mql_dby.day_of_week && old_time.day_of_week < mql_today.day_of_week) return(memory_array2[0]);      
   }
   return(AccountInfoDouble(ACCOUNT_EQUITY));
}   

void     EquityLog(datetime& local_time2[], datetime& london_time2[], double& logged_equity2[], int counter)
{
   log_handle = (int)TimeToString(TimeLocal());
   ArrayCopy(ltime, local_time2, 0, 0, WHOLE_ARRAY);
   ArrayCopy(lltime, london_time2, 0, 0, WHOLE_ARRAY);
   ArrayCopy(lequity, logged_equity2, 0, 0, WHOLE_ARRAY);

   string equityfolder  = (string)local_account_number + " Equity Logs";
   string source        = (string)local_account_number + " " + TimeToString(TimeGMT() - TimeDaylightSavings(),TIME_DATE) + " Equity Log.csv";
   string destination   = equityfolder + "//" + source;
   
   log_handle = FileOpen(source,FILE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);
   FileWrite(log_handle, "EQUITY LOG", local_account_number);
   FileWrite(log_handle, "LOCAL TIME", "LONDON TIME", "EQUITY");

   for(int i = 0; counter > i; i++)
   {
      FileWrite(log_handle, ltime[i], lltime[i], lequity[i]);
   }
   FileClose(log_handle);

   if(FileIsExist(equityfolder + "//" + source, FILE_COMMON)) FileMove(source, FILE_COMMON, destination, FILE_COMMON|FILE_REWRITE);
   else FileMove(source, FILE_COMMON, destination, FILE_COMMON);
}

void     DownloadLicense(string dl_url)
{
   string cookie = NULL, header;
   char post[], result[];
   int res; int timeout = 5000;
   string download_path = dl_url;
   ResetLastError();
   //https://drive.google.com/file/d/1bN5g-cOOPGLlYIgVAoxEmDs-_t_VkvNM/view?usp=sharing/EFEXIADATA.license
   res = WebRequest("GET", dl_url, NULL, timeout, post, result, header);

   if(res == -1)
     {
      Print("Error in WebRequest. Error code  =",GetLastError());
      MessageBox("Add the address '"+dl_url+"' in the list of allowed URLs on tab 'Expert Advisors'","Error",MB_ICONINFORMATION);
     }
   else
     {
      PrintFormat("The file has been successfully loaded, File size =%d bytes.",ArraySize(result));

      int filehandle = FileOpen("EFEXIADATA.license",FILE_WRITE|FILE_BIN);

      if(filehandle != INVALID_HANDLE)
        {
         FileWriteArray(filehandle, result, 0, ArraySize(result));
         FileClose(filehandle);
        }
      else Print("Error in FileOpen. Error code=",GetLastError());
     }
}

bool     IsNewCandle(ENUM_TIMEFRAMES time_frame)                                              
{
   static int BarsOnChart = 0;
   if(Bars(Symbol(),time_frame) == BarsOnChart) return(false);
   BarsOnChart = Bars(Symbol(),time_frame);
   return(true);
}