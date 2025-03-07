//+------------------------------------------------------------------+
// Squeeze Momentum indicator (lazybear)                             |
// Rewritten by Hamoon Soleimani                                     |
//+------------------------------------------------------------------+

#property copyright "Hamoon Soleimani"
#property link      "https://www.hamoon.net/"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 10
#property indicator_plots   7

// Indicator plot definitions
#property indicator_type1   DRAW_NONE
#property indicator_type2   DRAW_HISTOGRAM
#property indicator_color2  clrLime
#property indicator_width2  2
#property indicator_type3   DRAW_HISTOGRAM
#property indicator_color3  clrGreen
#property indicator_width3  2
#property indicator_type4   DRAW_HISTOGRAM
#property indicator_color4  clrRed
#property indicator_width4  2
#property indicator_type5   DRAW_HISTOGRAM
#property indicator_color5  clrMaroon
#property indicator_width5  2
#property indicator_type6   DRAW_ARROW
#property indicator_color6  clrBlue
#property indicator_width6  2
#property indicator_type7   DRAW_ARROW
#property indicator_color7  clrBlack
#property indicator_width7  2
#property indicator_type8   DRAW_ARROW
#property indicator_color8  clrGray
#property indicator_width8  2

input int    BBLength       = 20;   // BB Length
input double BBMult         = 2.0;  // BB MultFactor
input int    KCLength       = 20;   // KC Length
input double KCMult         = 1.5;  // KC MultFactor
input bool   useTrueRange   = true; // Use TrueRange (KC)

// Buffers
double range[];
double no[];
double On[];
double Off[];
double linregsrc[];
double upup[];
double updn[];
double dndn[];
double dnup[];
double linreg[];

int OnInit() {
    SetIndexBuffer(0, range, INDICATOR_DATA);
    SetIndexBuffer(1, upup, INDICATOR_DATA);
    SetIndexBuffer(2, updn, INDICATOR_DATA);
    SetIndexBuffer(3, dndn, INDICATOR_DATA);
    SetIndexBuffer(4, dnup, INDICATOR_DATA);
    SetIndexBuffer(5, no, INDICATOR_DATA);
    SetIndexBuffer(6, On, INDICATOR_DATA);
    SetIndexBuffer(7, Off, INDICATOR_DATA);
    SetIndexBuffer(8, linregsrc, INDICATOR_DATA);
    SetIndexBuffer(9, linreg, INDICATOR_DATA);

    // Labels
    PlotIndexSetString(0, PLOT_LABEL, "Range");
    PlotIndexSetString(1, PLOT_LABEL, "Up Up");
    PlotIndexSetString(2, PLOT_LABEL, "Up Down");
    PlotIndexSetString(3, PLOT_LABEL, "Down Down");
    PlotIndexSetString(4, PLOT_LABEL, "Down Up");
    PlotIndexSetString(5, PLOT_LABEL, "No Squeeze");
    PlotIndexSetString(6, PLOT_LABEL, "Squeeze On");
    PlotIndexSetString(7, PLOT_LABEL, "Squeeze Off");

    // Arrow settings
    PlotIndexSetInteger(5, PLOT_ARROW, 167);
    PlotIndexSetInteger(6, PLOT_ARROW, 167);
    PlotIndexSetInteger(7, PLOT_ARROW, 167);

    return(INIT_SUCCEEDED);
}

// Custom moving average function to replace iMA
double CustomMA(const double &close[], int period, int pos) {
    double sum = 0;
    for(int i = 0; i < period; i++) {
        sum += close[pos + i];
    }
    return sum / period;
}

