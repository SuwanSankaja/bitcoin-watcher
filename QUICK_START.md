# Quick Start - Bitcoin Watcher Day Trading Bot

## 🎯 What Was Fixed

✅ **CRITICAL BUG**: BUY/SELL signals were inverted (buying high, selling low)
✅ **NOW FIXED**: Correct trading logic implemented
✅ **DAY TRADING**: Optimized for 3-8 signals per day

---

## 🚀 Current Configuration

### Day Trading Settings (Active)
```
Buy Threshold:    0.8%
Sell Threshold:   0.8%
Short MA Period:  5 minutes
Long MA Period:   15 minutes
Expected Signals: 3-8 per day
```

### How It Works
- **BUY Signal**: When price dips 0.8% below trend → Buy the dip
- **SELL Signal**: When price rises 0.8% above trend → Take profit
- **HOLD Signal**: When price is within ±0.8% of trend → Wait

---

## 📦 Deploy in 3 Steps

### Step 1: Update Lambda
1. Go to AWS Lambda Console
2. Open `signal_analyzer` function
3. Copy code from `backend/lambda/signal_analyzer.py`
4. Click **Deploy**

### Step 2: Update MongoDB
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

### Step 3: Verify
Check CloudWatch logs for:
```
Using MA periods: 5/15, Thresholds: 0.008/0.008
```

---

## 📊 Trading Styles Available

### 🔥 Scalping (Ultra-Fast)
- **Settings**: 3/8 MA, 0.5% threshold
- **Signals**: 10-20 per day
- **Risk**: Very High
- **Best for**: Full-time traders

### ⚡ Day Trading (Current - Recommended)
- **Settings**: 5/15 MA, 0.8% threshold
- **Signals**: 3-8 per day
- **Risk**: Medium-High
- **Best for**: Active traders

### 📈 Swing Trading
- **Settings**: 12/26 MA, 1.5% threshold
- **Signals**: 1-3 per week
- **Risk**: Medium
- **Best for**: Part-time traders

### 🎯 Position Trading
- **Settings**: 20/50 MA, 2.0% threshold
- **Signals**: 1-2 per month
- **Risk**: Low
- **Best for**: Long-term investors

---

## 📚 Documentation

- **[DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)** - Detailed deployment steps
- **[DAY_TRADING_CONFIG.md](DAY_TRADING_CONFIG.md)** - Trading strategies & settings
- **[SIGNAL_FIX_SUMMARY.md](SIGNAL_FIX_SUMMARY.md)** - What was broken & how we fixed it

---

## ⚠️ Important Notes

### Before You Trade
- ⚠️ This generates **signals**, not trading advice
- ⚠️ Always use **stop-losses** in real trading
- ⚠️ Test with **paper trading** first (track without real money)
- ⚠️ Expect **30-40% false signals** in crypto volatility

### Day Trading Considerations
- 📱 **More notifications**: You'll get 3-8 alerts per day
- 💰 **Trading fees**: More signals = more fees
- ⏰ **Time commitment**: Requires monitoring throughout the day
- 🌙 **24/7 market**: Bitcoin trades all hours

---

## 🔧 Quick Settings Changes

### Switch to Swing Trading (Fewer Signals)
```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "settings.buy_threshold": 0.015,
      "settings.sell_threshold": 0.015,
      "settings.short_ma_period": 12,
      "settings.long_ma_period": 26
    }
  }
)
```

### Make More Aggressive (More Signals)
```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "settings.buy_threshold": 0.005,
      "settings.sell_threshold": 0.005
    }
  }
)
```

### Make More Conservative (Fewer Signals)
```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "settings.buy_threshold": 0.012,
      "settings.sell_threshold": 0.012
    }
  }
)
```

---

## 📈 Monitoring Your Bot

### Check Signal Count (Last 24 Hours)
```javascript
db.signals.countDocuments({
  timestamp: {
    $gte: new Date(Date.now() - 24*60*60*1000)
  }
})
```

### See Recent Signals
```javascript
db.signals.find().sort({timestamp: -1}).limit(10)
```

### Signal Breakdown by Type
```javascript
db.signals.aggregate([
  {
    $match: {
      timestamp: { $gte: new Date(Date.now() - 24*60*60*1000) }
    }
  },
  {
    $group: {
      _id: "$type",
      count: { $sum: 1 },
      avg_confidence: { $avg: "$confidence" }
    }
  }
])
```

---

## 🎯 Expected Results

### Day Trading Performance
With proper settings, you should see:
- ✅ **BUY signals** during price dips
- ✅ **SELL signals** during price peaks
- ✅ **3-8 signals** per day (during volatile periods)
- ✅ **Fewer whipsaw trades** than before

### Example Good Signal Pattern
```
10:00 AM - BTC at $90,000 - SELL (price peaking)
10:15 AM - BTC drops to $89,500
11:30 AM - BTC at $89,200 - BUY (price dipping)
11:45 AM - BTC rises to $89,800
```

---

## 🆘 Troubleshooting

### "Too many signals!"
→ Increase thresholds to 1.0% or 1.2%

### "Not enough signals!"
→ Decrease thresholds to 0.6% (but be careful - more noise)

### "Signals seem random"
→ You may be in a sideways market (no clear trend)
→ Consider switching to swing trading settings temporarily

### "Wrong timestamps"
→ Check timezone settings (should be Sri Lanka/Asia/Colombo)

---

## ✅ Deployment Checklist

- [ ] Deploy `signal_analyzer.py` to AWS Lambda
- [ ] Update MongoDB settings collection
- [ ] Verify in CloudWatch logs (see correct MA periods)
- [ ] Wait for first signal (within 30-60 minutes)
- [ ] Test notification on mobile app
- [ ] Monitor for 24-48 hours before live trading
- [ ] Set up paper trading to test strategy

---

## 🎉 You're Ready!

Your bot is now configured for **day trading** with the **corrected** BUY/SELL logic.

**Next Steps:**
1. Deploy the changes
2. Monitor signals for 2-3 days
3. Paper trade to verify accuracy
4. Start with small amounts if live trading

Good luck! 🚀

---

**Questions?** Check the detailed guides:
- Technical details → [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md)
- Strategy tuning → [DAY_TRADING_CONFIG.md](DAY_TRADING_CONFIG.md)
- Bug explanation → [SIGNAL_FIX_SUMMARY.md](SIGNAL_FIX_SUMMARY.md)
