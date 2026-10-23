import re
import secrets
import string
from flask import Blueprint, request, jsonify, current_app
from flask_jwt_extended import verify_jwt_in_request, get_jwt, get_jwt_identity
from extensions import db, bcrypt
from models import Donor, Hospital, Admin, normalize_phone, BLOOD_GROUPS, log_action
from utils.security import make_token
from utils.geocoding import GeocodingError, geocode_address

auth_bp = Blueprint("auth", __name__, url_prefix="/api/auth")


@auth_bp.post("/donor/signup")
def donor_signup():
    data = request.get_json(force=True)
    required = ["full_name", "phone", "password", "blood_group", "age", "address"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    if data["blood_group"] not in BLOOD_GROUPS:
        return jsonify({"error": "Invalid blood group"}), 400

    phone = normalize_phone(data["phone"])
    if len(phone) != 10:
        return jsonify({"error": "Enter a valid 10-digit mobile number"}), 400

    if Donor.query.filter_by(phone=phone).first():
        return jsonify({"error": "This mobile number is already registered"}), 409

    address = data["address"].strip()
    if len(address) > 255:
        return jsonify({"error": "Address must be 255 characters or fewer"}), 400
    location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))

    donor = Donor(
        full_name=data["full_name"].strip(),
        phone=phone,
        email=data.get("email"),
        password_hash=bcrypt.generate_password_hash(data["password"]).decode("utf-8"),
        blood_group=data["blood_group"],
        age=int(data["age"]),
        gender=data.get("gender"),
        address=address,
        latitude=location["latitude"],
        longitude=location["longitude"],
        fallback_latitude=location.get("fallback_latitude", location["latitude"]),
        fallback_longitude=location.get("fallback_longitude", location["longitude"]),
        location_source=location.get("location_source", "address"),
        location_accuracy_km=location.get("accuracy_radius_km", 0.0),
        city=location.get("city"),
    )
    db.session.add(donor)
    db.session.commit()
    log_action("donor", donor.id, "signup")

    token = make_token(str(donor.id), "donor", donor.password_version)
    return jsonify({
        "token": token, "role": "donor", "user": donor.to_dict(),
        "password_change_required": donor.must_change_password,
    }), 201


@auth_bp.post("/donor/login")
def donor_login():
    data = request.get_json(force=True)
    phone = normalize_phone(data.get("phone", ""))
    donor = Donor.query.filter_by(phone=phone).first()
    if not donor or not bcrypt.check_password_hash(donor.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid phone number or password"}), 401
    if not donor.is_active:
        return jsonify({"error": "This account has been deactivated by an admin"}), 403

    token = make_token(str(donor.id), "donor", donor.password_version)
    return jsonify({
        "token": token, "role": "donor", "user": donor.to_dict(),
        "password_change_required": donor.must_change_password,
    }), 200


@auth_bp.post("/hospital/signup")
def hospital_signup():
    data = request.get_json(force=True)
    required = ["name", "registration_number", "phone", "password", "address"]
    missing = [f for f in required if not data.get(f)]
    if missing:
        return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400

    phone = normalize_phone(data["phone"])
    if len(phone) != 10:
        return jsonify({"error": "Enter a valid 10-digit mobile number"}), 400

    if Hospital.query.filter_by(phone=phone).first():
        return jsonify({"error": "This mobile number is already registered"}), 409
    if Hospital.query.filter_by(registration_number=data["registration_number"]).first():
        return jsonify({"error": "This registration number is already in use"}), 409

    address = data["address"].strip()
    if len(address) > 255:
        return jsonify({"error": "Address must be 255 characters or fewer"}), 400
    location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))

    hospital = Hospital(
        name=data["name"].strip(),
        registration_number=data["registration_number"].strip(),
        phone=phone,
        email=data.get("email"),
        password_hash=bcrypt.generate_password_hash(data["password"]).decode("utf-8"),
        address=address,
        city=location.get("city"),
        latitude=location["latitude"],
        longitude=location["longitude"],
        fallback_latitude=location.get("fallback_latitude", location["latitude"]),
        fallback_longitude=location.get("fallback_longitude", location["longitude"]),
        location_source=location.get("location_source", "address"),
        location_accuracy_km=location.get("accuracy_radius_km", 0.0),
    )
    db.session.add(hospital)
    db.session.commit()
    log_action("hospital", hospital.id, "signup")

    token = make_token(str(hospital.id), "hospital", hospital.password_version)
    return jsonify({
        "token": token, "role": "hospital", "user": hospital.to_dict(),
        "password_change_required": hospital.must_change_password,
    }), 201


@auth_bp.post("/hospital/login")
def hospital_login():
    data = request.get_json(force=True)
    raw_phone = data.get("phone", "")
    if not isinstance(raw_phone, str) or not re.fullmatch(r"[0-9]{10}", raw_phone):
        return jsonify({"error": "Enter a valid 10-digit mobile number"}), 400
    phone = normalize_phone(raw_phone)
    hospital = Hospital.query.filter_by(phone=phone).first()
    if not hospital or not bcrypt.check_password_hash(hospital.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid phone number or password"}), 401
    if not hospital.is_active:
        return jsonify({"error": "This account has been deactivated by an admin"}), 403

    token = make_token(str(hospital.id), "hospital", hospital.password_version)
    return jsonify({
        "token": token, "role": "hospital", "user": hospital.to_dict(),
        "password_change_required": hospital.must_change_password,
    }), 200


@auth_bp.post("/admin/login")
def admin_login():
    data = request.get_json(force=True)
    email = (data.get("email") or "").strip().lower()
    admin = Admin.query.filter_by(email=email).first()
    if not admin or not bcrypt.check_password_hash(admin.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid email or password"}), 401

    token = make_token(str(admin.id), "admin")
    return jsonify({"token": token, "role": "admin", "user": admin.to_dict()}), 200


@auth_bp.post("/change-password")
def change_password():
    verify_jwt_in_request()
    claims = get_jwt()
    role = claims.get("role")
    account_id = int(get_jwt_identity())
    account_model = {"donor": Donor, "hospital": Hospital}.get(role)
    if not account_model:
        return jsonify({"error": "Unsupported account type"}), 403
    account = db.session.get(account_model, account_id)
    if not account:
        return jsonify({"error": "Account not found"}), 404
    if claims.get("password_version", 0) != getattr(account, "password_version", 0):
        return jsonify({"error": "Session expired. Please sign in again."}), 401

    data = request.get_json(force=True) or {}
    current_password = data.get("current_password", "")
    new_password = data.get("new_password", "")
    if not isinstance(new_password, str) or len(new_password) < 8:
        return jsonify({"error": "New password must be at least 8 characters"}), 400
    if not bcrypt.check_password_hash(account.password_hash, current_password):
        return jsonify({"error": "Current password is incorrect"}), 401
    if current_password == new_password:
        return jsonify({"error": "Choose a password different from the temporary password"}), 400

    account.password_hash = bcrypt.generate_password_hash(new_password).decode("utf-8")
    account.must_change_password = False
    account.password_version = getattr(account, "password_version", 0) + 1
    db.session.commit()
    token = make_token(str(account.id), role, account.password_version)
    user = account.to_dict()
    return jsonify({
        "token": token,
        "role": role,
        "user": user,
        "password_change_required": False,
    }), 200
