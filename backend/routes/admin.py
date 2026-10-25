import secrets
import string
from datetime import datetime
from flask import Blueprint, request, jsonify, current_app
from extensions import db, bcrypt
from models import (
    Donor,
    Hospital,
    BloodRequest,
    RequestMatch,
    DonationCertificate,
    AuditLog,
    log_action,
    normalize_phone,
    BLOOD_GROUPS,
)
from utils.geocoding import GeocodingError, geocode_address
from utils.security import role_required, current_user_id
from utils.dispatch_queue import advance_ranked_queues

admin_bp = Blueprint("admin", __name__, url_prefix="/api/admin")


@admin_bp.get("/donors")
@role_required("admin")
def list_donors():
    donors = Donor.query.filter_by(is_active=True).order_by(Donor.created_at.desc()).all()
    return jsonify([d.to_dict() for d in donors]), 200


@admin_bp.get("/donor-locations")
@role_required("admin")
def donor_locations():
    donors = Donor.query.filter(
        Donor.is_active.is_(True),
        Donor.is_available.is_(True),
        Donor.location_sharing_enabled.is_(True),
        Donor.gps_latitude.isnot(None),
        Donor.gps_longitude.isnot(None),
    ).order_by(Donor.full_name.asc()).all()
    return jsonify([
        {
            "id": donor.id,
            "full_name": donor.full_name,
            "blood_group": donor.blood_group,
            "latitude": donor.gps_latitude,
            "longitude": donor.gps_longitude,
            "location_source": donor.gps_location_source or "gps",
            "accuracy_m": donor.gps_accuracy_m,
        }
        for donor in donors
    ]), 200


@admin_bp.post("/hospitals")
@role_required("admin")
def create_hospital():
    data = request.get_json(force=True) or {}
    required = ["name", "registration_number", "phone", "password"]
    missing = [field for field in required if not data.get(field)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    phone = normalize_phone(data["phone"])
    if len(phone) != 10:
        return jsonify({"error": "Enter a valid 10-digit mobile number"}), 400
    if Hospital.query.filter_by(phone=phone).first():
        return jsonify({"error": "This mobile number is already registered"}), 409
    if Hospital.query.filter_by(registration_number=data["registration_number"]).first():
        return jsonify({"error": "This registration number is already in use"}), 409

    address = (data.get("address") or "").strip()
    city = (data.get("city") or "").strip()
    latitude = data.get("latitude")
    longitude = data.get("longitude")
    skip_geocoding = bool(data.get("skip_geocoding"))

    try:
        if latitude is not None:
            latitude = float(latitude)
        if longitude is not None:
            longitude = float(longitude)
    except (TypeError, ValueError):
        return jsonify({"error": "Latitude and longitude must be numeric values"}), 400

    location = None
    if address and not skip_geocoding:
        location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))
        latitude = latitude if latitude is not None else location["latitude"]
        longitude = longitude if longitude is not None else location["longitude"]
        city = city or location.get("city") or ""

    hospital = Hospital(
        name=data["name"].strip(),
        registration_number=data["registration_number"].strip(),
        phone=phone,
        email=data.get("email"),
        password_hash=bcrypt.generate_password_hash(data["password"]).decode("utf-8"),
        address=address,
        city=city,
        latitude=latitude,
        longitude=longitude,
        fallback_latitude=(location or {}).get("fallback_latitude", latitude),
        fallback_longitude=(location or {}).get("fallback_longitude", longitude),
        location_source=(location or {}).get("location_source", "address"),
        location_accuracy_km=(location or {}).get("accuracy_radius_km", 0.0),
        is_verified=True,
        is_active=True,
    )
    db.session.add(hospital)
    db.session.commit()
    log_action("admin", current_user_id(), "created_hospital", f"hospital_id={hospital.id}")
    return jsonify({"message": "Hospital added by admin", "hospital": hospital.to_dict()}), 201


@admin_bp.get("/hospitals")
@role_required("admin")
def list_hospitals():
    hospitals = Hospital.query.filter_by(is_active=True).order_by(Hospital.created_at.desc()).all()
    return jsonify([h.to_dict() for h in hospitals]), 200


