import os
import sys
from dotenv import load_dotenv

# Add lambda directory to path to import binance_trader
sys.path.append(os.path.join(os.path.dirname(__file__), 'lambda'))

from binance_trader import BinanceSpotTrader

# Load environment variables
load_dotenv()

def print_header(msg):
    print(f"\n{'='*50}")
    print(f" {msg}")
    print(f"{'='*50}")

def main():
    print_header("MANUAL SELL SCRIPT (TESTNET)")

    # 1. Get credentials from .env
    api_key = os.getenv('BINANCE_TESTNET_API_KEY')
    api_secret = os.getenv('BINANCE_TESTNET_API_SECRET')

    if not api_key or not api_secret:
        print("❌ Error: Missing BINANCE_TESTNET_API_KEY or BINANCE_TESTNET_API_SECRET in .env")
        return

    # 2. Initialize Trader
    try:
        trader = BinanceSpotTrader(
            api_key=api_key,
            api_secret=api_secret,
            testnet=True
        )
        trader.test_connection()
    except Exception as e:
        print(f"❌ Failed to connect to Binance: {e}")
        return

    # 3. Check Balances
    print("\n🔍 Checking Account Balances...")
    try:
        balances = trader.get_balances()
        btc_balance = balances.get('BTC', 0.0)
        usdt_balance = balances.get('USDT', 0.0)
        
        print(f"   BTC Balance:  {btc_balance:.8f}")
        print(f"   USDT Balance: {usdt_balance:.2f}")

        if btc_balance <= 0:
            print("\n❌ Error: You have 0 BTC. There is nothing to sell.")
            return

    except Exception as e:
        print(f"❌ Failed to fetch balances: {e}")
        return

    # 4. Confirm Sale
    print_header("CONFIRM SALE")
    print(f"You are about to sell ALL {btc_balance:.8f} BTC for USDT.")
    confirm = input("Type 'SELL' to confirm: ")

    if confirm.strip() != 'SELL':
        print("❌ Sale cancelled.")
        return

    # 5. Execute Sell
    print("\n🚀 Executing limit sell...")
    try:
        # We reuse the logic from binance_trader but force 100%
        result = trader.execute_sell_signal(btc_percentage=100)
        
        if result:
            print("\n✅ SUCCESS! Sold BTC.")
            print("New Balances:")
            new_balances = trader.get_balances()
            print(f"   BTC Balance:  {new_balances.get('BTC', 0.0):.8f}")
            print(f"   USDT Balance: {new_balances.get('USDT', 0.0):.2f}")
    except Exception as e:
        print(f"\n❌ Sell failed: {e}")

if __name__ == "__main__":
    main()
