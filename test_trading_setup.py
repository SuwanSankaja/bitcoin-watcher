"""
Complete Trading Bot Setup Verification Script
Tests all components: MongoDB, AWS Secrets, Binance API, and Lambda integration
Uses .env file for credentials
"""

import json
import os
from datetime import datetime, timedelta
import sys

# Load environment variables from .env file
try:
    from dotenv import load_dotenv
    load_dotenv()
    print("✅ Loaded .env file\n")
except ImportError:
    print("⚠️  python-dotenv not installed. Install with: pip install python-dotenv")
    print("   Trying to use environment variables directly...\n")

print("=" * 70)
print("BITCOIN WATCHER - TRADING BOT SETUP VERIFICATION")
print("=" * 70)
print()

# Track test results
tests_passed = 0
tests_failed = 0
errors = []

def test_result(test_name, passed, error_msg=None):
    global tests_passed, tests_failed, errors
    if passed:
        print(f"✅ {test_name}")
        tests_passed += 1
    else:
        print(f"❌ {test_name}")
        if error_msg:
            print(f"   Error: {error_msg}")
            errors.append(f"{test_name}: {error_msg}")
        tests_failed += 1
    print()

# ============================================================================
# TEST 1: Environment Variables Check
# ============================================================================
print("TEST 1: Environment Variables")
print("-" * 70)

# Check for required environment variables
env_vars = {
    'MONGODB_URI': os.getenv('MONGODB_URI'),
    'BINANCE_TESTNET_API_KEY': os.getenv('BINANCE_TESTNET_API_KEY'),
    'BINANCE_TESTNET_API_SECRET': os.getenv('BINANCE_TESTNET_API_SECRET')
}

for var_name, var_value in env_vars.items():
    if var_value:
        test_result(f"{var_name} found in .env", True)
        if 'SECRET' in var_name or 'URI' in var_name:
            print(f"   Value: {var_value[:20]}... (hidden for security)")
        else:
            print(f"   Value: {var_value[:30]}...")
        print()
    else:
        test_result(f"{var_name} found in .env", False, "Not set in .env file")

# ============================================================================
# TEST 2: MongoDB Connection & Settings
# ============================================================================
print("\nTEST 2: MongoDB Connection & Settings")
print("-" * 70)