@admin_bp.post("/users/<string:account_type>/<int:account_id>/temporary-password")
@role_required("admin")
def issue_temporary_password(account_type, account_id):
    account_model = {"donor": Donor, "hospital": Hospital}.get(account_type)
    if account_model is None:
        return jsonify({"error": "Temporary passwords can only be issued to donors or hospitals"}), 400
    account = db.session.get(account_model, account_id)
    if not account:
        return jsonify({"error": f"{account_type.title()} not found"}), 404
    if not account.is_active:
        return jsonify({"error": "Cannot reset a deactivated account"}), 409

    alphabet = string.ascii_letters + string.digits
    temporary_password = "".join(secrets.choice(alphabet) for _ in range(16))
    account.password_hash = bcrypt.generate_password_hash(temporary_password).decode("utf-8")
    account.must_change_password = True
    account.password_version += 1
    db.session.commit()
    log_action(
        "admin",
        current_user_id(),
        "issued_temporary_password",
        f"account_type={account_type}, account_id={account_id}",
    )
    return jsonify({
        "temporary_password": temporary_password,
        "message": "Share this temporary password securely. It is shown only once.",
    }), 200


@admin_bp.post("/hospitals/<int:hospital_id>/verify")
@role_required("admin")
def verify_hospital(hospital_id):
    hospital = Hospital.query.get(hospital_id)
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    hospital.is_verified = True
    db.session.commit()
    log_action("admin", current_user_id(), "verified_hospital", f"hospital_id={hospital_id}")
    return jsonify(hospital.to_dict()), 200


@admin_bp.delete("/donors/<int:donor_id>")
@role_required("admin")
def remove_donor(donor_id):
    donor = Donor.query.get(donor_id)
    if not donor:
        return jsonify({"error": "Donor not found"}), 404
    donor.is_active = False  # preserve history while removing donor network access
    donor.is_available = False
    donor.location_sharing_enabled = False
    donor.gps_latitude = None
    donor.gps_longitude = None
    donor.gps_accuracy_m = None
    donor.gps_location_source = None
    donor.password_version += 1
    affected_requests = set()
    for match in RequestMatch.query.filter(
        RequestMatch.donor_id == donor.id,
        RequestMatch.status.in_(("pending", "accepted")),
    ).all():
        match.status = "declined"
        match.responded_at = datetime.utcnow()
        affected_requests.add(match.request_id)
    db.session.commit()
    log_action("admin", current_user_id(), "removed_donor", f"donor_id={donor_id}")
    advance_ranked_queues(affected_requests)
    return jsonify({"message": "Donor removed"}), 200


@admin_bp.delete("/hospitals/<int:hospital_id>")
@role_required("admin")
def remove_hospital(hospital_id):
    hospital = Hospital.query.get(hospital_id)
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    hospital.is_active = False
    hospital.password_version += 1
    for blood_request in BloodRequest.query.filter_by(
        hospital_id=hospital.id,
        status="open",
    ).all():
        blood_request.status = "cancelled"
        for match in RequestMatch.query.filter(
            RequestMatch.request_id == blood_request.id,
            RequestMatch.status.in_(("pending", "accepted")),
        ).all():
            match.status = "declined"
            match.responded_at = datetime.utcnow()
    db.session.commit()
    log_action("admin", current_user_id(), "removed_hospital", f"hospital_id={hospital_id}")
    return jsonify({"message": "Hospital removed"}), 200


@admin_bp.get("/audit-logs")
@role_required("admin")
def audit_logs():
    logs = AuditLog.query.order_by(AuditLog.created_at.desc()).limit(200).all()
    return jsonify([l.to_dict() for l in logs]), 200


@admin_bp.get("/inventory")
@role_required("admin")
def inventory_overview():
    """Count available, eligible and location-sharing donors by city and group."""
    committed_donors = {
        donor_id
        for (donor_id,) in db.session.query(RequestMatch.donor_id)
        .filter(RequestMatch.status == "accepted")
        .distinct()
        .all()
    }
    donors = Donor.query.filter(
        Donor.is_active.is_(True),
        Donor.is_available.is_(True),
        Donor.location_sharing_enabled.is_(True),
    ).all()
    counts = {}
    for d in donors:
        if d.id in committed_donors or not d.is_eligible_now():
            continue
        city = (d.city or "").strip() or "Location not set"
        city_counts = counts.setdefault(city, {"total": 0})
        city_counts[d.blood_group] = city_counts.get(d.blood_group, 0) + 1
        city_counts["total"] += 1
    return jsonify(counts), 200


