# LifePulse AI — Frontend (Flutter)

This folder contains the Flutter app source and its Android project.

## Setup

Install Flutter and Android Studio with the Android SDK, Android SDK
Command-line Tools, and an emulator or Android device. From this `frontend/`
directory, run `flutter pub get` and then start a local development build with
the backend running:

```bash
flutter run --dart-define=ALLOW_INSECURE_HTTP=true
```

The local API uses HTTP, so this opt-in is required for development. For a
release build, configure an HTTPS API URL with `API_BASE_URL` instead; do not
enable `ALLOW_INSECURE_HTTP`. Android Studio can open this directory directly.

## Connecting to the backend

`lib/utils/constants.dart` sets the API base URL:
- Android emulator → `http://10.0.2.2:5000/api` (already the default)
- iOS simulator / web / desktop → `http://localhost:5000/api` (already the default)
- A **real physical device** → replace with your computer's LAN IP, e.g.
  `http://192.168.1.5:5000/api`, since the phone can't reach "localhost"
  on your laptop.

## Accurate donor and hospital map pins

- Donors explicitly opt in when turning availability on. The app captures a
  foreground location snapshot using device location services or the browser
  Geolocation API; estimates up to 500 m accuracy are accepted and their
  accuracy is shown in the app. It does not track
  donors in the background. Turning availability off clears the shared pin.
  Donors can refresh the snapshot from their portal or drop a clearly labeled
  test pin on their own map to simulate different locations. Test pins are
  never presented as GPS and are hidden from hospitals/admins while unavailable.
- Hospitals set or refresh their facility pin from the dashboard while at the
  hospital. Candidate maps show the hospital and only available donors who
  have opted in to sharing their GPS location.
- Donors see only their own location map. Admins have a shared donor map that
  refreshes while open; it contains only available, opted-in donors and labels
  test pins. Location updates themselves remain donor-controlled and foreground
  only; no background tracking is performed.
- Close distances are shown in meters, so nearby pins are not rounded to
  `0.0 km`. Distance scoring retains sub-hundred-meter precision.
- Each hospital-approved donor contributes one unit to a request. Multi-unit
  requests remain open until enough distinct donors are approved. Approval
  updates donor history and issues a certificate that the donor can download
  as a PDF.
- Map tiles come from OpenStreetMap; precise GPS positioning does not depend
  on a Google Maps key. The optional backend Google Geocoding API can resolve
  addresses, but missing geocoding no longer creates guessed coordinates.
  Distances remain unknown until GPS pins are set.
- On web, allow location access for `localhost` in the browser's site
  permissions. On Android, grant location permission when prompted and enable
  device location services.

## App structure

| Path | Purpose |
|---|---|
| `lib/main.dart` | App entry + `_RootRouter`, which sends the user to the right dashboard based on the saved session's role — the route-guard equivalent of the original web app. |
| `lib/providers/auth_provider.dart` | Session state (token/role/user), persisted with `shared_preferences` so a restart doesn't log the user out — the Flutter equivalent of `sessionStorage`. |
| `lib/services/api_service.dart` | Thin HTTP client wrapper with auth header injection and error handling. |
| `lib/screens/auth_hub_screen.dart` | Entry hub → Donor / Hospital / Admin portals. |
| `lib/screens/donor_auth_screen.dart`, `hospital_auth_screen.dart`, `admin_login_screen.dart` | Sign-in/sign-up forms per role. |
| `lib/screens/donor_portal_screen.dart` | Availability toggle, personal map and test-pin control, incoming requests, certificates and PDF downloads. |
| `lib/screens/hospital_dashboard_screen.dart`, `request_detail_screen.dart`, `ai_recommendation_screen.dart` | Requisitions list + priority filter, create-request modal, AI donor ranking + "Send Request to Donor". |
| `lib/screens/admin_dashboard_screen.dart` | Live shared-donor map, donor/hospital registry, remove/verify actions, inventory reserve, audit log. |

## What's intentionally left out (for a mini-project scope)

- Push notifications for new emergency requests (the donor currently sees
  new requests by pulling to refresh).
