#property copyright     "Copyright Efexia 2022"
#property link          "www.efexia.com"
#property version       "1.1"
#property description   " New in 1.1:\n- Added functionality for auto-closing of positions and orders by Drawdown and Equity.
                                     \n- Added textbased info-field, and option to turn it off.
                                     \n- Numerous glitch fixes.
                                     \n\nNOTE:
                                     \nMake sure Algo Trading is enabled in Terminal settings, and Allow Algo Trading is checked below to enable the auto-close risk features."

#include <EEDFunctions.mqh>
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>  
#include <Trade/OrderInfo.mqh>

CTrade         mTrade;
CPositionInfo  m_position;
CSymbolInfo    m_symbol;
COrderInfo     m_order;

enum section1              {
                           Value                              // === File Writing Options ===
                           };
enum section2              {
                           Value                              // === Risk Management ===
                           };
enum section3              {
                           Value                              // === Equity Log Options ===
                           };
enum section4              {
                           Value                              // === Miscellenous Settings ===
                           };     
enum section5              {
                           Value                              // === Indicator 1 Settings ===
                           };                                                
enum binary_options        {
                           Yes                   = 1,         // On
                           No                    = 0          // Off
                           };
enum symbols_options       {
                           AllSymbols            = 1,         // All Symbols
                           MWSymbols             = 0          // Market Watch Symbols
                           };
enum file_options          {
                           AllInOneFile          = 0,         // All-In-One File
                           SeparateFiles         = 1,         // Separate Files
                           Both                  = 2          // Both
                           };                        
enum data_refresh_rate     {
                           OneS                  = 1,         //1 Second
                           FiveS                 = 5,         //5 Seconds
                           FifteenS              = 15,        //15 Seconds
                           ThirtyS               = 30,        //30 Seconds
                           FourtyFiveS           = 45,        //45 Seconds
                           SixtyS                = 60         //1 Minute
                           };
enum equity_log_tf         {
                           M1                    = PERIOD_M1, //1 Minute
                           M5                    = PERIOD_M5, //5 Minutes
                           M10                   = PERIOD_M10,//10 Minutes
                           M15                   = PERIOD_M15,//15 Minutes
                           M30                   = PERIOD_M30,//30 Minutes
                           H1                    = PERIOD_H1, //1 Hour
                           H2                    = PERIOD_H2, //2 Hours
                           H4                    = PERIOD_H4, //4 Hours
                           H6                    = PERIOD_H6  //6 Hours
                           };

input section1             file_write_title;                  // === File Writing Options ===
input file_options         filewrite_option     = 2;          // File Option
input binary_options       account_data         = 1;          // Export Account Data
input binary_options       market_watch         = 1;          // Export Market Watch Data
input binary_options       position_data        = 1;          // Export Positions Data
input binary_options       pending_orders       = 1;          // Export Pending Orders Data
input data_refresh_rate    refresh_rate         = 1;          // Data Refresh Rate (s)
input section2             risk_title;                        // === Risk Management ===
input double               close_all_drawdown   = 0;          // Close all on set % Drawdown. 0 = Off
input double               close_all_equity     = 0;          // Close all on set Equity. 0 = Off
input section3             equity_log_title;                  // === Equity Log Options ===
input binary_options       equity_log           = 1;          // Equity Log
input equity_log_tf        eq_log_rate          = H1;         // Equity Log Frequency
input section4             misc_title;                        // === Miscellenous Settings ===
input symbols_options      symbols_option       = 0;          // Extracted Symbols
input binary_options       chart_infos          = 1;          // Show chart information
//input string               url;                             // License adress
//input section5             indicator_one_title;             // === Indicator 1 Settings ===
//input string               ind_symbol;                      // Symbol Name
//input ENUM_TIMEFRAMES      ind_timeframe;                   // Timeframe
//input ENUM_INDICATOR       ind_indicator;                   // Indicator

bool           ddreset = false, s_option, LicenseValid = true, eq_larmed = false, dd_larmed = false, terminal_on_midnight = true;
int            all_handle, TEST_handle, account_handle, positions_handle, market_watch_handle, orders_handle, memory_handle, mem_day, custom_indicator;
int            eq_log_counter = 0, alarm_count = 0;
double         equity_limit   = 0;
double         yesterdays_equity, last_eq, old_close_all_drawdown, old_close_all_equity, abs_close_all_drawdown;
double         logged_equity[87000], indicator_buffer[];
string         eq_larmcomment, dd_larmcomment, ddd_string, pdd_string, terminal_trade, expert_trade, phone_notifications, email_notifications;
MqlDateTime    eq_time;
datetime       local_time[87000], london_time[87000];


