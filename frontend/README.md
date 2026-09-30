# LifePulse AI — Frontend (Flutter)

This folder contains the Dart source (`lib/`) and `pubspec.yaml` for the
app, but not the generated native `android/`, `ios/`, `web/` platform
folders — those are machine-generated boilerplate that Flutter creates for
you, and regenerating them from scratch is what `flutter create` is for.

## Setup

```bash
# 1. Scaffold a new Flutter project (creates android/, ios/, web/, etc.)
flutter create lifepulse_ai_app
cd lifepulse_ai_app

# 2. Replace the generated lib/ and pubspec.yaml with the ones from this folder
rm -rf lib
cp -r ../frontend/lib .
cp ../frontend/pubspec.yaml .

# 3. Install packages
flutter pub get

# 4. Run (make sure the Flask backend is running first)
flutter run
```

## Connecting to the backend

`lib/utils/constants.dart` sets the API base URL:
- Android emulator → `http://10.0.2.2:5000/api` (already the default)
- iOS simulator / web / desktop → `http://localhost:5000/api` (already the default)
- A **real physical device** → replace with your computer's LAN IP, e.g.
  `http://192.168.1.5:5000/api`, since the phone can't reach "localhost"
  on your laptop.

## App structure

| Path | Purpose |
|---|---|
| `lib/main.dart` | App entry + `_RootRouter`, which sends the user to the right dashboard based on the saved session's role — the route-guard equivalent of the original web app. |
| `lib/providers/auth_provider.dart` | Session state (token/role/user), persisted with `shared_preferences` so a restart doesn't log the user out — the Flutter equivalent of `sessionStorage`. |
| `lib/services/api_service.dart` | Thin HTTP client wrapper with auth header injection and error handling. |
| `lib/screens/auth_hub_screen.dart` | Entry hub → Donor / Hospital / Admin portals. |
| `lib/screens/donor_auth_screen.dart`, `hospital_auth_screen.dart`, `admin_login_screen.dart` | Sign-in/sign-up forms per role. |
| `lib/screens/donor_portal_screen.dart` | Availability toggle, incoming requests (Accept/Decline/Complete), certificates list. |
| `lib/screens/hospital_dashboard_screen.dart`, `request_detail_screen.dart`, `ai_recommendation_screen.dart` | Requisitions list + priority filter, create-request modal, AI donor ranking + "Send Request to Donor". |
| `lib/screens/admin_dashboard_screen.dart` | Donor/hospital registry, remove/verify actions, inventory reserve, audit log. |

## What's intentionally left out (for a mini-project scope)

- A donation-certificate PDF viewer/exporter (the backend issues certificate
  *records*; rendering/downloading them as styled PDFs is a good "v2" add-on
  using a package like `pdf` + `printing`).
- Push notifications for new emergency requests (the donor currently sees
  new requests by pulling to refresh).
- Live map view of donor-to-hospital distance (the AI ranking screen shows
  distance as text/sorting instead of a map widget).
