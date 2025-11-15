# Wireless Programming – Personalized Weather Dashboard

A Flutter assignment that turns a student index (e.g., `194174B`) into latitude/longitude, queries the [Open-Meteo](https://open-meteo.com/) API, and displays current weather data with offline caching.

## Features

- Text input for the student index (prefilled, editable) with instant coordinate preview using the rules:
	- `lat = 5 + firstTwo / 10`
	- `lon = 79 + nextTwo / 10`
- Fetch button that shows a loading indicator, calls Open-Meteo, and renders temperature, wind speed, raw weather code, computed coordinates, request URL, and the device-side last updated time.
- Friendly error handling plus automatic reuse of the last successful response via `shared_preferences`, marked with a `(cached)` chip whenever offline data is shown.

## Run It

```bash
flutter pub get
flutter run
```

## Tests

```bash
flutter test
```

The widget test simply verifies that the dashboard scaffolding (index field, coordinate cards, fetch button) renders correctly with mocked preferences.
