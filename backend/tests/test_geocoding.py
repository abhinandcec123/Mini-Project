import unittest

from models import Donor
from utils.ai_matching import score_donor
from utils.geocoding import geocode_address


class GeocodingAccuracyTests(unittest.TestCase):
    def test_missing_api_key_does_not_create_fake_map_coordinates(self):
        location = geocode_address("Some address", None)

        self.assertIsNone(location["latitude"])
        self.assertIsNone(location["longitude"])
        self.assertEqual(location["location_source"], "unresolved")

    def test_nearby_distance_keeps_sub_hundred_meter_precision(self):
        donor = Donor(
            is_active=True,
            is_available=True,
            location_sharing_enabled=True,
            gps_latitude=0,
            gps_longitude=0.00001,
            reliability_score=80,
            total_donations=0,
        )

        _, distance = score_donor(donor, 0, 0)

        self.assertGreater(distance, 0)
        self.assertLess(distance, 0.01)


if __name__ == "__main__":
    unittest.main()
