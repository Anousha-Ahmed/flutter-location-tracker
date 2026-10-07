# Location Tracker App

A Flutter mobile app that signs users in with Google, shows a map, fetches the
current location with a floating action button, and stores the latest location
in Firebase Firestore.

## Features

- Google Sign-In using Firebase Authentication
- Home screen with an interactive map (MapTiler / OpenStreetMap)
- Floating Action Button (bottom-right) to fetch current location
- Runtime location permission handling
- Camera moves to the user's location with a marker and accuracy circle
- Saves userId, latitude, longitude and timestamp to Firestore
- Every new fetch updates the same document with the latest location

## Tech Stack

- Flutter / Dart
- Firebase Authentication
- Cloud Firestore
- geolocator
- flutter_map + MapTiler tiles

## Project Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── config/
│   ├── secrets.dart            (ignored, your own key)
│   └── secrets.example.dart
├── services/
│   ├── auth_service.dart
│   ├── location_service.dart
│   └── firestore_service.dart
└── screens/
    ├── login_screen.dart
    └── home_screen.dart
```

## Firestore Structure

Collection `user_locations`, document ID = user UID:

| Field | Type |
|---|---|
| userId | string |
| latitude | number |
| longitude | number |
| updatedAt | timestamp |

## Setup

1. Clone the repo and run `flutter pub get`.
2. Create a Firebase project, enable **Google** sign-in and **Firestore**.
3. Run `flutterfire configure` to generate `firebase_options.dart`, and add
   `google-services.json` to `android/app/`.
4. Add your debug **SHA-1 and SHA-256** fingerprints in Firebase project settings.
5. Copy `lib/config/secrets.example.dart` to `lib/config/secrets.dart` and put
   your MapTiler API key in it.
6. Set Firestore rules:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /user_locations/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;
    }
  }
}
```

7. Run the app on an Android device: `flutter run`

## Note

The map uses MapTiler (OpenStreetMap data) instead of Google Maps SDK.