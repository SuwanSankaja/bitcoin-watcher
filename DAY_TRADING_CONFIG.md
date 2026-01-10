# Day Trading Configuration Guide

## ⚡ Day Trading vs. Swing Trading

### What's the Difference?

| Trading Style | Holding Period | Goal | Risk |
|--------------|----------------|------|------|
| **Day Trading** | Minutes to Hours | Quick profits from small moves | High frequency, higher fees |
| **Swing Trading** | Days to Weeks | Capture larger trends | Fewer trades, lower fees |

Your original settings were for **swing trading**. For **day trading**, you need faster, more sensitive signals.

---

## 🎯 Day Trading Settings (UPDATED)

### New Configuration

```json
{
  "buy_threshold": 0.008,      // 0.8% movement triggers signal
  "sell_threshold": 0.008,     // 0.8% movement triggers signal
  "short_ma_period": 5,        // 5 minutes - fast reaction
  "long_ma_period": 15         // 15 minutes - trend detection
}
```

### Why These Values?

#### 1. **Lower Thresholds (0.8% instead of 1.5%)**
- **More sensitive** to price movements
- **Catches smaller swings** in Bitcoin's volatility
- Bitcoin typically moves 0.5-2% in a few minutes
- **More signals** throughout the day

#### 2. **Shorter MA Periods (5/15 instead of 12/26)**
- **5-minute MA**: Reacts to immediate price action
- **15-minute MA**: Shows short-term trend
- **Faster crossovers** = More trading opportunities
- Ideal for 1-minute price updates

---

## 📊 Expected Signal Frequency

### With Day Trading Settings:
- **Signals per day**: 3-8 signals (depending on volatility)
- **Minimum gap**: ~10-20 minutes between signals
- **Best for**: Active traders monitoring throughout the day

### Comparison to Swing Trading:
- **Swing Trading** (12/26, 1.5%): 1-3 signals per week
- **Day Trading** (5/15, 0.8%): 3-8 signals per day

---

## ⚙️ Fine-Tuning Your Strategy

### If You're Getting TOO MANY Signals:

**Option 1: Increase Thresholds**
```json
{
  "buy_threshold": 0.010,    // 1.0%
  "sell_threshold": 0.010    // 1.0%
}
```

**Option 2: Slightly Longer Periods**
```json
{
  "short_ma_period": 7,
  "long_ma_period": 20
}
```

### If You're Getting TOO FEW Signals:

**Option 1: Lower Thresholds** (More risky!)
```json
{
  "buy_threshold": 0.005,    // 0.5% - Very aggressive
  "sell_threshold": 0.005    // 0.5%
}
```

**Option 2: Faster Periods**
```json
{
  "short_ma_period": 3,
  "long_ma_period": 10
}
```

---

## 🎚️ Recommended Settings by Trading Style

### 1. **Scalping** (Ultra-Fast, Many Trades)
```json
{
  "buy_threshold": 0.005,
  "sell_threshold": 0.005,
  "short_ma_period": 3,
  "long_ma_period": 8
}
```
- ⚡ **Very aggressive**
- 📈 10-20 signals per day
- ⚠️ High risk, requires constant monitoring

### 2. **Day Trading** (Current - Recommended)
```json
{
  "buy_threshold": 0.008,
  "sell_threshold": 0.008,
  "short_ma_period": 5,
  "long_ma_period": 15
}
```
- ⚡ **Moderately aggressive**
- 📈 3-8 signals per day
- ✅ Good balance of signals and quality

### 3. **Swing Trading** (Original)
```json
{
  "buy_threshold": 0.015,
  "sell_threshold": 0.015,
  "short_ma_period": 12,
  "long_ma_period": 26
}
```
- 🐢 **Conservative**
- 📈 1-3 signals per week
- ✅ Lower risk, fewer false signals

### 4. **Position Trading** (Long-term)
```json
{
  "buy_threshold": 0.020,
  "sell_threshold": 0.020,
  "short_ma_period": 20,
  "long_ma_period": 50
}
```
- 🐌 **Very conservative**
- 📈 1-2 signals per month
- ✅ Minimal noise, major trends only

---

## 🔧 Additional Considerations for Day Trading

### 1. **Price Update Frequency**
Your current setup fetches prices every **1 minute**. This is GOOD for day trading!

If you need even faster:
- Update Lambda schedule: Every 30 seconds (more expensive)
- Adjust `get_recent_prices(minutes=30)` to `minutes=20` for fresher data

### 2. **Data Requirements**
With 5/15 MA periods:
- **Minimum data needed**: 15 minutes of price history
- **Current**: 30 minutes (good buffer)
- Keep `get_recent_prices(minutes=30)` as is

