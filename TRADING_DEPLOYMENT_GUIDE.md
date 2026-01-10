```markdown
# Trading Bot Deployment Guide

## 📋 Overview

This guide covers deploying the automated trading functionality to your AWS Lambda function.

**What's new:**
- Automated BTC/USDT spot trading on Binance
- Testnet support for safe testing
- Trade execution on BUY/SELL signals
- Trade logging to MongoDB
- Safety features and error handling

---

## ⚠️ Prerequisites

Before deploying, complete these steps:

1. ✅ **Binance Testnet Setup**
   - Follow [BINANCE_TESTNET_SETUP.md](BINANCE_TESTNET_SETUP.md)
   - Get API keys
   - Fund testnet account

2. ✅ **AWS Secrets Manager**
   - Store Binance API keys in Secrets Manager
   - Secret name: `bitcoin-watcher-binance-testnet`

3. ✅ **MongoDB Settings**
   - Add trading configuration fields

4. ✅ **Lambda Permissions**
   - Grant Secrets Manager read access

---

## 🚀 Deployment Steps

### Step 1: Update Lambda Function Code

#### 1.1 Package the Code

You need to deploy TWO files to Lambda:

1. **signal_analyzer.py** (updated with trading integration)
2. **binance_trader.py** (new trading module)

**Option A: AWS Console Upload**

1. Go to AWS Lambda Console
2. Open your `signal_analyzer` function
3. In the Code tab, you'll see the file tree on the left
4. **Update signal_analyzer.py**:
   - Click on `signal_analyzer.py` in the file tree
   - Copy entire content from your local `backend/lambda/signal_analyzer.py`
   - Paste into the editor
   - Click **Deploy**

5. **Add binance_trader.py**:
   - Click **File** → **New File**
   - Name it: `binance_trader.py`
   - Copy entire content from your local `backend/lambda/binance_trader.py`
   - Paste into the editor
   - Click **Deploy**

**Option B: ZIP Upload (If many files)**

```bash
cd backend/lambda

# Create deployment package
zip -r deployment.zip signal_analyzer.py binance_trader.py

# Upload via AWS Console
# Or use AWS CLI:
aws lambda update-function-code \
  --function-name signal_analyzer \
  --zip-file fileb://deployment.zip
```

#### 1.2 Install Dependencies

The trading module uses `requests` library (for HTTP calls to Binance API).

**Check if requests is already available:**
- Lambda includes `requests` in Python 3.x runtime ✅
- You don't need to add it separately

**If you need to add dependencies:**

1. Create requirements.txt:
   ```
   requests==2.31.0
   ```

2. Install to a folder:
   ```bash
   pip install -r requirements.txt -t python/
   ```

3. Zip and upload as Lambda Layer (optional, advanced)

---

### Step 2: Configure AWS Secrets Manager

#### 2.1 Create Secret for Testnet

1. Go to **AWS Secrets Manager**
2. Click **Store a new secret**
3. Select **Other type of secret**
4. Add key/value pairs:
   ```
   api_key: [Your Binance Testnet API Key]
   api_secret: [Your Binance Testnet Secret]
   ```
5. Secret name: `bitcoin-watcher-binance-testnet`
6. Click through and **Store**

#### 2.2 Grant Lambda Access

**Option A: Attach Policy to Lambda Role**

1. Go to **IAM** → **Roles**
2. Find your Lambda execution role
3. Click **Add permissions** → **Create inline policy**
4. Use JSON editor:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": [
                "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:bitcoin-watcher-binance-testnet-*",
                "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:bitcoin-watcher-binance-production-*"
            ]
        }
    ]
}
```

Replace:
- `REGION`: Your AWS region (e.g., `us-east-1`)
- `ACCOUNT_ID`: Your AWS account ID (12 digits)

5. Name: `BinanceSecretsAccess`
6. **Create policy**

**Option B: Use AWS Managed Policy (Easier but less secure)**

Attach: `SecretsManagerReadWrite` to your Lambda role

---

### Step 3: Update MongoDB Settings

