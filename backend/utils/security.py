from functools import wraps
from flask import jsonify
from flask_jwt_extended import create_access_token, verify_jwt_in_request, get_jwt, get_jwt_identity


def make_token(identity: str, role: str):
    return create_access_token(identity=identity, additional_claims={"role": role})


def role_required(role: str):
    """Decorator: requires a valid JWT whose 'role' claim matches `role`."""

    def decorator(fn):
        @wraps(fn)
        def wrapper(*args, **kwargs):
            verify_jwt_in_request()
            claims = get_jwt()
            if claims.get("role") != role:
                return jsonify({"error": "Forbidden: wrong account type for this action"}), 403
            return fn(*args, **kwargs)

        return wrapper

    return decorator


def current_user_id() -> int:
    return int(get_jwt_identity())
