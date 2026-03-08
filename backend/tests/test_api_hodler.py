"""
API Integration Tests for Bitcoin Watcher — Hodler Edition
Extends the original tests with /portfolio endpoint and new settings keys.

Run locally: pytest backend/tests/test_api_hodler.py -v
Run in CI:   Automatically triggered after hodler deploy via GitHub Actions
"""

import os
import time
import pytest
import requests

# ── Config ────────────────────────────────────────────────────────────────────
APIGW_REST_API_ID = os.environ.get("APIGW_REST_API_ID", "o9tic8ti7h")
REGION = "ap-northeast-1"
BASE_URL = f"https://{APIGW_REST_API_ID}.execute-api.{REGION}.amazonaws.com/prod"
TIMEOUT = 15  # seconds


# ── Helpers ───────────────────────────────────────────────────────────────────
def get(endpoint, params=None):
    return requests.get(f"{BASE_URL}{endpoint}", params=params, timeout=TIMEOUT)


def post(endpoint, json_body):
    return requests.post(f"{BASE_URL}{endpoint}", json=json_body, timeout=TIMEOUT)


# ── Tests: /currentPrice (hodler enriched) ────────────────────────────────────
class TestCurrentPriceHodler:
    def test_status_200(self):
        r = get("/currentPrice")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_price_key(self):
        data = get("/currentPrice").json()
        assert "price" in data, f"Missing 'price' key: {data}"

    def test_price_has_required_fields(self):
        price = get("/currentPrice").json()["price"]
        assert "timestamp" in price, f"Missing 'timestamp': {price}"
        assert "price" in price, f"Missing 'price': {price}"

    def test_price_is_positive_number(self):
        price = get("/currentPrice").json()["price"]["price"]
        assert isinstance(price, (int, float)), f"Price is not a number: {price}"
        assert price > 0, f"Price must be positive, got: {price}"

    def test_signal_key_present(self):
        data = get("/currentPrice").json()
        assert "signal" in data, f"Missing 'signal' key: {data}"

    def test_signal_has_valid_type(self):
        signal = get("/currentPrice").json().get("signal")
        if signal is not None:
            assert signal["type"] in ("BUY", "HOLD"), \
                f"Hodler signal should be BUY or HOLD, got: {signal['type']}"

    def test_signal_has_accumulation_score(self):
        """Hodler signals should include accumulation_score field."""
        signal = get("/currentPrice").json().get("signal")
        if signal is not None:
            assert "accumulation_score" in signal, \
                f"Missing 'accumulation_score' in signal: {signal}"
            assert "buy_zone" in signal, \
                f"Missing 'buy_zone' in signal: {signal}"

    def test_signal_has_fear_greed_index(self):
        signal = get("/currentPrice").json().get("signal")
        if signal is not None:
            assert "fear_greed_index" in signal, \
                f"Missing 'fear_greed_index' in signal: {signal}"


# ── Tests: /priceHistory ──────────────────────────────────────────────────────
class TestPriceHistoryHodler:
    def test_status_200(self):
        r = get("/priceHistory", params={"hours": 1})
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_prices_key(self):
        data = get("/priceHistory", params={"hours": 1}).json()
        assert "prices" in data, f"Missing 'prices' key: {data}"

    def test_prices_is_list(self):
        prices = get("/priceHistory", params={"hours": 1}).json()["prices"]
        assert isinstance(prices, list), f"Expected list, got {type(prices)}"


# ── Tests: /signalHistory ─────────────────────────────────────────────────────
class TestSignalHistoryHodler:
    def test_status_200(self):
        r = get("/signalHistory", params={"limit": 5})
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_notifications_key(self):
        data = get("/signalHistory", params={"limit": 5}).json()
        assert "notifications" in data, f"Missing 'notifications' key: {data}"

    def test_notifications_is_list(self):
        notifs = get("/signalHistory", params={"limit": 5}).json()["notifications"]
        assert isinstance(notifs, list), f"Expected list, got {type(notifs)}"


