# Binance Testnet Setup Guide

## 📋 Overview

This guide walks you through:
1. Creating Binance Testnet account
2. Getting API keys
3. Getting test USDT/BTC
4. Testing the trading bot
5. Moving to production

---

## 🌐 Step 1: Create Binance Testnet Account

### 1.1 Go to Binance Testnet

Visit: **https://testnet.binance.vision/**

### 1.2 Register Account

1. Click **"Register"** or **"Sign Up"**
2. **Enter your email** (can be any email, even fake for testnet)
3. **Create a password**
4. **Verify** (usually just email confirmation)

**Note**: Testnet is separate from production Binance. Your real Binance account won't work here.

### 1.3 Login

- Go to https://testnet.binance.vision/
- Login with your testnet credentials

---

## 🔑 Step 2: Create API Keys

### 2.1 Navigate to API Management

1. After logging in, click on your **profile icon** (top right)
2. Select **"API Management"** from dropdown

### 2.2 Create New API Key

1. Click **"Create API"** button
2. **Label your API**: e.g., "Bitcoin Watcher Bot"
3. **Complete verification** (if required)
4. Click **"Create"**

### 2.3 Save Your Keys Securely ⚠️

You'll see two keys:

```
API Key:    YOUR_API_KEY_HERE (visible)
API Secret: YOUR_SECRET_KEY_HERE (shown only once!)
```

**IMPORTANT:**
- ⚠️ **Copy BOTH keys immediately**
- ⚠️ **Secret key is shown only ONCE**
- ⚠️ Save them securely (we'll add to AWS Secrets Manager later)
- ⚠️ Never share or commit these to Git

**Example format to save:**
```
BINANCE_TESTNET_API_KEY=abcdef123456789...
BINANCE_TESTNET_SECRET=xyz789456123...
```

### 2.4 Configure API Permissions

1. Find your newly created API key
2. Click **"Edit restrictions"** or **"Edit"**
3. Enable the following permissions:
   - ✅ **Enable Reading** (to check balances)
   - ✅ **Enable Spot & Margin Trading** (to place orders)
   - ❌ **Disable Withdrawals** (for safety)

4. **IP Access List** (Optional):
   - For testing: Leave as **"Unrestricted"**
   - For production: Add your AWS Lambda IP ranges

5. Click **"Save"**

---

## 💰 Step 3: Get Test Funds

### 3.1 Navigate to Testnet Faucet

On testnet dashboard, look for:
- **"Get Test Funds"**
- **"Faucet"**
- Or go to: https://testnet.binance.vision/en/faucet

### 3.2 Request Test USDT

1. Select **USDT** from asset dropdown
2. Click **"Get Testnet USDT"** or **"Request"**
3. You'll receive test USDT (usually 10,000 USDT)

### 3.3 Request Test BTC (Optional)

1. Select **BTC** from asset dropdown
2. Click **"Get Testnet BTC"**
3. You'll receive test BTC (usually 1 BTC)

### 3.4 Verify Balance

1. Go to **"Wallet"** → **"Spot Wallet"**
2. You should see:
   ```
   USDT: 10,000.00
   BTC:  1.00000000 (if you requested it)
   ```

**Note**: You can request more test funds anytime!

---

## 🧪 Step 4: Test API Keys Locally (Optional)

Before deploying to AWS, test your API keys locally.

### 4.1 Create Test Script

Create `test_binance_connection.py`:

```python
from backend.lambda.binance_trader import BinanceSpotTrader

# Your testnet API keys
API_KEY = "your_testnet_api_key_here"
API_SECRET = "your_testnet_secret_here"

# Initialize trader in testnet mode
trader = BinanceSpotTrader(
    api_key=API_KEY,
    api_secret=API_SECRET,
    testnet=True
)

print("Testing Binance Testnet Connection...")
print("=" * 50)

# Test 1: Connection
print("\n1. Testing API Connection...")
if trader.test_connection():
    print("✅ Connection successful!")
else:
    print("❌ Connection failed!")
    exit(1)

# Test 2: Account Info
print("\n2. Getting Account Info...")
try:
    account = trader.get_account_info()
    print(f"✅ Account Type: {account.get('accountType')}")
    print(f"✅ Can Trade: {account.get('canTrade')}")
except Exception as e:
    print(f"❌ Failed: {e}")

# Test 3: Check Balances
print("\n3. Checking Balances...")
try:
    usdt = trader.get_balance('USDT')
    btc = trader.get_balance('BTC')

    print(f"✅ USDT Balance: ${usdt['free']:.2f}")
    print(f"✅ BTC Balance: {btc['free']:.8f}")
except Exception as e:
    print(f"❌ Failed: {e}")

# Test 4: Get Current Price
print("\n4. Getting BTC/USDT Price...")
try:
    price = trader.get_current_price('BTCUSDT')
    print(f"✅ Current BTC Price: ${price:,.2f}")
except Exception as e:
    print(f"❌ Failed: {e}")

print("\n" + "=" * 50)
print("✅ All tests passed! API keys are working.")
print("You're ready to deploy to AWS!")
```

### 4.2 Run Test

```bash
cd c:\Users\suwan\Downloads\Github\Personal\bitcoin-watcher
python test_binance_connection.py
```

Expected output:
```
Testing Binance Testnet Connection...
==================================================

1. Testing API Connection...
✅ Connection successful!

2. Getting Account Info...
✅ Account Type: SPOT
✅ Can Trade: True

3. Checking Balances...
✅ USDT Balance: $10000.00
✅ BTC Balance: 1.00000000

4. Getting BTC/USDT Price...
✅ Current BTC Price: $96,500.00

==================================================
✅ All tests passed! API keys are working.
You're ready to deploy to AWS!
```

---

## 🔐 Step 5: Store Keys in AWS Secrets Manager

### 5.1 Go to AWS Secrets Manager

1. Login to **AWS Console**
2. Navigate to **Secrets Manager**
3. Select your region (same as your Lambda functions)

### 5.2 Create New Secret for Testnet

1. Click **"Store a new secret"**

2. **Secret type**: Select **"Other type of secret"**

3. **Key/value pairs**: Add your keys
   ```
   Key: api_key
   Value: [Paste your Binance Testnet API Key]

   Key: api_secret
   Value: [Paste your Binance Testnet Secret Key]
   ```

4. Click **"Next"**

5. **Secret name**: `bitcoin-watcher-binance-testnet`
   - ⚠️ Must match exactly! The code looks for this name.

6. **Description**: "Binance Testnet API credentials for Bitcoin Watcher bot"

7. Click **"Next"**

8. **Rotation**: Leave disabled for now
   - Click **"Next"**

9. **Review** and click **"Store"**

### 5.3 Verify Secret

1. Find your secret: `bitcoin-watcher-binance-testnet`
2. Click on it
3. Click **"Retrieve secret value"**
4. Verify you see both `api_key` and `api_secret`

### 5.4 Grant Lambda Access

Your Lambda function needs permission to read this secret.

**Option A: Using AWS Console**

1. Go to **IAM** → **Roles**
2. Find your Lambda execution role (e.g., `bitcoin-watcher-lambda-role`)
3. Click **"Add permissions"** → **"Attach policies"**
4. Search for **"SecretsManagerReadWrite"**
5. Attach it

**Option B: Add Inline Policy**

Add this to your Lambda's execution role:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "arn:aws:secretsmanager:REGION:ACCOUNT_ID:secret:bitcoin-watcher-binance-testnet-*"
        }
    ]
}
```

Replace:
- `REGION`: Your AWS region (e.g., `us-east-1`)
- `ACCOUNT_ID`: Your AWS account ID

---

## 📦 Step 6: Update Lambda Function

### 6.1 Add Trading Configuration

You'll need to add these settings to your MongoDB `settings` collection:

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      // Existing settings...
      "trading_enabled": false,  // Set to true when ready to trade
      "trading_mode": "testnet",  // "testnet" or "production"
      "trade_amount_usdt": 100,  // Amount to spend per BUY signal
      "sell_percentage": 100  // Percentage of BTC to sell (100 = all)
    }
  }
)
```