Add trading configuration to your settings:

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      // Existing signal settings...
      "buy_threshold": 0.008,
      "sell_threshold": 0.008,
      "short_ma_period": 5,
      "long_ma_period": 15,
      "notifications_enabled": true,

      // NEW: Trading settings
      "trading_enabled": false,  // Set true when ready!
      "trading_mode": "testnet",  // "testnet" or "production"
      "trade_amount_usdt": 50,  // USDT per BUY (start small!)
      "sell_percentage": 100  // % of BTC to sell (100 = all)
    }
  }
)
```

**Verify:**
```javascript
db.settings.findOne({ "_id": "default" })
```

---

### Step 4: Test the Deployment

#### 4.1 Check Lambda Logs (Before Trading)

1. Go to **CloudWatch** → **Log groups**
2. Find `/aws/lambda/signal_analyzer`
3. Watch for errors in recent logs

#### 4.2 Dry Run Test (Trading Disabled)

With `trading_enabled: false`, run your Lambda:

1. Lambda Console → **Test** tab
2. Create test event (empty JSON: `{}`)
3. Click **Test**
4. Check logs for:
   ```
   Using MA periods: 5/15, Thresholds: 0.008/0.008
   Trading is disabled in settings
   Signal analyzed successfully
   ```

#### 4.3 Enable Trading on Testnet

**⚠️ First time? Start with small amount!**

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "trading_enabled": true,  // ENABLE TRADING
      "trading_mode": "testnet",  // Testnet only!
      "trade_amount_usdt": 50  // Small amount for first test
    }
  }
)
```

#### 4.4 Wait for Signal or Force One

**Option 1: Wait for natural signal**
- Let your bot run normally
- Watch CloudWatch logs for next signal

**Option 2: Force signal (for testing)**

Temporarily lower thresholds to trigger signal quickly:

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "buy_threshold": 0.001,  // Very sensitive
      "sell_threshold": 0.001
    }
  }
)
```

**Remember to restore after testing!**

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "buy_threshold": 0.008,
      "sell_threshold": 0.008
    }
  }
)
```

#### 4.5 Monitor Trade Execution

When a signal triggers, check CloudWatch logs:

```
Signal changed to BUY, attempting trade execution...
Fetching Binance credentials (testnet)
Initialized Binance Trader (TESTNET)
✅ Binance API connection successful

==================================================
🟢 EXECUTING BUY SIGNAL
==================================================
💵 USDT Balance: $10000.00
📊 Current BTC Price: $96,500.00
💰 Calculated quantity: 0.00051813 BTC
🔄 Placing BUY order: 0.00051813 BTCUSDT
✅ Order placed successfully!
   Order ID: 12345678
   Status: FILLED
   Executed Qty: 0.00051813
==================================================

Trade stored in MongoDB with ID: 6789abc...
✅ Trade executed and stored: BUY
```

#### 4.6 Verify in Binance Testnet

1. Login to https://testnet.binance.vision/
2. Go to **Orders** → **Trade History**
3. You should see your executed order!

#### 4.7 Verify in MongoDB

```javascript
// Check trades collection
db.trades.find().sort({timestamp: -1}).limit(5)

// Should see:
{
  "_id": ObjectId("..."),
  "timestamp": ISODate("..."),
  "signal_id": "...",
  "binance_order_id": 12345678,
  "symbol": "BTCUSDT",
  "side": "BUY",
  "status": "FILLED",
  "executed_qty": 0.00051813,
  "average_price": 96500.00,
  "signal_price": 96485.50,
  "signal_confidence": 75.5,
  "fills": [...]
}
```

---

## 📊 MongoDB Collections

### New Collections Created

#### 1. `trades` Collection
Stores successful trades:

```javascript
{
  timestamp: Date,
  signal_id: String,
  binance_order_id: Number,
  symbol: String,          // "BTCUSDT"
  side: String,            // "BUY" or "SELL"
  type: String,            // "MARKET"
  status: String,          // "FILLED"
  executed_qty: Number,    // BTC amount
  average_price: Number,   // Execution price
  signal_price: Number,    // Price when signal generated
  signal_confidence: Number,
  fills: Array             // Binance fill details
}
```

#### 2. `failed_trades` Collection
Stores failed trade attempts:

```javascript
{
  timestamp: Date,
  signal_id: String,
  signal_type: String,     // "BUY" or "SELL"
  signal_price: Number,
  error: String            // Error message
}
```

### Useful Queries

```javascript
// Today's trades
db.trades.find({
  timestamp: {
    $gte: new Date(new Date().setHours(0,0,0,0))
  }
})

// Count trades by side
db.trades.aggregate([
  {
    $group: {
      _id: "$side",
      count: { $sum: 1 },
      total_qty: { $sum: "$executed_qty" }
    }
  }
])

// Failed trades
db.failed_trades.find().sort({timestamp: -1}).limit(10)

// Average execution price vs signal price
db.trades.aggregate([
  {
    $project: {
      slippage: {
        $subtract: ["$average_price", "$signal_price"]
      }
    }
  },
  {
    $group: {
      _id: null,
      avg_slippage: { $avg: "$slippage" }
    }
  }
])
```

---

## 🔧 Configuration Options

### Trading Settings Explained