### 3. **Notification Fatigue**
⚠️ **Warning**: Day trading settings = MORE notifications!

**Solutions**:
- Set "Do Not Disturb" hours in your app
- Use different thresholds for BUY vs SELL:
  ```json
  {
    "buy_threshold": 0.008,
    "sell_threshold": 0.010  // Slightly higher to reduce sell signals
  }
  ```

### 4. **Trading Fees**
More signals = More trades = More fees!
- Consider fee structure before executing every signal
- Maybe execute only high-confidence signals (>80%)

---

## 📈 Advanced: Asymmetric Thresholds

For day trading, you might want different buy/sell sensitivities:

### Conservative Buying, Aggressive Selling
```json
{
  "buy_threshold": 0.012,   // Only buy on significant dips
  "sell_threshold": 0.006   // Take quick profits
}
```
**Strategy**: "Buy carefully, sell quickly"

### Aggressive Buying, Conservative Selling
```json
{
  "buy_threshold": 0.006,   // Catch small dips
  "sell_threshold": 0.012   // Hold for bigger gains
}
```
**Strategy**: "Buy the dips, hold for trends"

---

## 🚀 Deployment for Day Trading

### Update MongoDB:
```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "settings.buy_threshold": 0.008,
      "settings.sell_threshold": 0.008,
      "settings.short_ma_period": 5,
      "settings.long_ma_period": 15,
      "updated_at": new Date()
    }
  }
)
```

### Verify:
```javascript
db.settings.findOne({ "_id": "default" })
```

---

## 📊 Monitoring Your Day Trading Bot

### Key Metrics to Track:

1. **Signal Frequency**
   ```javascript
   // Signals per day
   db.signals.countDocuments({
     timestamp: {
       $gte: new Date(Date.now() - 24*60*60*1000)
     }
   })
   ```

2. **Signal Distribution**
   ```javascript
   // Count by type
   db.signals.aggregate([
     {
       $match: {
         timestamp: { $gte: new Date(Date.now() - 24*60*60*1000) }
       }
     },
     {
       $group: {
         _id: "$type",
         count: { $sum: 1 }
       }
     }
   ])
   ```

3. **Average Time Between Signals**
   - Should be ~10-30 minutes for day trading
   - If less than 10 min: Too sensitive
   - If more than 1 hour: Too conservative

---

## ⚠️ Day Trading Warnings

### 1. **Higher Risk**
- More trades = More opportunities to lose money
- Always use stop-losses in actual trading
- This is a signal generator, not trading advice

### 2. **False Signals**
- Crypto is volatile - expect 30-40% false signals
- Don't trade every signal blindly
- Consider additional confirmation (volume, RSI, etc.)

### 3. **Market Hours**
- Bitcoin trades 24/7 - signals come anytime
- Consider disabling notifications during sleep
- Or set trading hours in app

### 4. **Backtesting Recommended**
Before live trading with these settings:
- Test on historical data
- Check win rate
- Calculate average profit/loss per signal

---

## 🎯 Quick Reference Card

```
DAY TRADING SETTINGS (Current)
================================
Buy Threshold:    0.8%
Sell Threshold:   0.8%
Short MA:         5 periods (5 min)
Long MA:          15 periods (15 min)
Expected Signals: 3-8 per day
Risk Level:       Medium-High
Best For:         Active traders
```

---

## 📝 Testing Plan

After deployment:

### Day 1-2: Monitor Only
- Watch signals, don't trade
- Count frequency
- Check quality (are they accurate?)

### Day 3-5: Paper Trade
- Simulate trades based on signals
- Track hypothetical profit/loss
- Adjust thresholds if needed

### Day 6+: Consider Live Trading
- Start with small amounts
- Only if signals prove accurate
- Always use stop-losses

---

## 🔄 Quick Settings Switch

Save these in your MongoDB for easy switching:

```javascript
// Day Trading Profile
db.trading_profiles.insertOne({
  _id: "day_trading",
  settings: {
    buy_threshold: 0.008,
    sell_threshold: 0.008,
    short_ma_period: 5,
    long_ma_period: 15
  }
})

// Swing Trading Profile
db.trading_profiles.insertOne({
  _id: "swing_trading",
  settings: {
    buy_threshold: 0.015,
    sell_threshold: 0.015,
    short_ma_period: 12,
    long_ma_period: 26
  }
})

// Scalping Profile
db.trading_profiles.insertOne({
  _id: "scalping",
  settings: {
    buy_threshold: 0.005,
    sell_threshold: 0.005,
    short_ma_period: 3,
    long_ma_period: 8
  }
})
```

Then switch by copying from profiles collection.

---

**Ready to deploy?** See [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) for steps!
