"""
Binance Spot Trading Module — Hodler Edition
Handles DCA-scaled BTC accumulation buys.
SELL is kept but not called by the signal engine — manual use only.
"""

import json
import hmac
import hashlib
import time
import requests
from urllib.parse import urlencode
from datetime import datetime
import pytz
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry


class BinanceSpotTrader:
    """
    Binance Spot Trading Client — Hodler Edition
    Supports testnet and production environments
    """

    TESTNET_BASE_URL = "https://testnet.binance.vision"
    PRODUCTION_BASE_URL = "https://api.binance.com"

    def __init__(self, api_key, api_secret, testnet=True):
        self.api_key = api_key
        self.api_secret = api_secret
        self.base_url = self.TESTNET_BASE_URL if testnet else self.PRODUCTION_BASE_URL
        self.testnet = testnet

        print(f"Initialized Binance Trader ({'TESTNET' if testnet else 'PRODUCTION'}) [Hodler Edition]")

        self.session = requests.Session()
        retries = Retry(
            total=3,
            backoff_factor=0.5,
            status_forcelist=[500, 502, 503, 504],
            allowed_methods=frozenset(['GET', 'POST', 'DELETE'])
        )
        self.session.mount('https://', HTTPAdapter(max_retries=retries))

    def _generate_signature(self, params):
        query_string = urlencode(params)
        signature = hmac.new(
            self.api_secret.encode('utf-8'),
            query_string.encode('utf-8'),
            hashlib.sha256
        ).hexdigest()
        return signature

    def _make_request(self, method, endpoint, params=None, signed=False):
        if params is None:
            params = {}

        url = f"{self.base_url}{endpoint}"
        headers = {'X-MBX-APIKEY': self.api_key}

        if signed:
            params['timestamp'] = int(time.time() * 1000)
            params['signature'] = self._generate_signature(params)

        try:
            if method == 'GET':
                response = self.session.get(url, params=params, headers=headers, timeout=10)
            elif method == 'POST':
                response = self.session.post(url, params=params, headers=headers, timeout=10)
            elif method == 'DELETE':
                response = self.session.delete(url, params=params, headers=headers, timeout=10)
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
        try:
            self._make_request('GET', '/api/v3/ping')
            print("✅ Binance API connection successful")
            return True
        except Exception as e:
            print(f"❌ Binance API connection failed: {e}")
            raise

    def get_account_info(self):
        return self._make_request('GET', '/api/v3/account', signed=True)

    def get_balance(self, asset='USDT'):
        try:
            account_info = self.get_account_info()
            for balance in account_info.get('balances', []):
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
        result = self._make_request('GET', '/api/v3/ticker/price', {'symbol': symbol})
        return float(result['price'])

    def get_symbol_info(self, symbol='BTCUSDT'):
        result = self._make_request('GET', '/api/v3/exchangeInfo', {'symbol': symbol})
        symbols = result.get('symbols', [])
        return symbols[0] if symbols else None

    def calculate_quantity(self, symbol, usdt_amount, current_price=None):
        if current_price is None:
            current_price = self.get_current_price(symbol)

        symbol_info = self.get_symbol_info(symbol)
        lot_size_filter = next(
            (f for f in symbol_info.get('filters', []) if f['filterType'] == 'LOT_SIZE'),
            None
        )
        if not lot_size_filter:
            raise ValueError("LOT_SIZE filter not found")

        min_qty = float(lot_size_filter['minQty'])
        max_qty = float(lot_size_filter['maxQty'])
        step_size = float(lot_size_filter['stepSize'])

        raw_quantity = usdt_amount / current_price
        quantity = round(raw_quantity / step_size) * step_size
        quantity = max(min_qty, min(quantity, max_qty))

        step_size_str = f"{step_size:.10f}".rstrip('0')
        decimals = len(step_size_str.split('.')[-1]) if '.' in step_size_str else 0
        quantity = round(quantity, decimals)

        print(f"💰 Calculated quantity: {quantity} BTC for ${usdt_amount:.2f} USDT at ${current_price:,.2f}")
        return quantity

    def place_market_order(self, symbol, side, quantity):
        params = {
            'symbol': symbol,
            'side': side,
            'type': 'MARKET',
            'quantity': quantity
        }
        print(f"🔄 Placing {side} order: {quantity} {symbol}")
        result = self._make_request('POST', '/api/v3/order', params, signed=True)
        print(f"✅ Order placed: ID={result.get('orderId')} | Status={result.get('status')} | Qty={result.get('executedQty')}")
        return result

    def execute_scaled_buy(self, usdt_base_amount, accumulation_score,
                           dca_scale_factor=1.5, max_usdt=200, symbol='BTCUSDT'):
        """
        DCA-scaled BUY — the core Hodler accumulation method.
        Buy size scales up with accumulation score:
          score 60–69: base amount × 1.0
          score 70–79: base × scale_factor × 0.75
          score 80–89: base × scale_factor × 1.0
          score 90+  : base × scale_factor × 1.25  (capped at max_usdt)
        """
        try:
            print(f"\n{'='*55}")
            print(f"🟢 HODLER DCA BUY — Score: {accumulation_score}/100")
            print(f"{'='*55}")

            # Scale factor based on score tier
            if accumulation_score >= 90:
                multiplier = dca_scale_factor * 1.25
            elif accumulation_score >= 80:
                multiplier = dca_scale_factor * 1.0
            elif accumulation_score >= 70:
                multiplier = dca_scale_factor * 0.75
            else:
                multiplier = 1.0

            scaled_usdt = min(usdt_base_amount * multiplier, max_usdt)
            print(f"📊 Score multiplier: {multiplier:.2f}x → ${scaled_usdt:.2f} USDT")

            # Check balance
            usdt_balance = self.get_balance('USDT')
            print(f"💵 USDT Balance: ${usdt_balance['free']:.2f}")

            if usdt_balance['free'] < scaled_usdt:
                if usdt_balance['free'] < usdt_base_amount * 0.5:
                    raise ValueError(
                        f"Insufficient USDT. Required: ${scaled_usdt:.2f}, "
                        f"Available: ${usdt_balance['free']:.2f}"
                    )
                # Use whatever is available (down to 50% of base)
                scaled_usdt = usdt_balance['free']
                print(f"⚠️  Adjusted to available balance: ${scaled_usdt:.2f} USDT")

            current_price = self.get_current_price(symbol)
            print(f"₿ Current BTC Price: ${current_price:,.2f}")

            quantity = self.calculate_quantity(symbol, scaled_usdt, current_price)
            order_result = self.place_market_order(symbol, 'BUY', quantity)

            print(f"{'='*55}\n")
            return order_result, scaled_usdt

        except Exception as e:
            print(f"❌ DCA BUY failed: {e}")
            print(f"{'='*55}\n")
            raise

    def execute_buy_signal(self, usdt_amount, symbol='BTCUSDT'):
        """Standard fixed-amount BUY (kept for compatibility)"""
        try:
            print(f"\n{'='*50}")
            print(f"🟢 EXECUTING BUY SIGNAL (fixed amount)")
            print(f"{'='*50}")

            usdt_balance = self.get_balance('USDT')
            if usdt_balance['free'] < usdt_amount:
                raise ValueError(
                    f"Insufficient USDT. Required: ${usdt_amount}, "
                    f"Available: ${usdt_balance['free']:.2f}"
                )

            current_price = self.get_current_price(symbol)
            quantity = self.calculate_quantity(symbol, usdt_amount, current_price)
            order_result = self.place_market_order(symbol, 'BUY', quantity)

            print(f"{'='*50}\n")
            return order_result
        except Exception as e:
            print(f"❌ BUY signal execution failed: {e}")
            raise

    def execute_sell_signal(self, btc_percentage=100, symbol='BTCUSDT'):
        """
        SELL — kept for manual use only.
        Not called by the hodler signal engine.
        """
        try:
            print(f"\n{'='*50}")
            print(f"🔴 EXECUTING SELL (MANUAL — Hodler mode)")
            print(f"{'='*50}")

            btc_balance = self.get_balance('BTC')
            if btc_balance['free'] <= 0:
                raise ValueError("No BTC available to sell")

            quantity_to_sell = btc_balance['free'] * (btc_percentage / 100)
            symbol_info = self.get_symbol_info(symbol)
            lot_size_filter = next(
                (f for f in symbol_info.get('filters', []) if f['filterType'] == 'LOT_SIZE'),
                None
            )
            step_size = float(lot_size_filter['stepSize'])
            quantity_to_sell = round(quantity_to_sell / step_size) * step_size
            step_size_str = f"{step_size:.10f}".rstrip('0')
            decimals = len(step_size_str.split('.')[-1]) if '.' in step_size_str else 0
            quantity_to_sell = round(quantity_to_sell, decimals)

            order_result = self.place_market_order(symbol, 'SELL', quantity_to_sell)
            print(f"{'='*50}\n")
            return order_result
        except Exception as e:
            print(f"❌ SELL failed: {e}")
            raise

    def get_trade_history(self, symbol='BTCUSDT', limit=10):
        params = {'symbol': symbol, 'limit': limit}
        return self._make_request('GET', '/api/v3/myTrades', params, signed=True)

    def format_trade_summary(self, trade_result):
        try:
            sri_lanka_tz = pytz.timezone('Asia/Colombo')
            timestamp = datetime.fromtimestamp(
                trade_result['transactTime'] / 1000, tz=sri_lanka_tz
            )
            fills = trade_result.get('fills', [])
            total_qty = sum(float(f['qty']) for f in fills)
            avg_price = (
                sum(float(f['price']) * float(f['qty']) for f in fills) / total_qty
                if total_qty > 0 else 0
            )
            return {
                'timestamp': timestamp.strftime('%Y-%m-%d %H:%M:%S %Z'),
                'order_id': trade_result['orderId'],
                'symbol': trade_result['symbol'],
                'side': trade_result['side'],
                'status': trade_result['status'],
                'executed_qty': float(trade_result['executedQty']),
                'average_price': avg_price,
            }
        except Exception as e:
            print(f"Failed to format trade summary: {e}")
            return trade_result


def get_binance_credentials_from_aws(testnet=True):
    """Fetch Binance API credentials from AWS Secrets Manager"""
    import boto3

    try:
        secrets_client = boto3.client('secretsmanager')
        secret_name = (
            'bitcoin-watcher-binance-testnet' if testnet
            else 'bitcoin-watcher-binance-production'
        )
        secret = secrets_client.get_secret_value(SecretId=secret_name)
        creds = json.loads(secret['SecretString'])
        return {'api_key': creds['api_key'], 'api_secret': creds['api_secret']}
    except Exception as e:
        print(f"Failed to fetch Binance credentials from AWS: {e}")
        raise


if __name__ == '__main__':
    print("Binance Spot Trader — Hodler Edition")
    print("This module is imported by signal_analyzer.py")