int OnInit()
{
   EventSetTimer(refresh_rate); SVN(); EOnInit();
   TimeToStruct(TimeGMT() - TimeDaylightSavings(), time);
   FolderCreate((string)local_account_number + " Equity Logs", FILE_COMMON);

          //+-------------A-L-A-R-M----R-E-S-E-T-------------------+//
          //|             A L A R M    R E S E T                   |//
          //+------------------------------------------------------+//

   if(close_all_equity != old_close_all_equity && eq_larmed == true) eq_larmed = false;
   if(close_all_drawdown != old_close_all_drawdown && dd_larmed == true) dd_larmed = false;

   if(terminal_on_midnight == true) { GlobalVariableSet("highest_eq", AccountInfoDouble(ACCOUNT_EQUITY)); terminal_on_midnight = false; }

   if(!GlobalVariableCheck("highest_eq")) GlobalVariableSet("highest_eq", AccountInfoDouble(ACCOUNT_EQUITY));

   if(symbols_option == 0) s_option = true; else s_option = false;

   yesterdays_equity = LoadEquity();
   if(yesterdays_equity == 0) yesterdays_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   daily_drawdown    = AccountInfoDouble(ACCOUNT_EQUITY) / yesterdays_equity - 1;
   
   /*if(AccountInfoString(ACCOUNT_SERVER) != S_N)   // FOR TESTING PURPOSES, NO ACCOUNT CHECK IS BEING PERFORMED
      {
      MessageBox("Unauthorised Server. \nOnly for use on " + S_N + " accounts.","Error!",MB_OK|MB_ICONSTOP);
      return(INIT_FAILED);
      }*/
   
   if(EOnInit() == 1) return(INIT_FAILED);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   Comment("");
}

