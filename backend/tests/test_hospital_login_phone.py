import unittest

from app import create_app
from extensions import bcrypt, db
from models import Hospital
from db_config import TEST_DATABASE_URI


class HospitalLoginPhoneTests(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            "TESTING": True,
            "SQLALCHEMY_DATABASE_URI": TEST_DATABASE_URI,
            "JWT_SECRET_KEY": "test-secret-key-with-at-least-32-bytes",
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            hospital = Hospital(
                name="Test Hospital",
                registration_number="TEST-001",
                phone="1234567890",
                password_hash=bcrypt.generate_password_hash("hospital-password").decode(),
            )
            db.session.add(hospital)
            db.session.commit()

    def tearDown(self):
        with self.app.app_context():
            db.session.remove()
            db.drop_all()

    def test_hospital_login_accepts_exactly_ten_digits(self):
        response = self.client.post("/api/auth/hospital/login", json={
            "phone": "1234567890",
            "password": "hospital-password",
        })
        self.assertEqual(response.status_code, 200)

    def test_hospital_login_rejects_short_or_long_numbers(self):
        for phone in ("123456789", "12345678901"):
            with self.subTest(phone=phone):
                response = self.client.post("/api/auth/hospital/login", json={
                    "phone": phone,
                    "password": "hospital-password",
                })
                self.assertEqual(response.status_code, 400)


if __name__ == "__main__":
    unittest.main()
