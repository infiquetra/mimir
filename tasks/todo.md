# Project: Mimir Improvements - Market & Ship Fitting
Date: 2026-05-16
Checkpoint: 2026-05-16-10-00

## Overview
We are expanding Mimir's functionality to support Market Tools (Phase 3) and Ship Fitting (Phase 4). Market Tools includes price checking and active order tracking. Ship Fitting involves an integrated Dogma Engine, Drift database schemas for saved fits, and parsing EFT/DNA formats.

## Phase 1: Database & ESI Infrastructure (Market)
- [x] [SEQ] Update Database Schema (`app_database.dart`) with `MarketOrders` and `MarketPrices`.
- [x] [SEQ] Add ESI Endpoints (`esi_client.dart`).
- [x] [SEQ] Create Models for Market.

## Phase 2: Repositories & Sync Services (Market)
- [x] [SEQ] Implement `MarketRepository`.
- [x] [SEQ] Implement `MarketSyncService`.
- [x] [SEQ] Create Riverpod Providers.

## Phase 3: User Interface (Market)
- [x] [SEQ] Market Dashboard / Screen
- [x] [SEQ] Active Orders View
- [x] [SEQ] Price Checker View
- [x] [SEQ] Multi-Window Integration

## Phase 4: Ship Fitting Backend Infrastructure
- [x] [SEQ] Create core domain models (`Fitting`, `FittedModule`, `FittingStats`, `ShipType`, `ModuleType`).
- [x] [SEQ] Update Drift schema with `SavedFittings`, `FittingFolders`, and `FittingFolderMembers`.
- [x] [SEQ] Expand `sde_database.dart` and `sde_service.dart` to fetch Dogma attributes and effects.
- [x] [SEQ] Build native `DogmaEngine` in Dart for HP, EHP, Cap, CPU, and PG calculations with stacking penalties.
- [x] [SEQ] Build `FittingFormatParser` to handle EFT text blocks and DNA string imports/exports.
- [x] [CHECKPOINT] Save state before proceeding to UI implementation.

## Phase 5: Ship Fitting User Interface
- [x] [P1] Build Ship Browser
- [x] [P1] Build Fitting Editor Screen
- [x] [P1] Build Stats Panel

## Review
- **2026-05-16**: Implemented the backend architecture for the Ship Fitting Module. The Drift schema was updated with fitting tables and new Dogma attribute tables. The native Dogma Engine was created to parse base ship stats and modules to calculate effective hitpoints, capacitor stability, and resource requirements (CPU/Powergrid) with proper EVE stacking penalties. A format parser was added to translate between EFT strings, DNA share links, and the internal `Fitting` state representation.