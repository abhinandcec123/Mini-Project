from flask import Blueprint, request, jsonify, current_app
from extensions import db, bcrypt
from models import Donor, Hospital, BloodRequest, AuditLog, log_action, normalize_phone
from utils.geocoding import GeocodingError, geocode_address
from utils.security import role_required, current_user_id

admin_bp = Blueprint("admin", __name__, url_prefix="/api/admin")


@admin_bp.get("/donors")
@role_required("admin")
def list_donors():
    donors = Donor.query.order_by(Donor.created_at.desc()).all()
    return jsonify([d.to_dict() for d in donors]), 200


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

    if address and not skip_geocoding:
        try:
            location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))
            latitude = latitude if latitude is not None else location["latitude"]
            longitude = longitude if longitude is not None else location["longitude"]
            city = city or location.get("city") or ""
        except GeocodingError as error:
            if current_app.config.get("GOOGLE_MAPS_API_KEY"):
                return jsonify({"error": str(error)}), error.status_code
            # Admin override: allow manual registration when no Maps key is configured.
            latitude = latitude
            longitude = longitude

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
    hospitals = Hospital.query.order_by(Hospital.created_at.desc()).all()
    return jsonify([h.to_dict() for h in hospitals]), 200


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
    donor.is_active = False  # soft delete: preserves donation history & audit trail
    db.session.commit()
    log_action("admin", current_user_id(), "removed_donor", f"donor_id={donor_id}")
    return jsonify({"message": "Donor removed"}), 200


@admin_bp.delete("/hospitals/<int:hospital_id>")
@role_required("admin")
def remove_hospital(hospital_id):
    hospital = Hospital.query.get(hospital_id)
    if not hospital:
        return jsonify({"error": "Hospital not found"}), 404
    hospital.is_active = False
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
    """Aggregate reserve view: available eligible donor counts per blood group."""
    donors = Donor.query.filter_by(is_active=True, is_available=True).all()
    counts = {}
    for d in donors:
        if d.is_eligible_now():
            counts[d.blood_group] = counts.get(d.blood_group, 0) + 1
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
