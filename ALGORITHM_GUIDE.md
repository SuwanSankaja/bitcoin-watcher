# Algorithm Guide - Bitcoin Watcher

## Understanding the Moving Average Crossover Strategy

### What is a Moving Average?

A **Moving Average (MA)** is the average price over a specific time period. It "smooths out" price fluctuations to help identify trends.

**Example:**
```
Prices over 5 minutes: [100, 102, 101, 103, 104]
5-minute MA = (100 + 102 + 101 + 103 + 104) / 5 = 102
```

### Short vs Long Moving Averages

- **Short MA** (7 minutes by default)
  - Responds quickly to price changes
  - More sensitive to short-term fluctuations
  - Follows current market momentum

- **Long MA** (21 minutes by default)
  - Responds slowly to price changes
  - More stable, filters out noise
  - Represents longer-term trend

## How the Strategy Works

### Signal Generation Logic

```python
# Fetch recent prices
prices = get_last_30_minutes_of_prices()

# Calculate moving averages
short_ma = average(last_7_prices)
long_ma = average(last_21_prices)

# Compare with thresholds
buy_threshold = 0.005  # 0.5%
sell_threshold = 0.005  # 0.5%

if short_ma > long_ma * (1 + buy_threshold):
    signal = "BUY"
    # Short MA is significantly above Long MA
    # Indicates strong upward momentum
    
elif short_ma < long_ma * (1 - sell_threshold):
    signal = "SELL"
    # Short MA is significantly below Long MA
    # Indicates strong downward momentum
    
else:
    signal = "HOLD"
    # MAs are close together
    # No clear trend, wait for better opportunity
```

### Visual Example

```
Price Chart:

High ─────┐
          │   Short MA (7-min) ──────→ Fast, reactive
          │   /\      /\
          │  /  \    /  \
          │ /    \  /    \
          │/      \/      \
Mid  ─────┤─── Long MA (21-min) ──────→ Slow, stable
          │    ──────────────
          │
Low  ─────┘

When Short MA crosses ABOVE Long MA + threshold → BUY
When Short MA crosses BELOW Long MA - threshold → SELL
```

## Confidence Calculation

The algorithm also calculates a **confidence score** for each signal:

```python
# For BUY signal
confidence = min(
    ((short_ma / long_ma - 1) / buy_threshold) * 100,
    100
)

# For SELL signal
confidence = min(
    ((1 - short_ma / long_ma) / sell_threshold) * 100,
    100
)
```

**Interpretation:**
- **0-30%**: Weak signal, just crossed threshold
- **30-70%**: Moderate signal, clear separation
- **70-100%**: Strong signal, significant separation

## Customizing the Algorithm

### Parameters You Can Adjust

| Parameter | Default | Description | Effect |
|-----------|---------|-------------|--------|
| **Short MA Period** | 7 min | Window for short-term average | Lower = More sensitive, Higher = Less noise |
| **Long MA Period** | 21 min | Window for long-term average | Lower = Faster signals, Higher = More stable |
| **Buy Threshold** | 0.5% | % above long MA to trigger BUY | Lower = More signals, Higher = Fewer signals |
| **Sell Threshold** | 0.5% | % below long MA to trigger SELL | Lower = More signals, Higher = Fewer signals |

### Adjustment Strategies

#### Conservative (Fewer Signals, Higher Confidence)
```
Short MA Period: 10 minutes
Long MA Period: 30 minutes
Buy Threshold: 1.0%
Sell Threshold: 1.0%
```
**Best for:** Long-term holders, avoiding false signals

#### Moderate (Balanced)
```
Short MA Period: 7 minutes
Long MA Period: 21 minutes
Buy Threshold: 0.5%
Sell Threshold: 0.5%
```
**Best for:** Standard trading, good balance

#### Aggressive (More Signals, Lower Confidence)
```
Short MA Period: 5 minutes
Long MA Period: 15 minutes
Buy Threshold: 0.3%
Sell Threshold: 0.3%
```
**Best for:** Day trading, quick reactions

### How to Adjust in App

1. Open **Settings** screen
2. Scroll to **Algorithm Settings**
3. Adjust sliders:
   - **Buy Threshold**: 0.1% to 2.0%
   - **Sell Threshold**: 0.1% to 2.0%
   - **Short MA Period**: 3 to 15 minutes
   - **Long MA Period**: 15 to 30 minutes
4. Tap **Save** button
5. New settings take effect on next signal analysis (2 minutes)

## Advanced Modifications

### Adding RSI (Relative Strength Index)

Edit `backend/lambda/signal_analyzer.py`:

```python
def calculate_rsi(prices, period=14):
    """Calculate RSI indicator"""
    if len(prices) < period + 1:
        return 50
    
    changes = [prices[i]['price'] - prices[i-1]['price'] 
               for i in range(1, len(prices))]
    
    gains = [c if c > 0 else 0 for c in changes]
    losses = [-c if c < 0 else 0 for c in changes]
    
    avg_gain = sum(gains[-period:]) / period
    avg_loss = sum(losses[-period:]) / period
    
    if avg_loss == 0:
        return 100
    
    rs = avg_gain / avg_loss
    rsi = 100 - (100 / (1 + rs))
    return rsi

# In analyze_signal function:
def analyze_signal(prices, ...):
    # ... existing MA calculations ...
    
    rsi = calculate_rsi(prices)
    
    # Combine with MA strategy
    if short_ma > long_ma * (1 + buy_threshold) and rsi < 30:
        signal_type = 'BUY'  # Oversold + upward momentum
    elif short_ma < long_ma * (1 - sell_threshold) and rsi > 70:
        signal_type = 'SELL'  # Overbought + downward momentum
    else:
        signal_type = 'HOLD'
```