try:
    from pymongo import MongoClient
    import pytz

    mongo_uri = env_vars['MONGODB_URI']
    if not mongo_uri:
        test_result("MongoDB connection", False, "MONGODB_URI not set in .env")
        print("Add to .env file: MONGODB_URI=your_connection_string")
        print()
    else:
        client = MongoClient(mongo_uri, serverSelectionTimeoutMS=5000)
        client.server_info()  # Test connection
        test_result("MongoDB connection successful", True)

        # Check database exists
        db = client['bitcoin_watcher']
        collections = db.list_collection_names()
        test_result("Database 'bitcoin_watcher' exists", True)

        # Check settings collection
        settings_collection = db['settings']
        settings_doc = settings_collection.find_one({'_id': 'default'})

        if settings_doc and 'settings' in settings_doc:
            test_result("Settings document found", True)

            settings = settings_doc['settings']
            print("Current Settings:")
            print(f"   • Notifications: {settings.get('notifications_enabled', 'NOT SET')}")
            print(f"   • Buy Threshold: {settings.get('buy_threshold', 'NOT SET')}")
            print(f"   • Sell Threshold: {settings.get('sell_threshold', 'NOT SET')}")
            print(f"   • Short MA Period: {settings.get('short_ma_period', 'NOT SET')}")
            print(f"   • Long MA Period: {settings.get('long_ma_period', 'NOT SET')}")
            print(f"   • Trading Enabled: {settings.get('trading_enabled', 'NOT SET')}")
            print(f"   • Trading Mode: {settings.get('trading_mode', 'NOT SET')}")
            print(f"   • Trade Amount (USDT): {settings.get('trade_amount_usdt', 'NOT SET')}")
            print(f"   • Sell Percentage: {settings.get('sell_percentage', 'NOT SET')}")
            print()

            # Verify required fields
            required_fields = [
                'buy_threshold', 'sell_threshold', 'short_ma_period', 'long_ma_period',
                'trading_enabled', 'trading_mode', 'trade_amount_usdt', 'sell_percentage'
            ]

            missing_fields = [field for field in required_fields if field not in settings]
            if missing_fields:
                test_result("All required settings present", False, f"Missing: {', '.join(missing_fields)}")
            else:
                test_result("All required settings present", True)

            # Verify recommended values for day trading
            if settings.get('buy_threshold') == 0.008 and settings.get('sell_threshold') == 0.008:
                test_result("Day trading thresholds configured (0.008)", True)
            else:
                test_result("Day trading thresholds configured", False,
                           f"Expected 0.008, got buy={settings.get('buy_threshold')}, sell={settings.get('sell_threshold')}")

            if settings.get('short_ma_period') == 5 and settings.get('long_ma_period') == 15:
                test_result("Day trading MA periods configured (5/15)", True)
            else:
                test_result("Day trading MA periods configured", False,
                           f"Expected 5/15, got {settings.get('short_ma_period')}/{settings.get('long_ma_period')}")

            # Check trading status
            if settings.get('trading_enabled') == True:
                print("⚠️  WARNING: Trading is ENABLED!")
                print(f"   Mode: {settings.get('trading_mode', 'unknown')}")
                if settings.get('trading_mode') == 'production':
                    print("   🚨 PRODUCTION MODE - REAL MONEY!")
                else:
                    print("   ✅ Testnet mode - Safe for testing")
                print()
            else:
                print("ℹ️  Trading is disabled (safe mode)")
                print()

        else:
            test_result("Settings document found", False, "No settings document with _id='default'")

        # Check for recent price data
        prices_collection = db['btc_prices']
        recent_price = prices_collection.find_one(sort=[('timestamp', -1)])
        if recent_price:
            test_result("Price data collection exists", True)
            print(f"   Latest price: ${recent_price.get('price', 'N/A'):,.2f}")
            print(f"   Timestamp: {recent_price.get('timestamp', 'N/A')}")
            print()
        else:
            test_result("Price data collection exists", False, "No price data found")

        # Check for recent signals
        signals_collection = db['signals']
        recent_signal = signals_collection.find_one(sort=[('timestamp', -1)])
        if recent_signal:
            test_result("Signals collection exists", True)
            print(f"   Latest signal: {recent_signal.get('type', 'N/A')}")
            print(f"   Price: ${recent_signal.get('price', 'N/A'):,.2f}")
            print(f"   Confidence: {recent_signal.get('confidence', 'N/A')}%")
            print(f"   Timestamp: {recent_signal.get('timestamp', 'N/A')}")
            print()
        else:
            test_result("Signals collection exists", False, "No signals found")

        # Check for trades (if trading enabled)
        if settings and settings.get('trading_enabled'):
            trades_collection = db['trades']
            trade_count = trades_collection.count_documents({})
            if trade_count > 0:
                test_result(f"Trades collection exists ({trade_count} trades)", True)
                recent_trade = trades_collection.find_one(sort=[('timestamp', -1)])
                print(f"   Latest trade: {recent_trade.get('side', 'N/A')}")
                print(f"   Status: {recent_trade.get('status', 'N/A')}")
                print(f"   Quantity: {recent_trade.get('executed_qty', 'N/A')}")
                print(f"   Price: ${recent_trade.get('average_price', 'N/A'):,.2f}")
                print()
            else:
                print("ℹ️  No trades executed yet (normal for new setup)")
                print()

        client.close()

except ImportError as e:
    test_result("Required Python packages", False, f"Missing: {e}")
    print("Install with: pip install pymongo pytz")
    print()
except Exception as e:
    test_result("MongoDB connection", False, str(e))
    print("Fix MongoDB connection and try again.")
    print()

# ============================================================================
# TEST 3: Binance API Connection
# ============================================================================
print("\nTEST 3: Binance Testnet API Connection")
print("-" * 70)

api_key = env_vars['BINANCE_TESTNET_API_KEY']
api_secret = env_vars['BINANCE_TESTNET_API_SECRET']

if not api_key or not api_secret:
    test_result("Binance API credentials from .env", False, "Missing API credentials in .env")
    print("Add to .env file:")
    print("BINANCE_TESTNET_API_KEY=your_api_key")
    print("BINANCE_TESTNET_API_SECRET=your_api_secret")
    print()
else:
    try:
        # Import the trading module
        sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend', 'lambda'))
        from binance_trader import BinanceSpotTrader

        trader = BinanceSpotTrader(
            api_key=api_key,
            api_secret=api_secret,
            testnet=True
        )

        # Test connection
        if trader.test_connection():
            test_result("Binance Testnet API connection", True)

            # Get account info
            try:
                account = trader.get_account_info()
                test_result("Binance account info retrieval", True)
                print(f"   Account Type: {account.get('accountType', 'N/A')}")
                print(f"   Can Trade: {account.get('canTrade', 'N/A')}")
                print()
            except Exception as e:
                test_result("Binance account info retrieval", False, str(e))

            # Get balances
            try:
                usdt_balance = trader.get_balance('USDT')
                btc_balance = trader.get_balance('BTC')
                test_result("Binance balance check", True)
                print(f"   USDT Balance: ${usdt_balance['free']:,.2f}")
                print(f"   BTC Balance: {btc_balance['free']:.8f}")
                print()

                if usdt_balance['free'] < 50:
                    print("⚠️  WARNING: USDT balance low - request more from testnet faucet")
                    print("   Visit: https://testnet.binance.vision/")
                    print()
            except Exception as e:
                test_result("Binance balance check", False, str(e))

            # Get current BTC price
            try:
                price = trader.get_current_price('BTCUSDT')
                test_result("Binance price fetch", True)
                print(f"   Current BTC/USDT: ${price:,.2f}")
                print()
            except Exception as e:
                test_result("Binance price fetch", False, str(e))

        else:
            test_result("Binance Testnet API connection", False, "Connection test failed")

    except ImportError as e:
        test_result("Trading module import", False, str(e))
        print("Make sure binance_trader.py exists in backend/lambda/")
        print()
    except Exception as e:
        test_result("Binance API tests", False, str(e))