void OnTimer()
{
   TimeToStruct(TimeGMT() - TimeDaylightSavings(), time);
   Calc(); EOnTimer();
   if(chart_infos == 1) ChartInfo(); else Comment("");
   current_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
          //+--------D-R-A-W-D-O-W-N---M-A-N-A-G-E-M-E-N-T---------+//
          //|        D R A W D O W N   M A N A G E M E N T         |//
          //+------------------------------------------------------+//
   
   Print(GlobalVariableGet("highest_eq"));
   daily_drawdown = current_equity / yesterdays_equity - 1;
   if(daily_drawdown >= 0) daily_drawdown = 0;

   if(current_equity > GlobalVariableGet("highest_eq")) GlobalVariableSet("highest_eq", current_equity);
   if(current_equity < GlobalVariableGet("highest_eq")) current_drawdown = current_equity / GlobalVariableGet("highest_eq") - 1;
   if(current_drawdown < max_dd) max_dd = current_drawdown;
   if(current_drawdown >= 0) current_drawdown = 0;                                                
   
          //+-------------F-I-L-E---C-R-E-A-T-I-O-N----------------+//
          //|             F I L E   C R E A T I O N                |//
          //+------------------------------------------------------+//
   
   if (filewrite_option == 0 || filewrite_option == 2)
   {
      DeleteFiles(filewrite_option);
      all_handle = FileOpen((string)local_account_number + " All Data.csv",FILE_SHARE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON);

      if (account_data == 1) { ExtractAccount(all_handle, yesterdays_equity, max_dd, daily_drawdown); FileWrite(all_handle,  ""); }
      if (market_watch == 1) { ExtractSymbols(all_handle, s_option); FileWrite(all_handle,  ""); }
      if (position_data == 1) { ExtractPositions(all_handle); FileWrite(all_handle,  ""); }
      if (pending_orders == 1) ExtractOrders(all_handle);
   
      FileClose(all_handle);
   }

   if (filewrite_option == 1 || filewrite_option == 2)
   {
      DeleteFiles(filewrite_option);
      if (account_data == 1) 
      {
         account_handle = FileOpen((string)local_account_number + " Account Data.csv",FILE_SHARE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON); 
         ExtractAccount(all_handle, yesterdays_equity, max_dd, daily_drawdown);
         FileClose(account_handle);
      }

      if (market_watch == 1) 
      {
         market_watch_handle = FileOpen((string)local_account_number + " Market Watch.csv",FILE_SHARE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON); 
         ExtractSymbols(market_watch_handle, s_option);
         FileClose(market_watch_handle);
      }

      if (position_data == 1) 
      {
         positions_handle = FileOpen((string)local_account_number + " Position Data.csv",FILE_SHARE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON); 
         ExtractPositions(positions_handle);;
         FileClose(positions_handle);
      }

      if (pending_orders == 1) 
      {
         orders_handle = FileOpen((string)local_account_number + " Orders.csv",FILE_SHARE_READ|FILE_WRITE|FILE_CSV|FILE_COMMON); 
         ExtractOrders(orders_handle);;
         FileClose(orders_handle);
      }
   }

          //+----------E-Q-U-I-T-Y---R-E-S-E-T---&---L-O-G---------+//
          //|          E Q U I T Y   R E S E T   &   L O G         |//
          //+------------------------------------------------------+//

   if(IsNewCandle((ENUM_TIMEFRAMES)eq_log_rate) && equity_log == 1)
   {
      local_time[eq_log_counter]   = TimeLocal();
      london_time[eq_log_counter]   = TimeGMT() - TimeDaylightSavings();
      logged_equity[eq_log_counter] = AccountInfoDouble(ACCOUNT_EQUITY);
      eq_log_counter++;
   }

   if(time.hour == 0 && time.min > 5 && ddreset == true) ddreset = false;

   if(time.hour == 0 && time.min < 5 && ddreset == false)
   {
      max_dd            = 0;
      current_drawdown  = 0;
      ddreset           = true;
      GlobalVariableSet("highest_eq", AccountInfoDouble(ACCOUNT_EQUITY));
      terminal_on_midnight = false;

      if(equity_log == 1 && time.day_of_week != 6 && time.day_of_week != 0)
      {
         EquityLog(local_time, london_time, logged_equity, eq_log_counter);
         eq_log_counter    = 0;
         ArrayRemove(local_time, 0, WHOLE_ARRAY);
         ArrayRemove(logged_equity, 0, WHOLE_ARRAY);
         Print("Equity log file for " + TimeToString(TimeLocal(),TIME_DATE|TIME_SECONDS) + " created.");
      }

      if(time.day_of_week != 6 && time.day_of_week != 0) SaveEquity();

      yesterdays_equity = LoadEquity();
   }

          //+----------R-I-S-K---M-A-N-A-G-E-M-E-N-T---------------+//
          //|          R I S K   M A N A G E M E N T               |//
          //+------------------------------------------------------+//

   if(close_all_equity > 0)
      {
         if(AccountInfoDouble(ACCOUNT_EQUITY) <= close_all_equity && eq_larmed == false)
            {
               for(int i = PositionsTotal() - 1; i >= 0; i--){
                  if(m_position.SelectByIndex(i)) mTrade.PositionClose(m_position.Ticket());
                  }
               for(int i = OrdersTotal() - 1; i >= 0; i--){
                  if(m_order.SelectByIndex(i)) mTrade.OrderDelete(m_order.Ticket());
                  }

            old_close_all_equity = close_all_equity;
            eq_larmed = true;

            if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED)) 
               {
               SendNotification("Equity limit (" + (string)close_all_equity + ") reached. All positions and orders were closed.");
               Print("Equity limit (" + (string)close_all_equity + ") reached. All positions and orders were closed.");
               MessageBox("Equity limit (" + (string)close_all_equity + ") reached. \nAll positions and orders were closed.\n\nNOTE: To reactivate the Equity alarm, you must set the\nEquity alarm to a new value.", "Equity Limit", MB_OK|MB_ICONSTOP);
               SendMail("EED Equity Limit Close", "Equity limit (" + (string)close_all_equity + ") reached. All positions and orders were closed.");
               }
            else
               {
               SendNotification("Equity limit (" + (string)close_all_equity + ") reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               Print("Equity limit (" + (string)close_all_equity + ") reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               MessageBox("Equity limit (" + (string)close_all_equity + ") reached. \nWARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.", "Equity Limit", MB_OK|MB_ICONSTOP);
               SendMail("EED Equity Limit Close", "Equity limit (" + (string)close_all_equity + ") reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               }
            }
         
      }

   abs_close_all_drawdown = (MathAbs(close_all_drawdown)/100)*-1;

   if(close_all_drawdown != 0)
      {
         if(daily_drawdown <= abs_close_all_drawdown && dd_larmed == false)
            {
               for(int i = PositionsTotal() - 1; i >= 0; i--){
                  if(m_position.SelectByIndex(i)) mTrade.PositionClose(m_position.Ticket());
                  }
               for(int i=OrdersTotal() -1; i >= 0; i--){
                  if(m_order.SelectByIndex(i)) mTrade.OrderDelete(m_order.Ticket());
                  }

            old_close_all_drawdown = close_all_drawdown;
            dd_larmed = true;

            if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) && MQLInfoInteger(MQL_TRADE_ALLOWED)) 
               {
               SendNotification("Drawdown limit (" + (string)(abs_close_all_drawdown*100) + "%) reached. All positions and orders were closed.");
               Print("Drawdown limit (" + (string)(abs_close_all_drawdown*100) + "%) reached. All positions and orders were closed.");
               MessageBox("Drawdown limit (" + (string)(abs_close_all_drawdown*100) + "%) reached. \nAll positions and orders were closed.\n\nNOTE: To reactivate the Drawdown alarm, you must set the\nDrawdown alarm to a new value.", "Drawdown Limit", MB_OK|MB_ICONSTOP);
               SendMail("EED Drawdown Limit Close", "Drawdown limit (" + (string)abs_close_all_drawdown + ") reached. All positions and orders were closed.");
               }
            else
               {
               SendNotification("Drawdown limit (" + (string)(abs_close_all_drawdown*100) + "%) reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               Print("Drawdown limit (" + (string)(abs_close_all_drawdown * 100) + "%) reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               MessageBox("Drawdown limit (" + (string)(abs_close_all_drawdown*100) + "%) reached. \nWARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.", "Drawdown Limit", MB_OK|MB_ICONSTOP);
               SendMail("EED Drawdown Limit Close", "Drawdown limit (" + (string)abs_close_all_drawdown + ") reached. WARNING! Positions and orders were NOT closed due to Algo Trading set to OFF.");
               }
            }
      }

}


