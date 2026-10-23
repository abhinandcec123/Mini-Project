# 🩸 LifePulse AI — Flutter + Flask + MySQL

A rebuild of the LifePulse AI blood donor network on the requested stack:
**Flutter/Dart** frontend, **Flask** backend, **MySQL** database.

```
lifepulse/
├── backend/     Flask REST API + MySQL models (see backend/README.md)
└── frontend/    Flutter app source (see frontend/README.md)
```

## Quick start

1. **Backend first** — follow `backend/README.md`: create the MySQL
   database, install requirements, run `python app.py`, then `python seed.py`
   to create the first admin login.
2. **Frontend** — follow `frontend/README.md`: scaffold a Flutter project
   with `flutter create`, drop in the provided `lib/` and `pubspec.yaml`,
   `flutter pub get`, then `flutter run`.

## What this covers, mapped from the original handover doc

| Original feature | Where it lives now |
|---|---|
| Donor accepts/declines requests | `POST /api/donor/requests/<id>/accept\|decline` + Donor Portal screen |
| "Dispatch" (hospital sends request to a donor) | `POST /api/hospital/requests/<id>/dispatch/<donor_id>` |
| AI donor ranking ("Simulate"/recommendation) | `utils/ai_matching.py` — weighted scorer (distance/reliability/eligibility/experience), surfaced in `ai_recommendation_screen.dart` |
| Admin: registry, remove donor/hospital, audit log, inventory | `routes/admin.py` + `admin_dashboard_screen.dart` |
| Donation certificates | Hospital approval issues one-unit records; donors can download PDF certificates from the Donor Portal |
| Single mobile number constraint | `normalize_phone()` + `UNIQUE` column in `models.py` |
| Route guards / no cross-role access without logout | `AuthProvider` + `_RootRouter` in `main.dart` |
| Session persistence | `shared_preferences` (mobile/desktop equivalent of `sessionStorage`) |

Some additions remain outside this mini-project scope:
- **Push notifications** → new donor requests are retrieved by refreshing
  the donor portal; push notifications can be added later.

The candidate screen includes an OpenStreetMap view with the hospital GPS pin
and available donors who explicitly opt in to foreground GPS sharing. Donors
are not tracked in the background. When accurate GPS pins are unavailable,
the app leaves distance unknown rather than inventing map coordinates.
Donors can place a clearly labeled test pin to simulate far-away locations;
their personal map is private, while admins see only opted-in donors marked
available. The admin map refreshes the latest donor-submitted pins periodically.

## Honest note on "without any flaws"

This is a complete, working scaffold — auth, matching, dispatch, accept/
decline, certificates, admin controls, and audit logging all function
end-to-end. But no software ships flaw-free on a first pass: test it
against your own MySQL instance, and treat the two re-scoped items above
as known gaps rather than surprises.
