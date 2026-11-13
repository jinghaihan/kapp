import unittest
from release import bump_version


class ReleaseVersionTests(unittest.TestCase):
    def test_bumps_reset_lower_components(self):
        self.assertEqual(bump_version("1.2.3", "patch"), "1.2.4")
        self.assertEqual(bump_version("1.2.3", "minor"), "1.3.0")
        self.assertEqual(bump_version("1.2.3", "major"), "2.0.0")

    def test_rejects_unexpected_version_formats(self):
        for version in ["v1.2.3", "1.2", "1.2.3-beta.1"]:
            with self.assertRaises(ValueError):
                bump_version(version, "patch")
