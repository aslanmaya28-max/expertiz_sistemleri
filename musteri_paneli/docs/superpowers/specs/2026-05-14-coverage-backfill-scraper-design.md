# Coverage Backfill Scraper Design

## Goal

Scraper workers must replenish the Docker/PostgreSQL market database according to measured coverage gaps, not by blindly iterating the full static target list. The system should keep popular Turkish vehicle references fresh enough for official AI valuation.

## Current State

- `MarketCoverageService` calculates coverage by brand, model, segment, and 5-year bucket.
- `/api/v1/market-coverage/summary` and `/api/v1/market-coverage/backfill-targets` expose admin-visible coverage data.
- `ScraperWorker` currently reads `get_priority_queue()` from `workers/turkey_targets.py`, expands each target into years, and scrapes every year in sequence.
- Scraper start/stop/status is already controlled by `ScraperManager` through `/api/v1/scrapers/*`.

## Chosen Approach

Use coverage-driven backfill as the scraper worker's first-class target source.

The worker will:

1. Ask `MarketCoverageService` for coverage rows.
2. Build backfill targets from `underfilled`, `filled_imbalanced`, and `stale` rows.
3. Convert each backfill row into a small set of scrape jobs using the target year bucket.
4. Prioritize by source priority, then missing count, then model identity.
5. Fall back to the old static target loop only when coverage cannot be calculated or no backfill targets exist.

This keeps existing scraper behavior available as a safety fallback while making the normal path data-quality driven.

## Scrape Job Rules

Each backfill row produces one or more jobs:

- `brand`, `model`, `segment`, `priority` come from coverage.
- `year_min` and `year_max` come from the year bucket.
- `preferred_fuel` and `preferred_transmission` are carried as metadata for future scraper filters.
- Initial implementation chooses the midpoint year of the bucket for legacy scraper methods that accept one year.
- Borusan already accepts a range-like call in `scrape_source`; it will continue to receive the selected midpoint until a later scraper-specific filter pass.

## Error Handling

- If coverage calculation raises, worker logs the error and uses the existing static priority queue.
- If one backfill job fails, the worker continues to the next job.
- If no targets are produced, the worker sleeps for the configured cycle interval.

## Testing

Add unit tests around target selection without launching real browsers:

- Underfilled coverage rows are preferred over static targets.
- Empty coverage falls back to static target list.
- Coverage exceptions fall back to static target list.
- Backfill rows produce deterministic midpoint-year jobs.

## Out of Scope

- Admin frontend charts.
- Deep scraper-specific fuel/transmission filtering.
- New Docker services.
- Changing the existing `ScraperManager` process model.

## Acceptance Criteria

- Worker can run in coverage mode without breaking existing scraper start/stop commands.
- Worker preserves old target loop as fallback.
- Unit tests cover coverage-preferred and fallback behavior.
- Existing coverage, central AI, and scraper route tests continue to pass.
