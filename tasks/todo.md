# Project: Mimir Improvements - Industry & Manufacturing
Date: 2026-05-06

## Overview
We are expanding Mimir's functionality to support Industry & Manufacturing. This involves adding features for a blueprint browser and an industry manufacturing calculator. We will need to interact with ESI endpoints to fetch blueprints and industry jobs, store them in the local Drift database, and create a user interface to display and interact with this data.

## Phase 1: Database & ESI Infrastructure [SEQ]

- [x] [SEQ] **Update Database Schema (`app_database.dart`)**
  - Add `Blueprints` table (itemId, typeId, locationId, quantity, timeEfficiency, materialEfficiency, runs, isOriginal).
  - Add `IndustryJobs` table (jobId, installerId, facilityId, locationId, activityId, blueprintId, blueprintTypeId, outputLocationId, runs, cost, licensedProductionRuns, probabilities, productTypeId, status, timeInSeconds, startDate, endDate, pauseDate, completedDate, completedCharacterId, successfulRuns).
- [x] [SEQ] **Add ESI Endpoints (`esi_client.dart`)**
  - Implement `/characters/{character_id}/blueprints/` (get blueprints).
  - Implement `/characters/{character_id}/industry/jobs/` (get character industry jobs).
- [x] [SEQ] **Create Models**
  - Create data models for `Blueprint` and `IndustryJob` using Freezed/JsonSerializable.

## Phase 2: Repositories & Sync Services [SEQ]

- [x] [SEQ] **Implement `IndustryRepository`**
  - Create `lib/features/industry/data/industry_repository.dart` to handle database CRUD operations for blueprints and jobs.
- [x] [SEQ] **Implement `IndustrySyncService`**
  - Create `lib/features/industry/data/industry_sync_service.dart` to fetch data from ESI and update the local database.
- [x] [SEQ] **Create Riverpod Providers**
  - Add `industry_providers.dart` for streaming blueprints and industry jobs to the UI.

## Phase 3: User Interface [SEQ]

- [x] [SEQ] **Industry Dashboard / Screen**
  - Create `IndustryOverviewScreen` with two primary tabs: Blueprints and Jobs.
- [x] [SEQ] **Blueprints Browser**
  - Implement `BlueprintListPanel` to view, filter, and sort blueprints.
- [x] [SEQ] **Industry Jobs View**
  - Implement `IndustryJobsPanel` showing active, paused, and completed jobs with progress bars.
- [x] [SEQ] **Multi-Window Integration**
  - Add "Industry & Manufacturing" to the main NavigationRail and the Tray menu.

## Phase 4: Testing & Review [SEQ]

- [x] [SEQ] Update MockEsiClient and test fixtures with dummy blueprints and jobs.
- [x] [SEQ] Write unit tests for `IndustryRepository` and `IndustrySyncService`.
- [x] [SEQ] Run `flutter test` and generate new goldens for the Industry screens.