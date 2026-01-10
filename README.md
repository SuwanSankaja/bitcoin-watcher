# Bitcoin Watcher - Automated Trading Bot 🚀

Real-time Bitcoin price tracker with **intelligent buy/sell signals**, **automated trading on Binance**, and **push notifications**.

## ✨ Features

- 📊 **Real-time BTC Price Tracking** - Fetches price every minute from CoinGecko API
- 📈 **Moving Average Crossover Algorithm** - Day trading signals using 5-min & 15-min MAs
- 🤖 **Automated Trading** - Executes BTC/USDT spot trades on Binance
- 🔔 **Push Notifications** - Instant alerts via Firebase Cloud Messaging
- 📱 **Flutter Mobile App** - Beautiful Android app with interactive charts
- ☁️ **Serverless Architecture** - AWS Lambda + MongoDB Atlas + Firebase
- 🧪 **Testnet Support** - Safe testing with Binance testnet (fake money)

---

## 🛠️ Tech Stack

**Frontend:** Flutter 3.0+, Firebase Messaging, fl_chart, Provider

**Backend:** AWS Lambda (Python 3.11), EventBridge, Secrets Manager, MongoDB Atlas, Binance API, Firebase Admin SDK, CoinGecko API

---

## 📁 Project Structure

```
bitcoin-watcher/
├── lib/                          # Flutter mobile app
├── backend/lambda/               # AWS Lambda functions
│   ├── price_listener.py         # Fetches BTC price every minute
│   ├── signal_analyzer.py        # Generates signals & executes trades
│   └── binance_trader.py         # Binance trading module
├── test_trading_setup.py         # Test environment setup
├── test_trading_integration.py   # Test complete workflow
├── .env.example                  # Environment variables template
└── README.md                     # This file
```

---

## 🚀 Quick Setup

### Prerequisites
- Python 3.11+
- MongoDB Atlas account
- AWS account
- Binance testnet account
- Firebase project

### 1. Clone & Install

```bash
git clone https://github.com/yourusername/bitcoin-watcher.git
cd bitcoin-watcher
pip install pymongo pytz python-dotenv requests
```

### 2. Configure Environment

```bash
# Copy template
cp .env.example .env
```

Edit `.env` with your credentials:
```env
MONGODB_URI=mongodb+srv://your_connection_string
BINANCE_TESTNET_API_KEY=your_testnet_api_key
BINANCE_TESTNET_API_SECRET=your_testnet_secret
```

### 3. Set Up Binance Testnet

**Create Account:**
1. Go to https://testnet.binance.vision/
2. Register (can use any email)
3. Login

**Generate API Keys:**
1. Profile → API Management
2. Create new API key
3. Save both: API Key + Secret (Secret shown only once!)
4. Enable permissions: "Enable Reading" + "Enable Spot Trading"
5. **Disable** withdrawal permission

**Get Test Funds:**
1. Use testnet faucet
2. Request 10,000 USDT
3. Request 1 BTC (optional)

### 4. Configure MongoDB

Update settings collection:

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "settings.notifications_enabled": true,
      "settings.buy_threshold": 0.008,
      "settings.sell_threshold": 0.008,
      "settings.short_ma_period": 5,
      "settings.long_ma_period": 15,
      "settings.trading_enabled": true,
      "settings.trading_mode": "testnet",
      "settings.trade_amount_usdt": 50,
      "settings.sell_percentage": 100
    }
  }
)
```

### 5. Test Locally

```bash
# Test environment setup
python test_trading_setup.py

# Test complete workflow
python test_trading_integration.py
```

### 6. Deploy to AWS Lambda

**Upload Code:**
1. Go to AWS Lambda Console
2. Open `signal_analyzer` function
3. Upload `signal_analyzer.py` (updated)
4. Upload `binance_trader.py` (new file)
5. Click **Deploy**

**Store Binance Credentials in AWS Secrets Manager:**
1. Go to AWS Secrets Manager
2. Click "Store a new secret"
3. Select "Other type of secret"
4. Add key/value pairs:
   ```
   api_key: your_binance_testnet_api_key
   api_secret: your_binance_testnet_secret
   ```
5. Secret name: `bitcoin-watcher-binance-testnet`
6. Click "Store"

**Grant Lambda Permissions:**
1. Go to IAM → Roles
2. Find your Lambda execution role
3. Add inline policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": ["secretsmanager:GetSecretValue"],
            "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:bitcoin-watcher-binance-testnet-*"
        }
    ]
}
```

Replace `REGION` and `ACCOUNT_ID` with your values.

**Test Lambda:**
1. Lambda Console → Test tab
2. Create test event: `{}`
3. Click Test
4. Check logs for: `Using MA periods: 5/15, Thresholds: 0.008/0.008`