### 6.2 Deploy Updated Code

See **[TRADING_DEPLOYMENT_GUIDE.md](TRADING_DEPLOYMENT_GUIDE.md)** for detailed deployment steps.

---

## 🧪 Step 7: Test Trading (Paper Trading First!)

### 7.1 Enable Trading in Test Mode

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "trading_enabled": true,
      "trading_mode": "testnet",
      "trade_amount_usdt": 50  // Start small!
    }
  }
)
```

### 7.2 Manually Trigger a Signal

**Option 1: Wait for natural signal**
- Wait for your bot to generate a BUY or SELL signal

**Option 2: Force a test signal** (MongoDB)
```javascript
// Temporarily lower thresholds to trigger signal quickly
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "buy_threshold": 0.001,  // 0.1% - will trigger quickly
      "sell_threshold": 0.001
    }
  }
)

// Remember to restore after testing!
```

### 7.3 Monitor Execution

1. **CloudWatch Logs**: Watch Lambda execution
   ```
   🟢 EXECUTING BUY SIGNAL
   💵 USDT Balance: $10000.00
   📊 Current BTC Price: $96,500.00
   💰 Calculated quantity: 0.00051813 BTC
   ✅ Order placed successfully!
   ```

2. **MongoDB Trades Collection**: Check trade records
   ```javascript
   db.trades.find().sort({timestamp: -1}).limit(5)
   ```

3. **Binance Testnet Dashboard**: Verify orders
   - Go to **"Orders"** → **"Trade History"**
   - See your executed orders

---

## ✅ Step 8: Verify Everything Works

### Checklist:

- [ ] Testnet account created
- [ ] API keys generated and saved
- [ ] Test funds received (USDT + BTC)
- [ ] API keys tested locally (optional)
- [ ] Keys stored in AWS Secrets Manager
- [ ] Lambda has permission to read secrets
- [ ] Settings updated in MongoDB
- [ ] Test trade executed successfully
- [ ] Trade visible in Binance testnet
- [ ] Trade recorded in MongoDB

---

## 🚀 Step 9: Moving to Production (LATER!)

**⚠️ DO NOT DO THIS YET! Test thoroughly on testnet first.**

When you're ready for real trading:

### 9.1 Create Real Binance Account

1. Go to **https://www.binance.com**
2. Complete **full KYC verification**
3. Enable **2FA** (required)

### 9.2 Create Production API Keys

1. Similar process as testnet
2. **Be extra careful with permissions**:
   - ✅ Enable Reading
   - ✅ Enable Spot Trading
   - ❌ **DISABLE Withdrawals** (critical!)
   - ✅ **Enable IP Whitelist** (add AWS Lambda IPs)

### 9.3 Store Production Keys

Create separate secret: `bitcoin-watcher-binance-production`

### 9.4 Update Settings

```javascript
db.settings.updateOne(
  { "_id": "default" },
  {
    $set: {
      "trading_mode": "production",  // ⚠️ Real money!
      "trade_amount_usdt": 50  // Start VERY small!
    }
  }
)
```

### 9.5 Start Small!

- Begin with $50-$100 per trade
- Monitor closely for 1-2 weeks
- Gradually increase if performing well

---

## 🔒 Security Best Practices

### API Key Security

1. **Never commit keys to Git**
   ```bash
   # Add to .gitignore
   echo "*.env" >> .gitignore
   echo "*credentials*" >> .gitignore
   ```

2. **Use AWS Secrets Manager** (not environment variables)

3. **Rotate keys periodically**
   - Every 90 days recommended
   - Immediately if compromised

4. **Restrict permissions**
   - Only enable what's needed
   - NEVER enable withdrawals for bots

5. **IP Whitelist** (Production)
   - Add AWS Lambda IP ranges
   - Or use VPC with fixed IP

### Trading Safety

1. **Start with testnet** (fake money)
2. **Paper trade first** (track without executing)
3. **Start small** (max 1-5% of portfolio per trade)
4. **Use stop losses** (future enhancement)
5. **Monitor closely** (CloudWatch + notifications)

---

## 🆘 Troubleshooting

### Issue: "Invalid API Key"

**Solution:**
- Verify API key copied correctly (no extra spaces)
- Check API key is from testnet (not production)
- Ensure API key is enabled in Binance dashboard

---

### Issue: "Insufficient balance"

**Solution:**
- Request more test funds from faucet
- Check balance: `trader.get_balance('USDT')`
- Reduce `trade_amount_usdt` in settings

---

### Issue: "Permission denied"

**Solution:**
- Check API permissions include "Spot Trading"
- Verify Lambda has Secrets Manager permissions
- Check secret name matches exactly

---

### Issue: "Signature verification failed"

**Solution:**
- API secret might be wrong
- Check for extra spaces or newlines
- Regenerate API keys if needed

---

## 📊 Monitoring Your Bot

### Check Testnet Dashboard

- **Wallet**: See balances
- **Orders**: View trade history
- **API Management**: Monitor API usage

### MongoDB Queries

```javascript
// Recent trades
db.trades.find().sort({timestamp: -1}).limit(10)

