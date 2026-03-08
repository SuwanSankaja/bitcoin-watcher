"""
API Integration Tests for Bitcoin Watcher
Run locally: pytest backend/tests/test_api.py -v
Run in CI:   Automatically triggered after Lambda deployment via GitHub Actions
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


# ── Tests: /currentPrice ──────────────────────────────────────────────────────
class TestCurrentPrice:
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
        if signal is not None:  # signal can be null if not yet generated
            assert signal["type"] in ("BUY", "SELL", "HOLD"), \
                f"Invalid signal type: {signal['type']}"
            assert 0 <= signal["confidence"] <= 100, \
                f"Confidence out of range: {signal['confidence']}"


# ── Tests: /priceHistory ──────────────────────────────────────────────────────
class TestPriceHistory:
    def test_status_200(self):
        r = get("/priceHistory", params={"hours": 1})
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_prices_key(self):
        data = get("/priceHistory", params={"hours": 1}).json()
        assert "prices" in data, f"Missing 'prices' key: {data}"

    def test_prices_is_list(self):
        prices = get("/priceHistory", params={"hours": 1}).json()["prices"]
        assert isinstance(prices, list), f"Expected list, got {type(prices)}"

    def test_price_entries_have_required_fields(self):
        prices = get("/priceHistory", params={"hours": 24}).json()["prices"]
        if prices:
            entry = prices[0]
            assert "timestamp" in entry, f"Missing 'timestamp': {entry}"
            assert "price" in entry, f"Missing 'price': {entry}"
            assert entry["price"] > 0, f"Price must be positive: {entry['price']}"

    def test_prices_are_chronological(self):
        prices = get("/priceHistory", params={"hours": 24}).json()["prices"]
        if len(prices) > 1:
            timestamps = [p["timestamp"] for p in prices]
            assert timestamps == sorted(timestamps), "Prices should be in chronological order"

    def test_24h_returns_more_than_1h(self):
        h1 = get("/priceHistory", params={"hours": 1}).json()["prices"]
        h24 = get("/priceHistory", params={"hours": 24}).json()["prices"]
        assert len(h24) >= len(h1), "24h should return >= data points than 1h"


# ── Tests: /signalHistory ─────────────────────────────────────────────────────
class TestSignalHistory:
    def test_status_200(self):
        r = get("/signalHistory", params={"limit": 5})
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_notifications_key(self):
        data = get("/signalHistory", params={"limit": 5}).json()
        assert "notifications" in data, f"Missing 'notifications' key: {data}"

    def test_notifications_is_list(self):
        notifs = get("/signalHistory", params={"limit": 5}).json()["notifications"]
        assert isinstance(notifs, list), f"Expected list, got {type(notifs)}"

    def test_limit_is_respected(self):
        notifs = get("/signalHistory", params={"limit": 2}).json()["notifications"]
        assert len(notifs) <= 2, f"Limit=2 but got {len(notifs)} items"

    def test_notification_fields(self):
        notifs = get("/signalHistory", params={"limit": 5}).json()["notifications"]
        if notifs:
            n = notifs[0]
            for field in ("_id", "timestamp", "title", "message", "signal_type", "price"):
                assert field in n, f"Missing field '{field}' in notification: {n}"
            assert n["signal_type"] in ("BUY", "SELL", "HOLD"), \
                f"Invalid signal_type: {n['signal_type']}"


# ── Tests: /settings ──────────────────────────────────────────────────────────
class TestSettings:
    def test_get_status_200(self):
        r = get("/settings")
        assert r.status_code == 200, f"Expected 200, got {r.status_code}: {r.text}"

    def test_has_settings_key(self):
        data = get("/settings").json()
        assert "settings" in data, f"Missing 'settings' key: {data}"

    def test_required_settings_fields(self):
        settings = get("/settings").json()["settings"]
        required = ("notifications_enabled", "buy_threshold", "sell_threshold",
                    "short_ma_period", "long_ma_period")
        for field in required:
            assert field in settings, f"Missing settings field: '{field}'"

    def test_post_updates_settings(self):
        """Round-trip: POST new settings → GET to verify they were saved."""
        original = get("/settings").json()["settings"]

        # Update with a distinguishable test value
        test_buy_threshold = round(original["buy_threshold"] + 0.001, 4)
        payload = {**original, "buy_threshold": test_buy_threshold}

        r = post("/settings", payload)
        assert r.status_code == 200, f"POST failed: {r.status_code}: {r.text}"

        # Verify the update was persisted
        time.sleep(1)
        updated = get("/settings").json()["settings"]
        assert updated["buy_threshold"] == test_buy_threshold, \
            f"Expected {test_buy_threshold}, got {updated['buy_threshold']}"

        # Restore original settings
        post("/settings", original)
