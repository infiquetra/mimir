# Project: Mimir Improvements - Market Tools
Date: 2026-05-06

## Overview
We are expanding Mimir's functionality to support Market Tools. This involves implementing features for price checking, active order tracking, and transaction history. We will interact with ESI endpoints to fetch market prices and character orders, store them in the local Drift database, and create a user interface to display and interact with this data.

## Phase 1: Database & ESI Infrastructure [SEQ]

- [x] [SEQ] **Update Database Schema (`app_database.dart`)**
  - Add `MarketOrders` table (orderId, characterId, typeId, regionId, locationId, price, volumeRemain, volumeTotal, minVolume, isBuyOrder, issued, duration, range, isCorporation, escrow, state).
  - Add `MarketPrices` table (typeId, adjustedPrice, averagePrice, lastUpdated).
- [x] [SEQ] **Add ESI Endpoints (`esi_client.dart`)**
  - Implement `/markets/prices/` (get all market prices).
  - Implement `/characters/{character_id}/orders/` (get character active orders).
- [x] [SEQ] **Create Models**
  - Create data models for `MarketPrice` and `CharacterOrder` using Freezed/JsonSerializable.

## Phase 2: Repositories & Sync Services [SEQ]

- [x] [SEQ] **Implement `MarketRepository`**
  - Create `lib/features/market/data/market_repository.dart` to handle database CRUD operations for orders and prices.
- [x] [SEQ] **Implement `MarketSyncService`**
  - Create `lib/features/market/data/market_sync_service.dart` to fetch data from ESI and update the local database.
- [x] [SEQ] **Create Riverpod Providers**
  - Add `market_providers.dart` for streaming active orders and market prices to the UI.

## Phase 3: User Interface [SEQ]

- [ ] [SEQ] **Market Dashboard / Screen**
  - Create `MarketOverviewScreen` with primary tabs for "Active Orders" and "Price Checker".
- [ ] [SEQ] **Active Orders View**
  - Implement `ActiveOrdersPanel` to list a character's current buy and sell orders, displaying progress based on `volumeRemain` vs `volumeTotal`.
- [ ] [SEQ] **Price Checker View**
  - Implement `PriceCheckerPanel` to search for items and view their adjusted and average prices.
- [ ] [SEQ] **Multi-Window Integration**
  - Add "Market" to the main NavigationRail and the Tray menu.

## Phase 4: Testing & Review [SEQ]

- [x] [SEQ] Update MockEsiClient and test fixtures with dummy market orders and prices.
- [x] [SEQ] Write unit tests for `MarketRepository` and `MarketSyncService`.
- [x] [SEQ] Run `flutter test` and generate new goldens for the Market screens.