// Custom standard deviation function to replace iStdDev
double CustomStdDev(const double &close[], int period, int pos) {
    double mean = CustomMA(close, period, pos);
    double sumSqrDev = 0;
    
    for(int i = 0; i < period; i++) {
        double dev = close[pos + i] - mean;
        sumSqrDev += dev * dev;
    }
    
    return MathSqrt(sumSqrDev / period);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[]) {
    
    int startPos = rates_total - prev_calculated - KCLength - 2;
    if (startPos <= 1) startPos = 1;
    
    for (int pos = startPos; pos >= 0; pos--) {
        // Calculate BB
        double basis = CustomMA(close, BBLength, pos);
        double dev = BBMult * CustomStdDev(close, BBLength, pos);
        double upperBB = basis + dev;
        double lowerBB = basis - dev;
        
        // Calculate KC
        double ma = CustomMA(close, KCLength, pos);
        range[pos] = useTrueRange ? TR(pos, high, low, close) : (high[pos] - low[pos]);
        
        // Manual moving average calculation for range
        double rangema = 0;
        for (int i = 0; i < KCLength; i++) {
            rangema += range[pos+i];
        }
        rangema /= KCLength;
        
        double upperKC = ma + rangema * KCMult;
        double lowerKC = ma - rangema * KCMult;

        bool sqzOn  = (lowerBB > lowerKC) && (upperBB < upperKC);
        bool sqzOff = (lowerBB < lowerKC) && (upperBB > upperKC);
        bool noSqz  = (sqzOn == false) && (sqzOff == false);
        
        double highest = High(KCLength, pos, high);
        double lowest  = Low(KCLength, pos, low);
        double sma     = CustomMA(close, KCLength, pos);
        
        linregsrc[pos] = close[pos] - (((highest + lowest) / 2) + sma) / 2;
        linreg[pos]    = LinearRegression(linregsrc, KCLength, pos);
        
        upup[pos] = (linreg[pos] > 0 && linreg[pos] > NZ(linreg[pos+1])) ? linreg[pos] : EMPTY_VALUE;
        updn[pos] = (linreg[pos] > 0 && linreg[pos] < NZ(linreg[pos+1])) ? linreg[pos] : EMPTY_VALUE;
        dndn[pos] = (linreg[pos] < 0 && linreg[pos] < NZ(linreg[pos+1])) ? linreg[pos] : EMPTY_VALUE;
        dnup[pos] = (linreg[pos] < 0 && linreg[pos] > NZ(linreg[pos+1])) ? linreg[pos] : EMPTY_VALUE;
        
        no[pos]  = noSqz  ? 0 : EMPTY_VALUE;
        On[pos]  = sqzOn  ? 0 : EMPTY_VALUE;
        Off[pos] = sqzOff ? 0 : EMPTY_VALUE;
    }

    return(rates_total);
}

// Rest of the helper functions remain the same as in the previous version
// (TR, LinearRegression, NZ, High, Low functions)
// Helper Functions
double TR(int shift, const double &high[], const double &low[], const double &close[]) {
    double t1 = high[shift] - low[shift];
    double t2 = MathAbs(high[shift] - close[shift+1]);
    double t3 = MathAbs(low[shift] - close[shift+1]);
    
    return MathMax(MathMax(t1, t2), t3);
}

double LinearRegression(double &src[], int period, int pos) {
    double SumY = 0, Sum1 = 0, Slope = 0;
    
    for (int x = 0; x < period; x++) {
        double c = src[x+pos];
        SumY += c;
        Sum1 += x * c;
    }
    
    double SumBars = period * (period - 1) * 0.5;
    double SumSqrBars = (period -  1) * period * (2 * period - 1) / 6;
    double Sum2 = SumBars * SumY;
    double Num1 = period * Sum1 - Sum2;
    double Num2 = SumBars * SumBars - period * SumSqrBars;
    
    if (Num2 != 0) {
        Slope = Num1 / Num2;
    } else {
        Slope = 0;
    }
    
    double Intercept = (SumY - Slope * SumBars) / period;
    return Intercept + Slope * (period - 1);
}

double NZ(double check, double val = 0) {
    return (check == EMPTY_VALUE) ? val : check;
}

double High(int length, int pos, const double &high[]) {
    double maxVal = high[pos];
    for (int i = 1; i < length && (pos - i) >= 0; i++) {
        if (high[pos - i] > maxVal) {
            maxVal = high[pos - i];
        }
    }
    return maxVal;
}

double Low(int length, int pos, const double &low[]) {
    double minVal = low[pos];
    for (int i = 1; i < length && (pos - i) >= 0; i++) {
        if (low[pos - i] < minVal) {
            minVal = low[pos - i];
        }
    }
    return minVal;
}