# Stock Alerts

A lightweight native macOS menu-bar utility for creating stock price alerts. This first implementation uses **Mock Data** and displays only generated completed-trade events as **Last Trade**. It does not connect to a brokerage, place trades, provide recommendations, or use bid/ask prices.

## Requirements

- macOS 13 or later
- Xcode 15+ or Swift 5.9+

## Build and run

```sh
swift build
swift run DadStockAlerts
```

To open the full manager directly as a desktop window, without first using the menu bar:

```sh
swift run DadStockAlerts --desktop
```

The chart icon appears in the macOS menu bar. Open it and choose **Open Alert Manager**. Add a symbol, alert type, and positive target price. Alerts are saved to `~/Library/Application Support/DadStockAlerts/alerts.json` and reload when the app starts.

Run tests with `swift test`.

## Normal macOS app

Create a double-clickable application bundle with:

```sh
./scripts/package-app.sh
```

Then open `dist/Stock Alerts.app`. This launches as a menu-bar application without opening Terminal.

## Current workflow

The main window keeps the alert table as its primary content. Click **+ New Price Alert** to open a focused sheet, then enter a stock symbol, choose **Buy Below**, **Buy Above**, **Sell Below**, or **Sell Above**, enter a target, optionally add a short local note, and click **Add Alert**. Below alerts trigger at or below the target; Above alerts trigger at or above it.

All saved alerts appear with equal visual weight in one native macOS table, sorted by creation date with the newest row first. Columns show Symbol, Type, Target, Last Trade, Distance, Status, Note, and row Actions.

Notes are optional, limited to 400 characters, stored only in the local alerts JSON, and never included in market-data subscriptions.

The menu-bar popover shows the current newest alert, status, Last Trade, target, pause/reset action, and a button to open the complete table. Mock completed trades update about every two seconds. Alerts trigger only from `CompletedTrade` events and can be dismissed, reset, edited, or deleted.

## Live market data

Open the main window and choose **Market Data**. Enter Alpaca Market Data API credentials, select a feed, and choose **Save & Connect**. Credentials are stored in the macOS Keychain.

- **IEX Real-Time Trades** works with Alpaca's Basic market-data plan.
- **Delayed SIP Trade Data** is explicitly labeled delayed.
- **SIP Real-Time Trades** requires the appropriate paid Alpaca market-data entitlement.

The WebSocket subscribes only to completed `trades` events for symbols currently being monitored. Quote and bar messages are ignored and cannot reach the alert engine. Mock Data remains available for offline testing.

## Notifications and sounds

When an alert triggers, the app plays a sound, posts a macOS notification, and switches the menu-bar icon to a bell badge until the alert is reset or dismissed. The menu-bar popover always surfaces the most recently triggered alert first. Notification permission is requested on first launch of the packaged app; notifications require running the packaged `Stock Alerts.app` (the bare `swift run` executable plays sounds only).
