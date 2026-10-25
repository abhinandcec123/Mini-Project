from functools import wraps
from flask import jsonify
from flask_jwt_extended import create_access_token, verify_jwt_in_request, get_jwt, get_jwt_identity
from extensions import db


def make_token(identity: str, role: str, password_version: int = 0):
    return create_access_token(
        identity=identity,
        additional_claims={"role": role, "password_version": password_version},
    )


def role_required(role: str):
    """Decorator: requires a valid JWT whose 'role' claim matches `role`."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            if claims.get("role") != role:
                return jsonify({"error": "Forbidden: wrong account type for this action"}), 403
            from models import Donor, Hospital, Admin

            account_model = {"donor": Donor, "hospital": Hospital, "admin": Admin}[role]
            account = db.session.get(account_model, int(get_jwt_identity()))
            if not account:
                return jsonify({"error": "Account not found"}), 401
            if not getattr(account, "is_active", True):
                return jsonify({"error": "This account has been deactivated by an admin"}), 403
            if claims.get("password_version", 0) != getattr(account, "password_version", 0):
                return jsonify({"error": "Session expired. Please sign in again."}), 401
            if getattr(account, "must_change_password", False):
                return jsonify({
                    "error": "Change your temporary password before continuing.",
                    "password_change_required": True,
                }), 403
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def current_user_id() -> int:
    return int(get_jwt_identity())