# ── Tests: /portfolio (NEW) ───────────────────────────────────────────────────
class TestPortfolio:
    """Tests for the /portfolio endpoint.
    Skips gracefully if the API Gateway route hasn't been provisioned yet (403).
    """

    @staticmethod
    def _get_portfolio():
        r = get("/portfolio")
        if r.status_code == 403 and "Missing Authentication Token" in r.text:
            pytest.skip("/portfolio API Gateway route not provisioned yet")
        return r

    def test_status_200(self):
        r = self._get_portfolio()
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_required_keys(self):
        r = self._get_portfolio()
        assert r.status_code == 200, f"Expected 200, got {r.status_code}"
        data = r.json()
        required_keys = (
            "total_btc_accumulated",
            "total_usdt_spent",
            "average_cost_basis",
            "current_btc_price",
            "current_value",
            "unrealized_pnl_percent",
            "trade_count",
            "trade_history",
        )
        for key in required_keys:
            assert key in data, f"Missing key '{key}' in portfolio: {data}"

    def test_types(self):
        r = self._get_portfolio()
        assert r.status_code == 200
        data = r.json()
        assert isinstance(data["total_btc_accumulated"], (int, float))
        assert isinstance(data["total_usdt_spent"], (int, float))
        assert isinstance(data["average_cost_basis"], (int, float))
        assert isinstance(data["current_btc_price"], (int, float))
        assert isinstance(data["current_value"], (int, float))
        assert isinstance(data["unrealized_pnl_percent"], (int, float))
        assert isinstance(data["trade_count"], int)
        assert isinstance(data["trade_history"], list)

    def test_values_are_non_negative(self):
        r = self._get_portfolio()
        assert r.status_code == 200
        data = r.json()
        assert data["total_btc_accumulated"] >= 0
        assert data["total_usdt_spent"] >= 0
        assert data["trade_count"] >= 0


# ── Tests: /settings (hodler extended) ────────────────────────────────────────
class TestSettingsHodler:
    def test_get_status_200(self):
        r = get("/settings")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_settings_key(self):
        data = get("/settings").json()
        assert "settings" in data, f"Missing 'settings' key: {data}"

    def test_required_settings_fields(self):
        """Hodler settings must include original + new DCA fields."""
        settings = get("/settings").json()["settings"]
        required = (
            "notifications_enabled", "buy_threshold",
            "short_ma_period", "long_ma_period",
            # Hodler-specific
            "min_score_threshold", "dca_scale_factor",
            "max_single_trade_usdt", "lookback_hours",
            "bb_period", "bb_std_dev",
        )
        for field in required:
            assert field in settings, f"Missing settings field: '{field}'"

    def test_min_score_threshold_range(self):
        settings = get("/settings").json()["settings"]
        v = settings.get("min_score_threshold", 60)
        assert 0 <= v <= 100, f"min_score_threshold out of range: {v}"

    def test_post_updates_settings(self):
        """Round-trip: POST new settings → GET to verify."""
        original = get("/settings").json()["settings"]

        test_min_score = 75 if original.get("min_score_threshold", 60) != 75 else 65
        payload = {**original, "min_score_threshold": test_min_score}

        r = post("/settings", payload)
        assert r.status_code == 200, f"POST failed: {r.status_code}: {r.text}"

        time.sleep(1)
        updated = get("/settings").json()["settings"]
        assert updated["min_score_threshold"] == test_min_score, \
            f"Expected {test_min_score}, got {updated['min_score_threshold']}"

        # Restore original
        post("/settings", original)


# ── Tests: /tradesHistory ─────────────────────────────────────────────────────
class TestTradesHistoryHodler:
    def test_status_200(self):
        r = get("/tradesHistory", params={"limit": 5})
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_trades_key(self):
        data = get("/tradesHistory", params={"limit": 5}).json()
        assert "trades" in data, f"Missing 'trades' key: {data}"

    def test_trades_is_list(self):
        trades = get("/tradesHistory", params={"limit": 5}).json()["trades"]
        assert isinstance(trades, list), f"Expected list, got {type(trades)}"
