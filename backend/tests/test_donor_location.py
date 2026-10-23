import unittest

from models import Donor


class DonorLocationPrivacyTests(unittest.TestCase):
    def setUp(self):
        self.donor = Donor(
            id=1,
            full_name="Test Donor",
            phone="1234567890",
            password_hash="not-a-real-password",
            blood_group="O+",
            age=30,
            latitude=10.0,
            longitude=20.0,
            fallback_latitude=10.1,
            fallback_longitude=20.1,
            gps_latitude=10.2,
            gps_longitude=20.2,
            gps_accuracy_m=8.0,
            location_sharing_enabled=False,
            is_available=False,
            is_active=True,
        )

    def test_private_or_unavailable_donor_has_no_shared_pin(self):
        data = self.donor.to_dict(include_contact=False)

        self.assertIsNone(data["latitude"])
        self.assertIsNone(data["longitude"])
        self.assertIsNone(data["fallback_latitude"])
        self.assertIsNone(data["effective_latitude"])
        self.assertFalse(data["location_sharing_enabled"])

    def test_available_opted_in_donor_shares_only_current_gps_pin(self):
        self.donor.is_available = True
        self.donor.location_sharing_enabled = True

        data = self.donor.to_dict(include_contact=False)

        self.assertEqual(data["latitude"], 10.2)
        self.assertEqual(data["longitude"], 20.2)
        self.assertIsNone(data["fallback_latitude"])
        self.assertEqual(data["location_accuracy_m"], 8.0)
        self.assertTrue(data["location_sharing_enabled"])

    def test_turning_availability_off_hides_gps_even_if_stale_consent_remains(self):
        self.donor.location_sharing_enabled = True
        self.donor.is_available = False

        data = self.donor.to_dict(include_contact=False)

        self.assertIsNone(data["latitude"])
        self.assertIsNone(data["longitude"])
        self.assertFalse(data["location_sharing_enabled"])


if __name__ == "__main__":
    unittest.main()
