# LifePulse AI — Project Guide

LifePulse AI is a blood donor coordination application built with a Flutter client and a Flask REST API. Hospitals can create blood requests, review ranked donor candidates, and dispatch requests. Donors can manage availability and respond to requests. Administrators manage registries, hospital verification, inventory summaries, and audit history.

## Technology

| Layer | Technology |
|---|---|
| Client | Flutter / Dart |
| REST API | Python / Flask |
| Persistence | MySQL via SQLAlchemy; SQLite is available for local development |
| Authentication | JWT bearer tokens |
| Password storage | Bcrypt hashes |
| Location and map | Foreground GPS with OpenStreetMap tiles; optional Google address geocoding |

## Architecture overview

LifePulse AI follows a client–server architecture using Flutter/Dart as the client, Flask as the backend API, and MySQL as the primary database.

Donors, hospitals, and administrators use the Flutter application to manage their profiles and perform role-specific tasks. The client sends HTTP requests to the Flask API, which authenticates users with JWT bearer tokens, enforces role-based access, applies blood-request and donor-matching rules, and reads or updates application data through SQLAlchemy.

MySQL stores donor and hospital profiles, blood requests, donor matches, donation certificates, and audit records. For local development, the backend can be configured to use SQLite instead.

The matching component ranks eligible donors using distance, reliability, eligibility, and experience. Donor distance uses an explicitly shared foreground GPS snapshot, and hospital distance uses a facility GPS pin. Candidate maps use OpenStreetMap tiles. Optional Google Maps Geocoding can resolve addresses, but unresolved addresses are not assigned guessed coordinates. Matching is rules-based, not a trained machine-learning model.

## Repository layout

```text
backend/
  app.py                 Flask app, blueprint registration, health route
  config.py              Environment-based configuration
  models.py              SQLAlchemy models and blood-group rules
  schema.sql             Database schema bootstrap
  seed.py                Initial administrator seed
  routes/                Auth, donor, hospital, and admin endpoints
  utils/                 Matching, geocoding, and security helpers
  tests/                 Backend tests
  README.md              Backend setup details
frontend/
  lib/                   Flutter application source
  pubspec.yaml           Flutter package dependencies
  README.md              Frontend setup and platform notes
README.md                Short project overview and quick start
```

## Capabilities

### Donors

- Create an account and sign in with a normalized 10-digit phone number.
- View and update profile information and availability.
- Review incoming hospital requests and accept or decline pending requests.
- View donation certificate records issued after a hospital confirms a completed donation.
- Opt in to share a foreground GPS snapshot while available; turning availability off clears the shared location.

### Hospitals

- Register and sign in.
- Create and manage blood requests.
- Review donor candidates ranked for a request and dispatch requests to donors.
- Set a facility GPS pin from the hospital dashboard for accurate distances and mapping.
- Track match responses and request status.
- Confirm accepted donations; confirmation updates the request and creates a certificate record.

### Administrators

- Review donor and hospital registries.
- Add, verify, and deactivate hospitals; deactivate donors.
- View eligible available donor counts by blood group, dashboard statistics, and recent audit logs.

### Client application

The Flutter client provides role-specific entry and dashboards. Authentication state is persisted with `shared_preferences`; API requests use a shared service that adds bearer tokens where needed.

## Getting started

### Backend

1. Install Python and MySQL, then create a virtual environment:

   ```bash
   cd backend
   python -m venv venv
   # Windows PowerShell: .\venv\Scripts\Activate.ps1
   # macOS/Linux: source venv/bin/activate
   pip install -r requirements.txt
   ```

2. Copy `.env.example` to `.env` and configure database credentials and secrets. To create the database from the schema:

   ```bash
   mysql -u root -p < schema.sql
   ```

3. Start the API with `python app.py`. It listens on port 5000; `GET /api/health` is the health check. Tables are created on startup as well.

4. Seed an initial admin account with `python seed.py`. The current seed credentials are `admin@lifepulse.ai` / `Admin@123`; change them for any non-demo use.

### Flutter client

From `frontend/`, install packages and run the app:

```bash
cd frontend
flutter pub get
flutter run
```

See [frontend/README.md](frontend/README.md) for API host configuration across Android emulators and physical devices. Android emulators generally use `10.0.2.2` to reach the host computer; physical devices need the computer's LAN address.

## Configuration

Backend settings are read from environment variables (typically via `backend/.env`):

| Variable | Purpose |
|---|---|
| `MYSQL_HOST` | Database host (default: localhost) |
| `MYSQL_PORT` | Database port (default: 3306) |
| `MYSQL_USER` / `MYSQL_PASSWORD` | Database credentials |
| `MYSQL_DB` | Database name (default: lifepulse_db) |
| `USE_SQLITE` | Set to `true` to use the local SQLite database |
| `JWT_SECRET_KEY` | Secret used to sign access tokens; set a unique value |
| `GOOGLE_MAPS_API_KEY` | Optional geocoding key, kept on the backend |

## API overview

Protected endpoints require `Authorization: Bearer <token>`. Signup and login responses return a token and role.

| Area | Routes |
|---|---|
| Authentication | `POST /api/auth/donor/signup`, `/donor/login`, `/hospital/signup`, `/hospital/login`, `/admin/login` |
| Donor | `GET/PUT /api/donor/me`; `POST /api/donor/availability`; `GET /api/donor/requests`; `POST /api/donor/requests/<match_id>/accept` and `/decline`; `GET /api/donor/certificates` |
| Hospital | `GET /api/hospital/me`; `POST/GET /api/hospital/requests`; request detail, candidates, matches, dispatch, donation approval, cancel, and guarded fulfill routes under `/api/hospital/requests/<request_id>` |
| Administrator | `GET /api/admin/donors`, `/hospitals`, `/audit-logs`, `/inventory`, `/stats`; hospital creation/verification; donor and hospital deactivation |
| Health | `GET /api/health` |

For exact request payloads and response behavior, see the route handlers in `backend/routes/`.

## Matching and eligibility

The donor ranking helper uses a transparent weighted score based on distance, donor reliability, donation eligibility, and experience. Whole-blood donation eligibility uses an approximately 90-day interval. The ranking is a rules-based scorer, not a trained machine-learning model. Blood-group compatibility rules are defined in `backend/models.py`.

Phone numbers are normalized before lookup and stored with a uniqueness constraint. Administrator removal is implemented as deactivation, preserving donation and audit history.

## Known scope limits

- Hospital approval issues one-unit donation certificates; donors can download the certificate as a PDF from their portal.
- Donor-to-hospital mapping requires a hospital GPS pin and donors to be available and opted in; no background tracking is used.
- New donor requests are retrieved by the client; push notifications are not included.
- Google address geocoding is optional; accurate donor distances require GPS pins. Missing geocoding no longer invents coordinates.

## More detail

- [Backend guide](backend/README.md)
- [Frontend guide](frontend/README.md)
