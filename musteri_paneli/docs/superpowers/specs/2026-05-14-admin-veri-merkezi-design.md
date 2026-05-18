# Admin Veri Merkezi Design

## Goal

Admin panel must show market data health from the live coverage API so administrators can see which vehicle references are healthy, missing, imbalanced, or stale.

## Design

Add a new `/yonetim/veri-merkezi` page in the existing Next.js admin area. Keep scraper controls on `/yonetim/kaziyici`; the new page focuses only on data coverage and backfill visibility.

The page shows summary counters from `/api/v1/market-coverage/summary` and the first 200 backfill targets from `/api/v1/market-coverage/backfill-targets`. It includes a refresh button and a shortcut to scraper controls.

## Acceptance Criteria

- Admin left menu includes `Veri Merkezi`.
- Page redirects non-admin users the same way existing admin pages do.
- Page renders loading, error, empty, and loaded states.
- Page lists backfill targets with brand, model, segment, year bucket, missing count, preferred fuel, preferred transmission, and reason.
- Frontend production build passes.
