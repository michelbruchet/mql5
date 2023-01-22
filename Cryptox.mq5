//+------------------------------------------------------------------+
//|                                                      Cryptox.mq5 |
//|                                                   Michel Bruchet |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Michel Bruchet"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include<Trade\Trade.mqh>

// Inputs

input double InpTPPercentage         = 3;        // Take profit Percentage
input double InpSLPercentage         = 2;         // Stop Loss Percentage
input double InpTradeLot             = 0.3;       // Lot size
input int    InpAtrPeriod            = 5;         // Atr Period
input int    InpRsiPeriod            = 15;        // Rsi Period
input int    InpMAFastPeriod         = 10;        // Fast MA Period
input int    InpMASlowPeriod         = 20;        // Slow MA Period
input double InpAtrThreshold         = 1.40;      // ATr Threshold
input int    InpRsiThreshold         = 30;        // Rsi Threshold
input double InpMinProfitAmount      = 4;         // Mini profit threshold
input double InpSpreadMATheshold     = 0.5;      // Spread for MA
input double InpLastSpreadMATheshold = 1;      // Spread for MA

// Variables
double       lastPrice;             // Last price
double       stopLoss;              // Stop Loss level
double       takeProfit;            // Take Profit
double      lastMAFast;             // Last MA Fast

//Handlers
int atrHandler, rsiHandler, maFastHandler, maSlowHandler;
int nbDirectionReversal=0;

//Buffers
double atrBuffer[];
double rsiBuffer[];
double maFastBuffer[];
double maSlowBuffer[];

int stops_level;

CTrade trade;

double Goal= 7.00;
string lastMaSignal = "";
double lastSpreadMA = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---

//Handler
   atrHandler = iATR(_Symbol, _Period, InpAtrPeriod);
   rsiHandler = iRSI(_Symbol, _Period, InpRsiPeriod, PRICE_CLOSE);
   maFastHandler = iMA(_Symbol, _Period, InpMAFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
   maSlowHandler = iMA(_Symbol, _Period, InpMASlowPeriod, 0, MODE_EMA, PRICE_CLOSE);

   ArraySetAsSeries(atrBuffer, true);
   ArraySetAsSeries(rsiBuffer, true);
   ArraySetAsSeries(maFastBuffer, true);
   ArraySetAsSeries(maSlowBuffer, true);

   stops_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);

   Alert("Start Cryptox bot");

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

   Alert("Stop Cryptox bot");

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

//Buffer
   CopyBuffer(atrHandler, 0, 0, 1, atrBuffer);
   CopyBuffer(rsiHandler, 0, 0, 1, rsiBuffer);
   CopyBuffer(maFastHandler, 0, 0, 1, maFastBuffer);
   CopyBuffer(maSlowHandler, 0, 0, 1, maSlowBuffer);

   double atr = atrBuffer[0];
   double rsi = rsiBuffer[0];
   double maFast = maFastBuffer[0];
   double maSlow = maSlowBuffer[0];

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(lastPrice == 0)
     {
      lastPrice = currentPrice;
      return;
     }

   string direction = "";
   string directionMA = "";

   if(currentPrice > lastPrice)
      direction = "UP";
   else
      if(currentPrice < lastPrice)
         direction = "DOWN";
      else
         direction = "HOLD";

   if(lastMAFast > maFast)
      directionMA = "DOWN";
   else
      if(lastMAFast < maFast)
         directionMA = "UP";
      else
         directionMA = "HOLD";

   string signal = "HOLD";

   double spreadMA = MathAbs(maFast - maSlow);

   if(direction == "UP" && directionMA == "UP"
      && maSlow <= maFast && spreadMA > InpSpreadMATheshold
      && rsi > InpRsiThreshold
      && atr > InpAtrThreshold)
      signal = "BUY";

   datetime current_time = iTime(_Symbol, _Period, 0);

   Print("symbol ", _Symbol, " date ", current_time,
         " Signal=", signal, " Direction=", direction, " Current price=",
         DoubleToString(currentPrice), "\n", " last price=", DoubleToString(lastPrice),
         " rsi=", DoubleToString(rsi) + "/" + DoubleToString(InpRsiThreshold),
         " atr=", DoubleToString(atr) + "/" + DoubleToString(InpAtrThreshold), "\n",
         " MA Fast=", DoubleToString(maFast), " MA Slow=", DoubleToString(maSlow),
         " Direction MA=", directionMA,
         " Spread MA=", spreadMA,
         " last MA Signal=", lastMaSignal);

   if(PositionsTotal() == 1 && PositionSelect(_Symbol))
     {
      //Existing position
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(profit > InpMinProfitAmount)
        {
         if(trade.PositionClose(_Symbol, 3))
           {
            Print("close profit profit=", DoubleToString(profit));
           }
        }
      else
        {
         Print("current profit=", DoubleToString(profit));
        }
     }
   else
      if(signal == "BUY")
        {
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         stopLoss =NormalizeDouble(bid * (1-InpSLPercentage / 100),_Digits);
         takeProfit =NormalizeDouble(bid * (1+InpTPPercentage / 100),_Digits);

         MqlTradeRequest request = {};
         request.action = TRADE_ACTION_DEAL;
         request.symbol = _Symbol;
         request.volume = InpTradeLot;
         request.type = ORDER_TYPE_BUY;
         request.price = ask;
         request.deviation = 3;
         request.comment = "Cryptox bot buy action";
         request.sl = stopLoss;
         request.tp = takeProfit;

         MqlTradeResult result = {};

         ResetLastError();

         if(OrderSend(request, result))
           {
            Print("Order send long position successfully, ticket is ", result.order);
           }
         else
           {
            Print("Can not open long position last error ", _LastError);
           }
        }

   lastPrice = currentPrice;

   lastMaSignal = "HOLD";
   lastSpreadMA = -1;

   if(maFast > maSlow)
      lastMaSignal = "UP";
   if(maFast < maSlow)
      lastMaSignal = "DOWN";

   lastSpreadMA = MathAbs(maFast - maSlow);

  }
//+------------------------------------------------------------------+