@admin_bp.get("/stats")
@role_required("admin")
def dashboard_stats():
    return jsonify({
        "total_donors": Donor.query.filter_by(is_active=True).count(),
        "total_hospitals": Hospital.query.filter_by(is_active=True).count(),
        "open_requests": BloodRequest.query.filter_by(status="open").count(),
        "fulfilled_requests": BloodRequest.query.filter_by(status="fulfilled").count(),
    }), 200


@admin_bp.get("/fulfilled-donations")
@role_required("admin")
def list_fulfilled_donations():
    """List all fulfilled blood requests and completed donation matches/certificates."""
    fulfilled_requests = (
        BloodRequest.query.filter_by(status="fulfilled")
        .order_by(BloodRequest.created_at.desc())
        .all()
    )

    certificates = (
        DonationCertificate.query.order_by(DonationCertificate.donation_date.desc()).all()
    )

    completed_matches = (
        RequestMatch.query.filter_by(status="completed")
        .order_by(RequestMatch.responded_at.desc())
        .all()
    )
    certificates_by_match = {
        certificate.match_id: certificate
        for certificate in certificates
        if certificate.match_id is not None
    }
    completed_donations = []
    for match in completed_matches:
        certificate = certificates_by_match.get(match.id)
        donor = match.donor
        request = match.request
        completed_donations.append({
            "match_id": match.id,
            "request_id": match.request_id,
            "patient_name": request.patient_name if request else None,
            "donor_id": donor.id if donor else match.donor_id,
            "donor_name": donor.full_name if donor else "Donor",
            "blood_group": donor.blood_group if donor else "Unknown",
            "hospital_name": (
                certificate.hospital_name if certificate
                else request.hospital.name if request and request.hospital
                else "Hospital"
            ),
            "donation_date": (
                certificate.donation_date.isoformat() if certificate
                else match.responded_at.isoformat() if match.responded_at
                else match.dispatched_at.isoformat()
            ),
            "units_donated": certificate.units_donated if certificate else 1,
        })

    fulfilled_request_rows = []
    for blood_request in fulfilled_requests:
        row = blood_request.to_dict()
        row["approved_units"] = len({
            match.donor_id
            for match in blood_request.matches
            if match.status == "completed"
        })
        fulfilled_request_rows.append(row)

    return jsonify({
        "total_fulfilled_requests": len(fulfilled_requests),
        "total_completed_donations": len(completed_matches),
        "total_fulfilled_units": sum((r.units_needed or 0) for r in fulfilled_requests),
        "fulfilled_requests": fulfilled_request_rows,
        "certificates": [certificate.to_dict() for certificate in certificates],
        "completed_matches": [match.to_dict() for match in completed_matches],
        "completed_donations": completed_donations,
    }), 200