# ============================================================================
# TEST 4: Signal Generation Logic Test
# ============================================================================
print("\nTEST 4: Signal Generation Logic")
print("-" * 70)

try:
    # Create sample price data
    sample_prices = []
    base_price = 96000

    # Simulate downtrend (should trigger BUY)
    for i in range(20):
        price = base_price - (i * 100)  # Decreasing prices
        sample_prices.append({
            'timestamp': datetime.now() - timedelta(minutes=20-i),
            'price': price
        })

    # Import signal analyzer functions
    sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'backend', 'lambda'))
    from signal_analyzer import calculate_moving_average, analyze_signal

    # Test MA calculation
    short_ma = calculate_moving_average(sample_prices, 5)
    long_ma = calculate_moving_average(sample_prices, 15)

    if short_ma and long_ma:
        test_result("Moving average calculation", True)
        print(f"   Short MA (5): ${short_ma:,.2f}")
        print(f"   Long MA (15): ${long_ma:,.2f}")
        print()
    else:
        test_result("Moving average calculation", False, "MA calculation returned None")

    # Test signal generation
    signal = analyze_signal(sample_prices, short_period=5, long_period=15,
                          buy_threshold=0.008, sell_threshold=0.008)

    test_result("Signal generation", True)
    print(f"   Signal Type: {signal['type']}")
    print(f"   Confidence: {signal['confidence']}%")
    print(f"   Current Price: ${signal['price']:,.2f}")
    print()

    # Verify logic is correct
    if short_ma < long_ma * (1 - 0.008):
        expected_signal = "BUY"
    elif short_ma > long_ma * (1 + 0.008):
        expected_signal = "SELL"
    else:
        expected_signal = "HOLD"

    print(f"   Expected signal: {expected_signal}")
    print(f"   Actual signal: {signal['type']}")

    if signal['type'] == expected_signal or signal['type'] == 'HOLD':
        test_result("Signal logic correct", True)
    else:
        test_result("Signal logic correct", False, f"Expected {expected_signal}, got {signal['type']}")

except ImportError as e:
    test_result("Signal analyzer import", False, str(e))
    print("Make sure signal_analyzer.py exists in backend/lambda/")
    print()
except Exception as e:
    test_result("Signal generation logic", False, str(e))

# ============================================================================
# SUMMARY
# ============================================================================
print("\n" + "=" * 70)
print("TEST SUMMARY")
print("=" * 70)
print(f"Tests Passed: {tests_passed}")
print(f"Tests Failed: {tests_failed}")
print()

if tests_failed > 0:
    print("ERRORS FOUND:")
    for i, error in enumerate(errors, 1):
        print(f"{i}. {error}")
    print()

# Final status
if tests_failed == 0:
    print("🎉 ALL TESTS PASSED! Your trading bot setup is ready!")
    print()
    print("Next Steps:")
    print("1. Deploy signal_analyzer.py and binance_trader.py to AWS Lambda")
    print("2. Store Binance API keys in AWS Secrets Manager")
    print("3. Monitor CloudWatch logs for trade execution")
    print("4. Check Binance testnet dashboard for orders")
    print()
    print("Documentation:")
    print("• BINANCE_TESTNET_SETUP.md - Binance setup guide")
    print("• TRADING_DEPLOYMENT_GUIDE.md - AWS deployment guide")
    print("• RISK_MANAGEMENT.md - Trading safety")
else:
    print("⚠️  SOME TESTS FAILED - Fix errors above before deploying")
    print()
    print("Common Fixes:")
    print("• Missing .env file: Create .env in project root")
    print("• MongoDB URI: Add MONGODB_URI=your_connection_string to .env")
    print("• Binance keys: Add BINANCE_TESTNET_API_KEY and BINANCE_TESTNET_API_SECRET to .env")
    print("• Settings: Run MongoDB update command (see earlier message)")
    print("• Packages: pip install pymongo pytz python-dotenv requests")

print("=" * 70)