```javascript
{
  "trading_enabled": false,
  // true: Bot will execute trades
  // false: Bot only generates signals (safe mode)

  "trading_mode": "testnet",
  // "testnet": Use Binance Testnet (fake money)
  // "production": Use real Binance (REAL MONEY!)

  "trade_amount_usdt": 100,
  // How much USDT to spend per BUY signal
  // Recommended: Start with $50-100 on testnet
  // Production: Max 1-5% of your portfolio

  "sell_percentage": 100
  // Percentage of BTC balance to sell
  // 100 = sell all BTC
  // 50 = sell half
  // 25 = sell quarter
}
```

### Recommended Starting Values

**Testnet Testing:**
```javascript
{
  "trading_enabled": true,
  "trading_mode": "testnet",
  "trade_amount_usdt": 50,
  "sell_percentage": 100
}
```

**Production (When Ready):**
```javascript
{
  "trading_enabled": true,
  "trading_mode": "production",
  "trade_amount_usdt": 100,  // Start SMALL!
  "sell_percentage": 100
}
```

---

## ⚠️ Safety Features Built-In

### 1. Trading Mode Separation
- Testnet and Production use different API keys
- Cannot accidentally trade real money in testnet mode

### 2. Signal Change Required
- Trades only execute when signal changes (BUY→SELL or SELL→BUY)
- Prevents duplicate trades on same signal

### 3. Balance Checks
- BUY: Verifies sufficient USDT balance
- SELL: Verifies sufficient BTC balance
- Fails gracefully if insufficient funds

### 4. Error Logging
- All failed trades logged to `failed_trades` collection
- Errors don't crash Lambda function

### 5. Trade History
- All trades logged with full details
- Can audit and review all executions

---

## 🆘 Troubleshooting

### Issue: "Failed to fetch Binance credentials"

**Solutions:**
1. Check secret name matches exactly: `bitcoin-watcher-binance-testnet`
2. Verify Lambda has Secrets Manager permissions
3. Check secret is in same region as Lambda
4. View CloudWatch logs for exact error

---

### Issue: "Insufficient USDT balance"

**Solutions:**
1. Check Binance testnet balance
2. Request more test funds from faucet
3. Reduce `trade_amount_usdt` in settings
4. Verify you're using testnet account

---

### Issue: "Signature verification failed"

**Solutions:**
1. API secret might be wrong in Secrets Manager
2. Check for extra spaces or newlines in secret
3. Regenerate API keys on Binance
4. Update Secrets Manager with new keys

---

### Issue: "Trade executed but not in MongoDB"

**Solutions:**
1. Check MongoDB connection in Lambda logs
2. Verify MongoDB URI in SSM Parameter Store
3. Check Lambda timeout (increase if needed)
4. Look in `failed_trades` collection for error

---

### Issue: "InvalidSymbol or LOT_SIZE filter"

**Solutions:**
1. Symbol must be exactly "BTCUSDT"
2. Quantity too small - increase `trade_amount_usdt`
3. Check Binance symbol info for minimum order

---

## 📈 Monitoring

### CloudWatch Metrics to Watch

1. **Lambda Duration**: Should be <10 seconds
2. **Lambda Errors**: Should be 0
3. **Lambda Invocations**: Every 1 minute (your schedule)

### Custom Alerts (Optional)

Create CloudWatch Alarms for:
- Failed trades (check `failed_trades` count)
- Lambda errors
- Unusual execution duration

### Daily Checklist

- [ ] Check CloudWatch logs for errors
- [ ] Review trades in MongoDB
- [ ] Verify balances in Binance
- [ ] Check failed_trades collection
- [ ] Monitor signal quality

---

## 🎯 Testing Checklist

Before enabling production trading:

- [ ] Tested on testnet for 1-2 weeks
- [ ] Executed at least 10 test trades
- [ ] Verified trades appear in Binance
- [ ] Checked trade logging in MongoDB
- [ ] Reviewed failed trades (if any)
- [ ] Comfortable with signal accuracy
- [ ] Understand risk management
- [ ] Set up production API keys
- [ ] Started with small production amounts

---

## 🚀 Moving to Production

See detailed guide: [BINANCE_TESTNET_SETUP.md#moving-to-production](BINANCE_TESTNET_SETUP.md)

**Quick steps:**
1. Create real Binance account + KYC
2. Enable 2FA
3. Create production API keys (NO withdrawal permission!)
4. Store in new secret: `bitcoin-watcher-binance-production`
5. Update settings: `"trading_mode": "production"`
6. Start with $50-100 per trade
7. Monitor closely for first week

---

## 📚 Related Guides

- [BINANCE_TESTNET_SETUP.md](BINANCE_TESTNET_SETUP.md) - Setup Binance testnet
- [RISK_MANAGEMENT.md](RISK_MANAGEMENT.md) - Trading safety & risk
- [DAY_TRADING_CONFIG.md](DAY_TRADING_CONFIG.md) - Signal settings
- [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) - General deployment

---

**You're ready to deploy automated trading!** 🤖💰

Test thoroughly on testnet before risking real money!
```
