import unittest
from datetime import datetime, timedelta

from models import Donor
from utils.ai_matching import rank_donors_for_request, score_donor


def make_donor(
    name,
    blood_group,
    latitude,
    longitude,
    *,
    available=True,
    active=True,
    last_donation_date=None,
):
    return Donor(
        full_name=name,
        phone="1234567890",
        password_hash="test-hash",
        blood_group=blood_group,
        age=30,
        is_active=active,
        is_available=available,
        location_sharing_enabled=available,
        gps_latitude=latitude,
        gps_longitude=longitude,
        reliability_score=80,
        total_donations=1,
        last_donation_date=last_donation_date,
    )


class DonorMatchingTests(unittest.TestCase):
    def test_ranks_nearer_compatible_donor_first_and_excludes_incompatible(self):
        nearby = make_donor("Nearby", "O+", 12.9717, 77.5946)
        farther = make_donor("Farther", "O-", 12.9800, 77.5946)
        incompatible = make_donor("Incompatible", "A+", 12.9716, 77.5946)

        ranked = rank_donors_for_request(
            [farther, incompatible, nearby],
            "O+",
            12.9716,
            77.5946,
        )

        self.assertEqual([item["donor"].full_name for item in ranked], ["Nearby", "Farther"])
        self.assertGreater(ranked[0]["score"], ranked[1]["score"])
        self.assertGreater(ranked[0]["distance_km"], 0)

    def test_excludes_unavailable_inactive_ineligible_and_out_of_range_donors(self):
        unavailable = make_donor("Unavailable", "O+", 12.9716, 77.5946, available=False)
        inactive = make_donor("Inactive", "O+", 12.9716, 77.5946, active=False)
        ineligible = make_donor(
            "Ineligible",
            "O+",
            12.9716,
            77.5946,
            last_donation_date=datetime.utcnow() - timedelta(days=30),
        )
        too_far = make_donor("Too Far", "O+", 13.9716, 77.5946)

        ranked = rank_donors_for_request(
            [unavailable, inactive, ineligible, too_far],
            "O+",
            12.9716,
            77.5946,
            max_distance_km=50,
        )

        self.assertEqual(ranked, [])

    def test_unknown_location_receives_score_without_fabricated_distance(self):
        donor = make_donor("No GPS", "O+", None, None)

        score, distance = score_donor(donor, 12.9716, 77.5946)

        self.assertIsNotNone(score)
        self.assertIsNone(distance)


if __name__ == "__main__":
    unittest.main()
