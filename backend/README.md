# LifePulse AI — Backend (Flask + MySQL)

## 1. Setup

```bash
cd backend
python -m venv venv
source venv/bin/activate        # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

## 2. Configure the database

1. Create a MySQL database (or let `schema.sql` do it):
   ```bash
   mysql -u root -p < schema.sql
   ```
2. Copy `.env.example` to `.env` and fill in your MySQL credentials and a random `JWT_SECRET_KEY`. `GOOGLE_MAPS_API_KEY` is optional and only geocodes registration addresses. Keep the key on the backend; do not add it to Flutter. Unresolved addresses are left without coordinates rather than assigned guessed pins.

## 3. Run

```bash
python app.py
```

The API starts at `http://localhost:5000`. Tables are also auto-created on
first run via `db.create_all()`, so step 2's `schema.sql` is optional but
recommended for clarity. Existing databases receive the donor address column
automatically on startup.

## 4. Create the first admin account

```bash
python seed.py
```

Creates `admin@lifepulse.ai` / `Admin@123`. **Change this password after your first login** —
there's no "change password" endpoint yet, so for now update it directly via a
one-off script or the `admins` table.

## 5. Temporary password resets

An admin can issue a temporary password from the donor or hospital registry.
The generated password is shown once; share it securely with the account
holder. The reset invalidates existing sessions and requires the account
holder to set a new password immediately after signing in. Existing passwords
are never retrievable. The admin reset action is intended for controlled
support/demo use; there is no email or SMS delivery configured.

Hospital approval records exactly one donated unit per donor. For requests
requiring multiple units, approve a different eligible donor for each unit;
the request remains open until the approved donor count reaches the requested
units. Approval updates the donor's donation history and issues a certificate.

## 6. Run backend tests

By default, the backend tests use an in-memory SQLite database. To run them
against MySQL/MariaDB, first create a dedicated, empty test database:

```sql
CREATE DATABASE lifepulse_test CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

From the `backend` directory, set the test database URI and run the suite:

```powershell
$env:LIFEPULSE_TEST_DATABASE_URI = "mysql+pymysql://root@127.0.0.1:3306/lifepulse_test"
.\venv\Scripts\python.exe -m unittest discover -s tests -p "test*.py" -v
```

Adjust the local MySQL username, password, and port as needed. The test suite
creates and drops tables in `lifepulse_test`; its test configuration refuses
to use another MySQL database name. Never point this variable at a development
or production database.

## 7. API summary

| Area | Endpoint |
|---|---|
| Auth | `POST /api/auth/donor/signup`, `/donor/login`, `/hospital/signup`, `/hospital/login`, `/admin/login` |
| Donor | `GET/PUT /api/donor/me`, `PUT /api/donor/location`, `PUT /api/donor/location/pin` (manual test pin), `POST /api/donor/availability`, `GET /api/donor/requests`, `POST /api/donor/requests/<id>/accept|decline|complete`, `GET /api/donor/certificates` |
| Hospital | `GET /api/hospital/me`, `PUT /api/hospital/location`, `POST /api/hospital/requests`, `GET /api/hospital/requests`, `GET /api/hospital/requests/<id>/candidates` (ranking), `POST /api/hospital/requests/<id>/dispatch/<donor_id>`, `GET /api/hospital/requests/<id>/matches`, `POST .../cancel`, `POST .../fulfill` |
| Admin | `GET /api/admin/donors`, `/admin/donor-locations` (available, opted-in shared pins only), `/hospitals`, `DELETE /api/admin/donors/<id>`, `/hospitals/<id>`, `GET /api/admin/audit-logs`, `/inventory`, `/stats`, `POST /api/admin/hospitals/<id>/verify` |

All donor/hospital/admin routes (except signup/login) require
`Authorization: Bearer <token>` from the login/signup response.

## Notes on design choices

- **Single phone number constraint**: enforced both by a `UNIQUE` column and
  by normalizing input (`normalize_phone`) before every lookup/insert, so
  `"98765 43210"` and `9876543210` collide correctly.
- **AI donor ranking** (`utils/ai_matching.py`) is a transparent weighted
  scorer — distance (haversine, 40%), reliability history (30%), eligibility
  by 90-day donation gap (20%), and donation experience (10%) — not a black-box
  ML model, matching what the original app actually did.
- **Accurate location and privacy**: donors explicitly opt in when becoming
  available. The app takes a foreground GPS snapshot; turning availability
  off clears the shared pin. Donors can set a visibly labeled test pin for
  simulated matching; admins and hospitals receive only pins belonging to
  active, available, opted-in donors. Admin location maps poll the latest
  donor-submitted locations while open, but do not track donors. There is no
  background location tracking.
  Distances use donor GPS and a hospital GPS pin; without either, distance is
  unknown rather than guessed.
- **Soft deletes**: Admin "remove donor/hospital" sets `is_active = False`
  rather than deleting rows, preserving certificates and audit history.