// Today's trades
db.trades.find({
  timestamp: {
    $gte: new Date(new Date().setHours(0,0,0,0))
  }
})

// Profit/loss summary
db.trades.aggregate([
  {
    $group: {
      _id: null,
      total_trades: { $sum: 1 },
      buys: {
        $sum: { $cond: [{ $eq: ["$side", "BUY"] }, 1, 0] }
      },
      sells: {
        $sum: { $cond: [{ $eq: ["$side", "SELL"] }, 1, 0] }
      }
    }
  }
])
```

---

## 📚 Next Steps

1. ✅ Complete this guide
2. ✅ Test on testnet for 1-2 weeks
3. ✅ Review trade performance
4. ✅ Read **[TRADING_DEPLOYMENT_GUIDE.md](TRADING_DEPLOYMENT_GUIDE.md)**
5. ✅ Read **[RISK_MANAGEMENT.md](RISK_MANAGEMENT.md)**
6. ⏳ Consider production (only when comfortable!)

---

## 🎯 Quick Reference

### Testnet URLs
- Dashboard: https://testnet.binance.vision/
- API Docs: https://binance-docs.github.io/apidocs/spot/en/

### AWS Secret Name
```
bitcoin-watcher-binance-testnet
```

### MongoDB Settings
```javascript
{
  "trading_enabled": true,
  "trading_mode": "testnet",
  "trade_amount_usdt": 100,
  "sell_percentage": 100
}
```

---

**You're ready to start automated trading on testnet!** 🚀

Test thoroughly before considering real funds.
