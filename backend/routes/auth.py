from flask import Blueprint, request, jsonify, current_app
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
    try:
        location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))
    except GeocodingError as error:
        return jsonify({"error": str(error)}), error.status_code

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
        city=location["city"],
    )
    db.session.add(donor)
    db.session.commit()
    log_action("donor", donor.id, "signup")

    token = make_token(str(donor.id), "donor")
    return jsonify({"token": token, "role": "donor", "user": donor.to_dict()}), 201


@auth_bp.post("/donor/login")
def donor_login():
    data = request.get_json(force=True)
    phone = normalize_phone(data.get("phone", ""))
    donor = Donor.query.filter_by(phone=phone).first()
    if not donor or not bcrypt.check_password_hash(donor.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid phone number or password"}), 401
    if not donor.is_active:
        return jsonify({"error": "This account has been deactivated by an admin"}), 403

    token = make_token(str(donor.id), "donor")
    return jsonify({"token": token, "role": "donor", "user": donor.to_dict()}), 200


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
    try:
        location = geocode_address(address, current_app.config.get("GOOGLE_MAPS_API_KEY"))
    except GeocodingError as error:
        return jsonify({"error": str(error)}), error.status_code

    hospital = Hospital(
        name=data["name"].strip(),
        registration_number=data["registration_number"].strip(),
        phone=phone,
        email=data.get("email"),
        password_hash=bcrypt.generate_password_hash(data["password"]).decode("utf-8"),
        address=address,
        city=location["city"],
        latitude=location["latitude"],
        longitude=location["longitude"],
    )
    db.session.add(hospital)
    db.session.commit()
    log_action("hospital", hospital.id, "signup")

    token = make_token(str(hospital.id), "hospital")
    return jsonify({"token": token, "role": "hospital", "user": hospital.to_dict()}), 201


@auth_bp.post("/hospital/login")
def hospital_login():
    data = request.get_json(force=True)
    phone = normalize_phone(data.get("phone", ""))
    hospital = Hospital.query.filter_by(phone=phone).first()
    if not hospital or not bcrypt.check_password_hash(hospital.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid phone number or password"}), 401
    if not hospital.is_active:
        return jsonify({"error": "This account has been deactivated by an admin"}), 403

    token = make_token(str(hospital.id), "hospital")
    return jsonify({"token": token, "role": "hospital", "user": hospital.to_dict()}), 200


@auth_bp.post("/admin/login")
def admin_login():
    data = request.get_json(force=True)
    email = (data.get("email") or "").strip().lower()
    admin = Admin.query.filter_by(email=email).first()
    if not admin or not bcrypt.check_password_hash(admin.password_hash, data.get("password", "")):
        return jsonify({"error": "Invalid email or password"}), 401

    token = make_token(str(admin.id), "admin")
    return jsonify({"token": token, "role": "admin", "user": admin.to_dict()}), 200
