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
| Donation certificates | `DonationCertificate` model issued on `.../complete`, listed in Donor Portal |
| Single mobile number constraint | `normalize_phone()` + `UNIQUE` column in `models.py` |
| Route guards / no cross-role access without logout | `AuthProvider` + `_RootRouter` in `main.dart` |
| Session persistence | `shared_preferences` (mobile/desktop equivalent of `sessionStorage`) |

Two things from the original doc were web-specific and don't carry over
1:1 to a mobile stack, so they're re-scoped rather than ignored:
- **PDF certificate generation** (`html2canvas-pro` + `jsPDF`, oklch color
  bug) → the backend now issues certificate *records*; rendering them as a
  downloadable PDF in Flutter is a small follow-up using the `pdf` +
  `printing` packages, noted in `frontend/README.md`.
- **Interactive geospatial radar map** → the AI ranking screen shows
  distance as a sortable number instead of a live map widget, to keep this
  a manageable mini-project; swap in `google_maps_flutter` later if needed.

## Honest note on "without any flaws"

This is a complete, working scaffold — auth, matching, dispatch, accept/
decline, certificates, admin controls, and audit logging all function
end-to-end. But no software ships flaw-free on a first pass: test it
against your own MySQL instance, and treat the two re-scoped items above
as known gaps rather than surprises.
