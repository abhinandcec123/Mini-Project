from flask import Flask, jsonify
from sqlalchemy import inspect, text
from config import Config
from extensions import db, jwt, bcrypt, cors


def create_app(config_override=None):
    app = Flask(__name__)
    app.config.from_object(Config)
    if config_override:
        app.config.update(config_override)

    db.init_app(app)
    jwt.init_app(app)
    bcrypt.init_app(app)
    cors.init_app(
        app,
        resources={r"/api/*": {"origins": app.config.get("CORS_ORIGINS", "*")}},
    )

    from routes.auth import auth_bp
    from routes.donor import donor_bp
    from routes.hospital import hospital_bp
    from routes.admin import admin_bp

    app.register_blueprint(auth_bp)
    app.register_blueprint(donor_bp)
    app.register_blueprint(hospital_bp)
    app.register_blueprint(admin_bp)

    @app.get("/api/health")
    def health():
        return jsonify({"status": "ok", "service": "LifePulse AI backend"}), 200

    @app.errorhandler(404)
    def not_found(e):
        return jsonify({"error": "Not found"}), 404

    @app.errorhandler(500)
    def server_error(e):
        return jsonify({"error": "Internal server error"}), 500

    with app.app_context():
        db.create_all()
        inspector = inspect(db.engine)
        column_map = {
            "donors": {column["name"] for column in inspector.get_columns("donors")},
            "hospitals": {column["name"] for column in inspector.get_columns("hospitals")},
        }

        for table_name, columns in column_map.items():
            if "fallback_latitude" not in columns:
                db.session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN fallback_latitude FLOAT NULL"))
            if "fallback_longitude" not in columns:
                db.session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN fallback_longitude FLOAT NULL"))
            if "location_source" not in columns:
                db.session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN location_source VARCHAR(30) NULL"))
            if "location_accuracy_km" not in columns:
                db.session.execute(text(f"ALTER TABLE {table_name} ADD COLUMN location_accuracy_km FLOAT NULL"))
        donor_columns = column_map["donors"]
        if "gps_latitude" not in donor_columns:
            db.session.execute(text("ALTER TABLE donors ADD COLUMN gps_latitude FLOAT NULL"))
        if "gps_longitude" not in donor_columns:
            db.session.execute(text("ALTER TABLE donors ADD COLUMN gps_longitude FLOAT NULL"))
        if "gps_accuracy_m" not in donor_columns:
            db.session.execute(text("ALTER TABLE donors ADD COLUMN gps_accuracy_m FLOAT NULL"))
        if "gps_location_source" not in donor_columns:
            db.session.execute(text("ALTER TABLE donors ADD COLUMN gps_location_source VARCHAR(20) NULL"))
        db.session.execute(text(
            "UPDATE donors SET gps_location_source = 'gps' "
            "WHERE gps_location_source IS NULL AND gps_latitude IS NOT NULL "
            "AND gps_longitude IS NOT NULL"
        ))
        if "location_sharing_enabled" not in donor_columns:
            db.session.execute(text(
                "ALTER TABLE donors ADD COLUMN location_sharing_enabled BOOLEAN NOT NULL DEFAULT FALSE"
            ))
        if "gps_accuracy_m" not in column_map["hospitals"]:
            db.session.execute(text("ALTER TABLE hospitals ADD COLUMN gps_accuracy_m FLOAT NULL"))
        for table_name in ("donors", "hospitals"):
            columns = {column["name"] for column in inspect(db.engine).get_columns(table_name)}
            if "must_change_password" not in columns:
                db.session.execute(text(
                    f"ALTER TABLE {table_name} ADD COLUMN must_change_password BOOLEAN NOT NULL DEFAULT FALSE"
                ))
            if "password_version" not in columns:
                db.session.execute(text(
                    f"ALTER TABLE {table_name} ADD COLUMN password_version INTEGER NOT NULL DEFAULT 0"
                ))
        db.session.execute(text(
            "UPDATE donors SET is_available = FALSE WHERE location_sharing_enabled = FALSE"
        ))
        db.session.commit()

    return app


app = create_app()

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=app.config["FLASK_DEBUG"])
