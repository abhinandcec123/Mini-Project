"""Run once after setting up the database to create the first admin account:

    python seed.py
"""
from app import create_app
from extensions import db, bcrypt
from models import Admin

app = create_app()

with app.app_context():
    existing = Admin.query.filter_by(email="admin@lifepulse.ai").first()
    if existing:
        print("Default admin already exists (admin@lifepulse.ai)")
    else:
        admin = Admin(
            full_name="LifePulse Admin",
            email="admin@lifepulse.ai",
            password_hash=bcrypt.generate_password_hash("Admin@123").decode("utf-8"),
        )
        db.session.add(admin)
        db.session.commit()
        print("Created default admin -> email: admin@lifepulse.ai  password: Admin@123")
        print("IMPORTANT: log in and change this password immediately.")
