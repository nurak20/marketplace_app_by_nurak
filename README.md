# Nurak MK27

Flutter marketplace client for the Spring Boot API. The app uses one shared Dio API singleton, GoRouter for navigation, and SharedPreferences to keep the JWT session between launches.

## Run locally

The app reads `API_BASE_URL` from the root `.env` file before startup. Debug builds start on the login or marketplace screen; the API setup screen remains available for a temporary debug override.

The local Docker backend serves the API on port `7001`. Set the matching host in `.env` for your target:

```env
API_BASE_URL=http://localhost:7001/api/v1
```

For an Android emulator, use `http://10.0.2.2:7001/api/v1`. On a physical phone, use your computer's LAN IP address and keep both devices on the same Wi-Fi network. If you run the backend directly with Maven, its default port is `8081` instead. Restart or rebuild after changing `.env` because Flutter bundles it as an asset.

## App structure

- `lib/core/api.dart` is the app-wide Dio client and endpoint facade.
- `lib/core/session_store.dart` persists the access token with SharedPreferences.
- `lib/features/` contains auth, marketplace, messaging, profile, notifications, and review screens.
- `lib/shell/` contains the five-tab navigation shell.
