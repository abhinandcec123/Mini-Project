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
2. Copy `.env.example` to `.env` and fill in your MySQL credentials, a random `JWT_SECRET_KEY`, and a Google Maps API key with the Geocoding API enabled. Keep the Google key in the backend `.env`; do not add it to Flutter.

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

## 5. API summary

| Area | Endpoint |
|---|---|
| Auth | `POST /api/auth/donor/signup`, `/donor/login`, `/hospital/signup`, `/hospital/login`, `/admin/login` |
| Donor | `GET/PUT /api/donor/me`, `POST /api/donor/availability`, `GET /api/donor/requests`, `POST /api/donor/requests/<id>/accept|decline|complete`, `GET /api/donor/certificates` |
| Hospital | `POST /api/hospital/requests`, `GET /api/hospital/requests`, `GET /api/hospital/requests/<id>/candidates` (AI ranking), `POST /api/hospital/requests/<id>/dispatch/<donor_id>`, `GET /api/hospital/requests/<id>/matches`, `POST .../cancel`, `POST .../fulfill` |
| Admin | `GET /api/admin/donors`, `/hospitals`, `DELETE /api/admin/donors/<id>`, `/hospitals/<id>`, `GET /api/admin/audit-logs`, `/inventory`, `/stats`, `POST /api/admin/hospitals/<id>/verify` |

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
- **Soft deletes**: Admin "remove donor/hospital" sets `is_active = False`
  rather than deleting rows, preserving certificates and audit history.