### Adding MACD (Moving Average Convergence Divergence)

```python
def calculate_macd(prices):
    """Calculate MACD indicator"""
    if len(prices) < 26:
        return 0, 0, 0
    
    ema_12 = calculate_ema(prices, 12)
    ema_26 = calculate_ema(prices, 26)
    
    macd_line = ema_12 - ema_26
    signal_line = calculate_ema_from_values([macd_line], 9)
    histogram = macd_line - signal_line
    
    return macd_line, signal_line, histogram

def calculate_ema(prices, period):
    """Calculate Exponential Moving Average"""
    multiplier = 2 / (period + 1)
    ema = prices[0]['price']
    
    for price in prices[1:]:
        ema = (price['price'] - ema) * multiplier + ema
    
    return ema
```

### Volume-Weighted Average Price (VWAP)

If Binance provides volume data:

```python
def calculate_vwap(prices_with_volume):
    """Calculate VWAP"""
    total_pv = sum(p['price'] * p['volume'] for p in prices_with_volume)
    total_volume = sum(p['volume'] for p in prices_with_volume)
    
    if total_volume == 0:
        return 0
    
    return total_pv / total_volume
```

## Strategy Comparison

| Strategy | Pros | Cons | Best For |
|----------|------|------|----------|
| **MA Crossover** | Simple, reliable | Lags price | Trending markets |
| **RSI + MA** | Catches reversals | Complex | Range-bound markets |
| **MACD** | Shows momentum | Needs tuning | Strong trends |
| **VWAP** | Considers volume | Needs volume data | Intraday trading |

## Backtesting Your Strategy

### 1. Collect Historical Data

```python
def backtest_strategy(historical_prices, settings):
    """Test strategy on historical data"""
    signals = []
    positions = []
    
    for i in range(settings['long_ma_period'], len(historical_prices)):
        window = historical_prices[i-settings['long_ma_period']:i]
        signal = analyze_signal(window, **settings)
        signals.append(signal)
        
        # Simulate trades
        if signal['type'] == 'BUY' and not positions:
            positions.append({
                'type': 'buy',
                'price': historical_prices[i]['price'],
                'time': historical_prices[i]['timestamp']
            })
        elif signal['type'] == 'SELL' and positions:
            buy_price = positions[-1]['price']
            sell_price = historical_prices[i]['price']
            profit = (sell_price - buy_price) / buy_price * 100
            print(f"Trade: {profit:.2f}% profit")
            positions = []
    
    return signals
```

### 2. Calculate Performance Metrics

```python
def calculate_metrics(trades):
    """Calculate strategy performance"""
    total_trades = len(trades)
    winning_trades = sum(1 for t in trades if t['profit'] > 0)
    total_profit = sum(t['profit'] for t in trades)
    
    win_rate = winning_trades / total_trades * 100
    avg_profit = total_profit / total_trades
    
    print(f"Win Rate: {win_rate:.2f}%")
    print(f"Average Profit per Trade: {avg_profit:.2f}%")
    print(f"Total Profit: {total_profit:.2f}%")
```

## Risk Management

### Stop-Loss Implementation

Add to your strategy:

```python
def check_stop_loss(current_price, buy_price, stop_loss_percent=5):
    """Check if stop-loss triggered"""
    loss = (buy_price - current_price) / buy_price * 100
    
    if loss >= stop_loss_percent:
        return True  # Exit position
    
    return False
```

### Position Sizing

```python
def calculate_position_size(portfolio_value, risk_percent, stop_loss):
    """Calculate how much to invest"""
    risk_amount = portfolio_value * (risk_percent / 100)
    position_size = risk_amount / (stop_loss / 100)
    
    return min(position_size, portfolio_value * 0.2)  # Max 20% per trade
```

## Monitoring Performance

### Key Metrics to Track

1. **Win Rate**: % of profitable signals
2. **Average Profit**: Mean % gain per signal
3. **Max Drawdown**: Largest loss from peak
4. **Sharpe Ratio**: Risk-adjusted return
5. **Signal Frequency**: How often signals are generated

### Logging Trades

Add to MongoDB:

```python
# New collection: trades
db.trades.insert_one({
    'timestamp': datetime.utcnow(),
    'signal_id': signal_id,
    'type': 'BUY/SELL',
    'entry_price': entry_price,
    'exit_price': exit_price,
    'profit_pct': profit_pct,
    'duration': duration_minutes
})
```

## Recommended Readings

- **Moving Averages**: Understanding MA strategies
- **Technical Analysis**: Indicators and patterns
- **Algorithmic Trading**: Automated strategies
- **Risk Management**: Protecting capital
- **Backtesting**: Testing strategies on historical data

## Conclusion

The Moving Average Crossover is a **beginner-friendly** strategy that works well in trending markets. Start with default settings and adjust based on your:

- **Risk tolerance**: Higher thresholds = safer
- **Trading style**: Shorter periods = more active
- **Market conditions**: Volatile vs stable markets

Remember: **No strategy is perfect**. Always:
- ✅ Test with small amounts first
- ✅ Monitor performance regularly
- ✅ Adjust based on results
- ✅ Never invest more than you can afford to lose

---

**Happy Trading! 📈**
