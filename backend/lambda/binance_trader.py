"""
Binance Spot Trading Module
Handles automated BTC/USDT spot trading based on signals
Supports both Testnet and Production
"""

import json
import hmac
import hashlib
import time
import requests
from urllib.parse import urlencode
from datetime import datetime
import pytz


class BinanceSpotTrader:
    """
    Binance Spot Trading Client
    Supports testnet and production environments
    """

    # API Endpoints
    TESTNET_BASE_URL = "https://testnet.binance.vision"
    PRODUCTION_BASE_URL = "https://api.binance.com"

    def __init__(self, api_key, api_secret, testnet=True):
        """
        Initialize Binance trader

        Args:
            api_key: Binance API key
            api_secret: Binance API secret
            testnet: Use testnet if True, production if False
        """
        self.api_key = api_key
        self.api_secret = api_secret
        self.base_url = self.TESTNET_BASE_URL if testnet else self.PRODUCTION_BASE_URL
        self.testnet = testnet

        print(f"Initialized Binance Trader ({'TESTNET' if testnet else 'PRODUCTION'})")

    def _generate_signature(self, params):
        """Generate HMAC SHA256 signature"""
        query_string = urlencode(params)
        signature = hmac.new(
            self.api_secret.encode('utf-8'),
            query_string.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return signature

    def _make_request(self, method, endpoint, params=None, signed=False):
        """
        Make HTTP request to Binance API

        Args:
            method: HTTP method (GET, POST, DELETE)
            endpoint: API endpoint
            params: Request parameters
            signed: Whether request needs signature
        """
        if params is None:
            params = {}

        url = f"{self.base_url}{endpoint}"
        headers = {
            'X-MBX-APIKEY': self.api_key
        }

        if signed:
            params['timestamp'] = int(time.time() * 1000)
            params['signature'] = self._generate_signature(params)

        try:
            if method == 'GET':
                response = requests.get(url, params=params, headers=headers, timeout=10)
            elif method == 'POST':
                response = requests.post(url, params=params, headers=headers, timeout=10)
            elif method == 'DELETE':
                response = requests.delete(url, params=params, headers=headers, timeout=10)
            else:
                raise ValueError(f"Unsupported method: {method}")

            response.raise_for_status()
            return response.json()

        except requests.exceptions.RequestException as e:
            print(f"API request failed: {e}")
            if hasattr(e, 'response') and e.response is not None:
                print(f"Response: {e.response.text}")
            raise

    def test_connection(self):
        """Test API connectivity"""
        try:
            result = self._make_request('GET', '/api/v3/ping')
            print("✅ Binance API connection successful")
            return True
        except Exception as e:
            print(f"❌ Binance API connection failed: {e}")
            return False

    def get_account_info(self):
        """Get account information and balances"""
        try:
            result = self._make_request('GET', '/api/v3/account', signed=True)
            return result
        except Exception as e:
            print(f"Failed to get account info: {e}")
            raise

    def get_balance(self, asset='USDT'):
        """
        Get balance for specific asset

        Args:
            asset: Asset symbol (e.g., 'USDT', 'BTC')
        """
        try:
            account_info = self.get_account_info()
            balances = account_info.get('balances', [])

            for balance in balances:
                if balance['asset'] == asset:
                    return {
                        'asset': asset,
                        'free': float(balance['free']),
                        'locked': float(balance['locked']),
                        'total': float(balance['free']) + float(balance['locked'])
                    }

            return {'asset': asset, 'free': 0.0, 'locked': 0.0, 'total': 0.0}

        except Exception as e:
            print(f"Failed to get balance for {asset}: {e}")
            raise

    def get_current_price(self, symbol='BTCUSDT'):
        """Get current market price for symbol"""
        try:
            result = self._make_request('GET', '/api/v3/ticker/price', {'symbol': symbol})
            return float(result['price'])
        except Exception as e:
            print(f"Failed to get price for {symbol}: {e}")
            raise

    def get_symbol_info(self, symbol='BTCUSDT'):
        """Get trading rules and filters for symbol"""
        try:
            result = self._make_request('GET', '/api/v3/exchangeInfo', {'symbol': symbol})
            symbols = result.get('symbols', [])
            if symbols:
                return symbols[0]
            return None
        except Exception as e:
            print(f"Failed to get symbol info for {symbol}: {e}")
            raise

    def calculate_quantity(self, symbol, usdt_amount, current_price=None):
        """
        Calculate valid BTC quantity based on USDT amount

        Args:
            symbol: Trading pair (e.g., 'BTCUSDT')
            usdt_amount: Amount in USDT to spend
            current_price: Current BTC price (fetched if not provided)
        """
        try:
            if current_price is None:
                current_price = self.get_current_price(symbol)

            # Get symbol info for filters
            symbol_info = self.get_symbol_info(symbol)

            # Find LOT_SIZE filter
            lot_size_filter = None
            for filter_info in symbol_info.get('filters', []):
                if filter_info['filterType'] == 'LOT_SIZE':
                    lot_size_filter = filter_info
                    break

            if not lot_size_filter:
                raise ValueError("LOT_SIZE filter not found")

            # Calculate quantity
            min_qty = float(lot_size_filter['minQty'])
            max_qty = float(lot_size_filter['maxQty'])
            step_size = float(lot_size_filter['stepSize'])

            # Calculate BTC quantity from USDT amount
            raw_quantity = usdt_amount / current_price

            # Round to step size
            quantity = round(raw_quantity / step_size) * step_size

            # Ensure within limits
            if quantity < min_qty:
                print(f"⚠️ Calculated quantity {quantity} is below minimum {min_qty}")
                quantity = min_qty
            elif quantity > max_qty:
                print(f"⚠️ Calculated quantity {quantity} is above maximum {max_qty}")
                quantity = max_qty

            # Format to proper decimal places
            step_size_str = f"{step_size:.10f}".rstrip('0')
            decimals = len(step_size_str.split('.')[-1]) if '.' in step_size_str else 0
            quantity = round(quantity, decimals)

            print(f"💰 Calculated quantity: {quantity} BTC for ${usdt_amount} USDT at ${current_price}")
            return quantity

        except Exception as e:
            print(f"Failed to calculate quantity: {e}")
            raise

    def place_market_order(self, symbol, side, quantity):
        """
        Place market order

        Args:
            symbol: Trading pair (e.g., 'BTCUSDT')
            side: 'BUY' or 'SELL'
            quantity: Quantity to trade
        """
        try:
            params = {
                'symbol': symbol,
                'side': side,
                'type': 'MARKET',
                'quantity': quantity
            }

            print(f"🔄 Placing {side} order: {quantity} {symbol}")
            result = self._make_request('POST', '/api/v3/order', params, signed=True)

            print(f"✅ Order placed successfully!")
            print(f"   Order ID: {result.get('orderId')}")
            print(f"   Status: {result.get('status')}")
            print(f"   Executed Qty: {result.get('executedQty')}")

            return result

        except Exception as e:
            print(f"❌ Failed to place {side} order: {e}")
            raise

    def execute_buy_signal(self, usdt_amount, symbol='BTCUSDT'):
        """
        Execute BUY signal - Buy BTC with USDT

        Args:
            usdt_amount: Amount of USDT to spend on BTC
            symbol: Trading pair
        """
        try:
            print(f"\n{'='*50}")
            print(f"🟢 EXECUTING BUY SIGNAL")
            print(f"{'='*50}")

            # Check USDT balance
            usdt_balance = self.get_balance('USDT')
            print(f"💵 USDT Balance: ${usdt_balance['free']:.2f}")

            if usdt_balance['free'] < usdt_amount:
                raise ValueError(
                    f"Insufficient USDT balance. "
                    f"Required: ${usdt_amount}, Available: ${usdt_balance['free']:.2f}"
                )

            # Get current price
            current_price = self.get_current_price(symbol)
            print(f"📊 Current BTC Price: ${current_price:,.2f}")

            # Calculate quantity
            quantity = self.calculate_quantity(symbol, usdt_amount, current_price)

            # Place market buy order
            order_result = self.place_market_order(symbol, 'BUY', quantity)

            print(f"{'='*50}\n")
            return order_result

        except Exception as e:
            print(f"❌ BUY signal execution failed: {e}")
            print(f"{'='*50}\n")
            raise

    def execute_sell_signal(self, btc_percentage=100, symbol='BTCUSDT'):
        """
        Execute SELL signal - Sell BTC for USDT

        Args:
            btc_percentage: Percentage of BTC to sell (1-100)
            symbol: Trading pair
        """
        try:
            print(f"\n{'='*50}")
            print(f"🔴 EXECUTING SELL SIGNAL")
            print(f"{'='*50}")

            # Check BTC balance
            btc_balance = self.get_balance('BTC')
            print(f"₿ BTC Balance: {btc_balance['free']:.8f}")

            if btc_balance['free'] <= 0:
                raise ValueError("No BTC available to sell")

            # Calculate quantity to sell
            quantity_to_sell = btc_balance['free'] * (btc_percentage / 100)

            # Get symbol info for precision
            symbol_info = self.get_symbol_info(symbol)
            lot_size_filter = None
            for filter_info in symbol_info.get('filters', []):
                if filter_info['filterType'] == 'LOT_SIZE':
                    lot_size_filter = filter_info
                    break

            step_size = float(lot_size_filter['stepSize'])
            quantity_to_sell = round(quantity_to_sell / step_size) * step_size

            # Format to proper decimals
            step_size_str = f"{step_size:.10f}".rstrip('0')
            decimals = len(step_size_str.split('.')[-1]) if '.' in step_size_str else 0
            quantity_to_sell = round(quantity_to_sell, decimals)

            print(f"💱 Selling: {quantity_to_sell} BTC ({btc_percentage}% of balance)")

            # Get current price for reference
            current_price = self.get_current_price(symbol)
            estimated_usdt = quantity_to_sell * current_price
            print(f"📊 Current BTC Price: ${current_price:,.2f}")
            print(f"💵 Estimated USDT: ${estimated_usdt:.2f}")

            # Place market sell order
            order_result = self.place_market_order(symbol, 'SELL', quantity_to_sell)

            print(f"{'='*50}\n")
            return order_result

        except Exception as e:
            print(f"❌ SELL signal execution failed: {e}")
            print(f"{'='*50}\n")
            raise

    def get_trade_history(self, symbol='BTCUSDT', limit=10):
        """Get recent trades for the account"""
        try:
            params = {
                'symbol': symbol,
                'limit': limit
            }
            result = self._make_request('GET', '/api/v3/myTrades', params, signed=True)
            return result
        except Exception as e:
            print(f"Failed to get trade history: {e}")
            raise

    def format_trade_summary(self, trade_result):
        """Format trade result into readable summary"""
        try:
            sri_lanka_tz = pytz.timezone('Asia/Colombo')
            timestamp = datetime.fromtimestamp(
                trade_result['transactTime'] / 1000,
                tz=sri_lanka_tz
            )

            fills = trade_result.get('fills', [])
            total_qty = sum(float(fill['qty']) for fill in fills)
            total_commission = sum(float(fill['commission']) for fill in fills)
            avg_price = (
                sum(float(fill['price']) * float(fill['qty']) for fill in fills) / total_qty
                if total_qty > 0 else 0
            )

            summary = {
                'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S %Z'),
                'order_id': trade_result['orderId'],
                'symbol': trade_result['symbol'],
                'side': trade_result['side'],
                'type': trade_result['type'],
                'status': trade_result['status'],
                'executed_qty': float(trade_result['executedQty']),
                'average_price': avg_price,
                'total_commission': total_commission,
                'fills_count': len(fills)
            }

            return summary
        except Exception as e:
            print(f"Failed to format trade summary: {e}")
            return trade_result


def get_binance_credentials_from_aws(testnet=True):
    """
    Fetch Binance API credentials from AWS Secrets Manager

    Args:
        testnet: If True, fetch testnet credentials, otherwise production
    """
    import boto3

    try:
        secrets_client = boto3.client('secretsmanager')

        # Different secret names for testnet vs production
        secret_name = (
            'bitcoin-watcher-binance-testnet' if testnet
            else 'bitcoin-watcher-binance-production'
        )

        secret = secrets_client.get_secret_value(SecretId=secret_name)
        credentials = json.loads(secret['SecretString'])

        return {
            'api_key': credentials['api_key'],
            'api_secret': credentials['api_secret']
        }

    except Exception as e:
        print(f"Failed to fetch Binance credentials from AWS: {e}")
        raise


# Example usage (for testing)
if __name__ == '__main__':
    # This is just for local testing
    # In Lambda, credentials come from Secrets Manager

    print("Binance Spot Trader Module")
    print("This module is imported by signal_analyzer.py")
    print("For standalone testing, use test_binance_trader.py")