void     ChartInfo()
{
   if(eq_larmed) eq_larmcomment = "(Larmed)"; else eq_larmcomment = "";
   if(dd_larmed) dd_larmcomment = "(Larmed)"; else dd_larmcomment = "";
   if(daily_drawdown < 0)     ddd_string = (string)NormalizeDouble((daily_drawdown*100), 4); else ddd_string = "0";
   if(current_drawdown < 0)  pdd_string = (string)NormalizeDouble((max_dd*100), 4);   else pdd_string = "0";
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) terminal_trade = "ON"; else terminal_trade = "OFF";
   if(MQLInfoInteger(MQL_TRADE_ALLOWED)) expert_trade = "ON"; else expert_trade = "OFF";
   if(TerminalInfoInteger(TERMINAL_NOTIFICATIONS_ENABLED)) phone_notifications = "ON"; else phone_notifications = "OFF";
   if(TerminalInfoInteger(TERMINAL_EMAIL_ENABLED)) email_notifications = "ON"; else email_notifications = "OFF";

   Comment(" Licensed for " + (string)S_N + " to " + TimeToString(L_A_D,TIME_DATE)
      + "\n London Time: " + TimeToString(TimeGMT() - TimeDaylightSavings(), TIME_DATE|TIME_MINUTES)
      + "\n © Efexia 2022"
      + "\n\n"
      + " Daily DD: " + ddd_string
      + "%\n Peak DD: " + pdd_string
      + "%\n" + dd_larmcomment + " Daily DD Limit: " + (string)(abs_close_all_drawdown*100) 
      + "%\n" + eq_larmcomment + " Equity Limit: " + (string)close_all_equity
      + "\n Yesterdays Equity: " + (string)yesterdays_equity
      + "\n Highest Equity: " + (string)GlobalVariableGet("highest_eq")
      + "\n\n Terminal Algo Trading: " + terminal_trade
      + "\n Expert Algo Trading: " + expert_trade
      + "\n\n Phone Notifications: " + phone_notifications
      + "\n Email Notifications: " + email_notifications);
}

// - T E S T I N G   O F   C O D E


//   T O - D O   L I S T
// - How to make two apps communicate and present aggregate data over several accounts?
// - Equity Log last entry is not 23:00 London time.
// - Remote Licensing.
// - User Interface.
// - DD Values need to stay even if restarting terminal / app?
// - Peak DD needs to set to 0 if user didnt have app on at market closure.
// - Extraction of a few set indicators.
// - Extraction of detailed OHLC data.
// - Output the log every one hour.

//   D O N E   F R O M   T O - D O   L I S T
// - Excel can sometimes not find files. Possible to fix this?
// - Other Terminals not able to output files, only DEV MT5 can, and its corrupted.
// - Timehandling in the app. Charttime/localtime/londontime?
// - Add option to extract all symbols available to the account or just market watch ones.
// - Possible to give the user the option to choose file output destination?
// - PEAK DD is reset every time timeframe changes.
// - Does the yesterdays_equity code work?
// - Start working with indicators. Is it possible to detect indicators on a chart?
// - Highest Equity should not reset if terminal is rebooted.
// - Get emergency exit all positions on equity / DD.