---

## 📊 How It Works

### Trading Strategy (Day Trading)

```
1. Price drops 0.8%+ below 15-min moving average
   ↓
2. BUY signal generated
   ↓
3. Executes market BUY on Binance (spends $50 USDT)
   ↓
4. Notification sent to mobile app
   ↓
5. Trade logged to MongoDB

---

When price rises 0.8%+ above 15-min moving average:
   ↓
SELL signal → Sells BTC for USDT → Notification → Logged
```

**Expected Signals:** 3-8 per day

### Complete Workflow

```
EventBridge (every 1 min)
  ↓
price_listener Lambda
  - Fetches BTC price from CoinGecko
  - Stores in MongoDB btc_prices
  ↓
signal_analyzer Lambda (every 1 min)
  - Reads last 30 minutes of prices
  - Calculates moving averages (5 & 15 periods)
  - Generates signal (BUY/SELL/HOLD)
  - Stores in MongoDB signals
  ↓
If signal changed:
  - Gets Binance credentials from AWS Secrets
  - Executes trade on Binance
  - Logs to MongoDB trades
  - Sends Firebase notification
```

---

## 🎯 MongoDB Collections

| Collection | Created | Purpose |
|------------|---------|---------|
| `settings` | Manual | Bot configuration |
| `btc_prices` | Auto | Price history (1 min intervals) |
| `signals` | Auto | BUY/SELL/HOLD signals |
| `trades` | Auto | Executed trades |
| `failed_trades` | Auto | Failed trade attempts |
| `notifications` | Auto | Sent notifications |

**Note:** Only `settings` requires manual creation. Others auto-create on first use.

---

## ⚙️ Configuration

### Trading Settings

```javascript
{
  "notifications_enabled": true,     // Enable push notifications
  "buy_threshold": 0.008,            // 0.8% - triggers BUY
  "sell_threshold": 0.008,           // 0.8% - triggers SELL
  "short_ma_period": 5,              // 5 minutes - fast MA
  "long_ma_period": 15,              // 15 minutes - slow MA
  "trading_enabled": true,           // Enable/disable trading
  "trading_mode": "testnet",         // "testnet" or "production"
  "trade_amount_usdt": 50,           // USDT per BUY trade
  "sell_percentage": 100             // % of BTC to sell (100 = all)
}
```

### Trading Strategies

**Day Trading (Current - 3-8 signals/day):**
```javascript
{ buy_threshold: 0.008, sell_threshold: 0.008, short_ma: 5, long_ma: 15 }
```

**Swing Trading (1-3 signals/week):**
```javascript
{ buy_threshold: 0.015, sell_threshold: 0.015, short_ma: 12, long_ma: 26 }
```

**Scalping (10-20 signals/day):**
```javascript
{ buy_threshold: 0.005, sell_threshold: 0.005, short_ma: 3, long_ma: 8 }
```

---

## 🧪 Testing

### Test Environment Setup

```bash
python test_trading_setup.py
```

**Tests:**
- ✅ MongoDB connection
- ✅ Binance API connection
- ✅ Settings configuration
- ✅ Signal generation logic
- ✅ Account balances

### Test Complete Workflow

```bash
python test_trading_integration.py
```

**Tests:**
- ✅ Price data fetching
- ✅ Moving average calculation
- ✅ Signal generation
- ✅ Trade execution (if enabled)
- ✅ Database logging

---

## 📈 Monitoring

### Check Recent Trades

```javascript
db.trades.find().sort({timestamp: -1}).limit(10)
```

### Today's Performance

```javascript
db.trades.find({
  timestamp: { $gte: new Date(new Date().setHours(0,0,0,0)) }
})
```

### Win Rate

```javascript
db.trades.aggregate([
  {
    $group: {
      _id: "$side",
      count: { $sum: 1 },
      avg_price: { $avg: "$average_price" }
    }
  }
])
```

### CloudWatch Logs

```bash
aws logs tail /aws/lambda/signal_analyzer --follow
```

---

## 🔒 Security

### Built-in Safety

- ✅ API keys in AWS Secrets Manager (not in code)
- ✅ No withdrawal permissions on Binance API keys
- ✅ Testnet for safe testing
- ✅ Environment variables for local testing
- ✅ Signal change required (prevents duplicate trades)
- ✅ Balance verification before trades
- ✅ Complete audit trail in MongoDB

### Best Practices

**API Keys:**
- Never commit to Git
- Rotate every 90 days
- Use separate keys for testnet/production
- Disable withdrawals

**Trading:**
- Start with testnet (1-2 weeks minimum)
- Small amounts even in production ($50-100)
- Monitor daily
- Set loss limits
- Accept losses as part of trading

---

## ⚠️ Risk Disclaimer