@admin_bp.post("/bulk-users")
@role_required("admin")
def bulk_add_users():
    """Bulk import donors and hospitals via JSON payload with default password User@123."""
    data = request.get_json(force=True) or {}
    donors_data = data.get("donors", [])
    hospitals_data = data.get("hospitals", [])

    created_donors = []
    created_hospitals = []
    errors = []

    for idx, d in enumerate(donors_data):
        row_num = idx + 1
        name = (d.get("full_name") or d.get("name") or "").strip()
        phone_raw = str(d.get("phone") or "").strip()
        blood_group = (d.get("blood_group") or "").strip().upper()
        city = (d.get("city") or "").strip()
        age_raw = d.get("age", 25)
        password = str(d.get("password") or "User@123").strip()
        latitude = d.get("latitude")
        longitude = d.get("longitude")

        if not name or not phone_raw or not blood_group:
            errors.append(f"Donor row {row_num}: missing name, phone, or blood group")
            continue

        phone = normalize_phone(phone_raw)
        if len(phone) != 10:
            errors.append(f"Donor row {row_num} ({name}): phone must be 10 digits")
            continue

        if blood_group not in BLOOD_GROUPS:
            errors.append(f"Donor row {row_num} ({name}): invalid blood group '{blood_group}'")
            continue

        if Donor.query.filter_by(phone=phone).first():
            errors.append(f"Donor row {row_num} ({name}): phone {phone} already registered")
            continue

        try:
            age = int(age_raw)
        except (ValueError, TypeError):
            age = 25

        try:
            latitude = float(latitude) if latitude not in (None, "") else None
            longitude = float(longitude) if longitude not in (None, "") else None
        except (TypeError, ValueError):
            errors.append(f"Donor row {row_num} ({name}): latitude and longitude must be numeric")
            continue
        if ((latitude is None) != (longitude is None)
                or (latitude is not None and not -90 <= latitude <= 90)
                or (longitude is not None and not -180 <= longitude <= 180)):
            errors.append(f"Donor row {row_num} ({name}): provide a valid latitude and longitude pair")
            continue
        if latitude is None and city:
            location = geocode_address(city, current_app.config.get("GOOGLE_MAPS_API_KEY"))
            latitude = location.get("latitude")
            longitude = location.get("longitude")

        donor = Donor(
            full_name=name,
            phone=phone,
            blood_group=blood_group,
            age=age,
            city=city,
            latitude=latitude,
            longitude=longitude,
            fallback_latitude=latitude,
            fallback_longitude=longitude,
            location_source="registered_area" if latitude is not None else "unresolved",
            password_hash=bcrypt.generate_password_hash(password).decode("utf-8"),
            must_change_password=True,
            is_active=True,
            # Imported accounts must opt in with a shared GPS/test pin before
            # appearing as available to hospitals or in live inventory.
            is_available=False,
        )
        db.session.add(donor)
        created_donors.append(name)

    for idx, h in enumerate(hospitals_data):
        row_num = idx + 1
        name = (h.get("name") or "").strip()
        reg = (h.get("registration_number") or h.get("reg_no") or "").strip()
        phone_raw = str(h.get("phone") or "").strip()
        city = (h.get("city") or "").strip()
        address = (h.get("address") or city or "").strip()
        password = str(h.get("password") or "User@123").strip()
        latitude = h.get("latitude")
        longitude = h.get("longitude")

        if not name or not phone_raw:
            errors.append(f"Hospital row {row_num}: missing name or phone")
            continue

        phone = normalize_phone(phone_raw)
        if len(phone) != 10:
            errors.append(f"Hospital row {row_num} ({name}): phone must be 10 digits")
            continue

        if not reg:
            reg = f"REG-{phone[-6:]}"

        if Hospital.query.filter_by(phone=phone).first():
            errors.append(f"Hospital row {row_num} ({name}): phone {phone} already registered")
            continue

        if Hospital.query.filter_by(registration_number=reg).first():
            reg = f"{reg}-{secrets.token_hex(2)}"

        try:
            latitude = float(latitude) if latitude not in (None, "") else None
            longitude = float(longitude) if longitude not in (None, "") else None
        except (TypeError, ValueError):
            errors.append(f"Hospital row {row_num} ({name}): latitude and longitude must be numeric")
            continue
        if ((latitude is None) != (longitude is None)
                or (latitude is not None and not -90 <= latitude <= 90)
                or (longitude is not None and not -180 <= longitude <= 180)):
            errors.append(f"Hospital row {row_num} ({name}): provide a valid latitude and longitude pair")
            continue
        location = None
        if latitude is None and (city or address):
            location = geocode_address(city or address, current_app.config.get("GOOGLE_MAPS_API_KEY"))
            latitude = location.get("latitude")
            longitude = location.get("longitude")

        hospital = Hospital(
            name=name,
            registration_number=reg,
            phone=phone,
            city=city,
            address=address,
            latitude=latitude,
            longitude=longitude,
            fallback_latitude=latitude,
            fallback_longitude=longitude,
            location_source="registered_area" if latitude is not None else "unresolved",
            password_hash=bcrypt.generate_password_hash(password).decode("utf-8"),
            must_change_password=True,
            is_verified=True,
            is_active=True,
        )
        db.session.add(hospital)
        created_hospitals.append(name)

    if created_donors or created_hospitals:
        db.session.commit()
        log_action(
            "admin",
            current_user_id(),
            "bulk_created_users",
            f"donors={len(created_donors)}, hospitals={len(created_hospitals)}",
        )

    return jsonify({
        "created_donors_count": len(created_donors),
        "created_hospitals_count": len(created_hospitals),
        "created_donors": created_donors,
        "created_hospitals": created_hospitals,
        "errors": errors,
        "default_password": "User@123",
    }), 201
