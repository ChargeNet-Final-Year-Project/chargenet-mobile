# Mobile architecture

`lib/main.dart` restores authentication and opens the app shell. Feature folders
own authentication, discovery, charging, activity/history and profile screens.
Shared tokens/theme/typography live in `lib/core`. The app uses ValueNotifier and
small service coordinators for application state.

- `ApiService` owns driver REST requests; `TokenStorage` persists authentication.
- `AppStateService` refreshes wallet, vehicles and history from the backend.
- `DiscoveryController` rejects superseded responses and reconciles selections.
- `SessionCoordinator` keeps a live charge across minimising/reopening and
  distinguishes confirmed completion from unavailable or interrupted telemetry.
- SSE delivers live snapshots; the transport watchdog and polling support recovery.

The backend is authoritative for eligibility, pricing acceptance, reservations,
settlement and receipts. Decimal estimate strings display backend-calculated
amounts. Tariffs and conditional simulated FX remain visible; secondary payment
and charger details expand. The settled wallet payment is the receipt's primary
amount. Missing paid totals remain unknown because energy alone cannot establish
the amount charged.

All screens retain the light theme, bundled Outfit font and Material controls.
Battery progress is linear; accessibility includes scalable text, contextual
confirmation alternatives to sliding, clear disabled/busy states and visible
interruption/error messages. Map rotation is disabled; OpenStreetMap attribution
is available through the compact OSM control.