**This is a trading bot. Cryptocurrency trading carries significant risk of loss.**

- Past performance does NOT guarantee future results
- Only trade with money you can afford to lose
- This is NOT financial advice
- Always test thoroughly on testnet first
- Start with small amounts in production
- Expect 30-40% false signals in volatile markets
- Use stop-losses in real trading
- Never risk more than 1-2% of portfolio per trade

---

## 🐛 Troubleshooting

### "MONGODB_URI not set in .env"
Create `.env` file from `.env.example` and add your MongoDB connection string.

### "Binance API connection failed"
- Verify keys are from testnet.binance.vision
- Check API permissions include "Spot Trading"
- Ensure no extra spaces in keys

### "Insufficient USDT balance"
- Request more funds from testnet faucet
- Or reduce `trade_amount_usdt` in settings

### "No price data available"
Ensure `price_listener` Lambda is running every 1 minute.

### "Trading enabled but no trades executing"
- Check if signal changed (vs previous signal)
- Verify Binance credentials in AWS Secrets Manager
- Check CloudWatch logs for errors

---

## 📊 Performance Metrics

Track these to evaluate your bot:

**Win Rate:** % of profitable trades (target: >60%)
**Average Profit:** Per trade (target: >1%)
**Sharpe Ratio:** Risk-adjusted returns (target: >1.0)
**Maximum Drawdown:** Largest loss from peak (keep <20%)

---

## 🔄 Moving to Production

**⚠️ Only after successful testnet testing (1-2 weeks minimum)!**

### Steps:

1. **Create Real Binance Account**
   - Complete KYC verification
   - Enable 2FA
   - Fund account

2. **Create Production API Keys**
   - **Disable** withdrawal permission
   - Enable IP whitelist
   - Save keys securely

3. **Store in AWS Secrets**
   - Secret name: `bitcoin-watcher-binance-production`
   - Same format as testnet secret

4. **Update Settings**
   ```javascript
   db.settings.updateOne(
     { "_id": "default" },
     { $set: {
       "settings.trading_mode": "production",  // ⚠️ REAL MONEY!
       "settings.trade_amount_usdt": 50        // Start SMALL!
     }}
   )
   ```

5. **Monitor Closely**
   - Check every few hours first day
   - Daily reviews first week
   - Weekly reviews ongoing

---

## 🎓 Understanding Signals

### BUY Signal
**When:** Short MA < Long MA × (1 - 0.008)
**Meaning:** Price dipped 0.8%+ below trend
**Action:** Buy $50 USDT worth of BTC
**Strategy:** Buy the dip

### SELL Signal
**When:** Short MA > Long MA × (1 + 0.008)
**Meaning:** Price rose 0.8%+ above trend
**Action:** Sell 100% of BTC for USDT
**Strategy:** Take profit at peak

### HOLD Signal
**When:** MAs within ±0.8%
**Meaning:** No strong trend
**Action:** Wait, don't trade

---

## 🔧 Advanced Configuration

### Asymmetric Thresholds

Conservative buying, aggressive selling:
```javascript
{
  "buy_threshold": 0.012,   // Only buy on significant dips
  "sell_threshold": 0.006   // Take quick profits
}
```

Aggressive buying, conservative selling:
```javascript
{
  "buy_threshold": 0.006,   // Catch small dips
  "sell_threshold": 0.012   // Hold for bigger gains
}
```

### Partial Selling

Sell only 50% of BTC (let rest ride):
```javascript
{
  "sell_percentage": 50
}
```

---

## 📝 Maintenance

### Daily
- [ ] Check CloudWatch logs for errors
- [ ] Review overnight trades
- [ ] Verify bot is running
- [ ] Check Binance balances

### Weekly
- [ ] Calculate win rate
- [ ] Review all trades
- [ ] Check drawdown
- [ ] Optimize settings if needed
- [ ] Backup trade data

### Monthly
- [ ] Export trades for taxes
- [ ] Rotate API keys (every 90 days)
- [ ] Review overall performance
- [ ] Adjust position sizes

---

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create feature branch
3. Test thoroughly on testnet
4. Submit pull request

---

## 📄 License

MIT License - See LICENSE file for details

---

## 🎉 Acknowledgments

- CoinGecko for free Bitcoin price API
- Binance for testnet trading environment
- Firebase for push notifications
- MongoDB Atlas for cloud database

---

## 📞 Support

For issues:
- Check CloudWatch logs (AWS)
- Review MongoDB collections
- Test with `test_trading_setup.py`
- Verify Binance API keys
- Check EventBridge triggers

---

**Built with ❤️ for automated crypto trading**

⚠️ **Remember**: Start with testnet, test thoroughly, trade responsibly!

**Last Updated:** 2026-01-10
**Version:** 2.0 (Trading Integration Complete)
