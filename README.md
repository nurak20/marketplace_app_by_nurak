# NR Online Shopping

Flutter marketplace client for the Spring Boot API. The app uses one shared Dio API singleton, GoRouter for navigation, and SharedPreferences to keep the JWT session between launches.

## Run locally

Start the backend on port `8081`, then run the Flutter app. The app selects `localhost` on iOS simulator and desktop, and `10.0.2.2` on Android emulator.

Override the API address when needed. For an Android emulator:

```sh
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8081/api/v1
```

For an iOS simulator, use `http://localhost:8081/api/v1`.

## App structure

- `lib/core/api.dart` is the app-wide Dio client and endpoint facade.
- `lib/core/session_store.dart` persists the access token with SharedPreferences.
- `lib/features/` contains auth, marketplace, messaging, profile, notifications, and review screens.
- `lib/shell/` contains the five-tab navigation shell.
