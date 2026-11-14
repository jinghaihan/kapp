import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from appcast import generate_feed


class AppcastTests(unittest.TestCase):
    def generate(self, version="0.2.0", signature="signed", length="7", url=None):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / "Kapp-0.2.0-macos-universal.zip"
            archive.write_bytes(b"archive")
            notes = Path(temporary) / "notes.md"
            notes.write_text("## Changes\n- New feature\n")
            expected_url = "https://github.com/jinghaihan/kapp/releases/download/v0.2.0/" + archive.name

            def run(command, **kwargs):
                self.assertNotIn("private-key", command)
                self.assertEqual(kwargs["input"], "private-key")
                folder = Path(command[-1])
                self.assertEqual((folder / (archive.stem + ".md")).read_text(), notes.read_text())
                (folder / "appcast.xml").write_text(f'''<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
                    <channel><item><sparkle:version>{version}</sparkle:version>
                    <enclosure sparkle:edSignature="{signature}" length="{length}" url="{url or expected_url}"/>
                    </item></channel></rss>''')

            with patch("appcast.read_version", return_value="0.2.0"), patch("appcast.subprocess.run", side_effect=run):
                return generate_feed(archive, notes, Path("generate_appcast"), "jinghaihan/kapp", "private-key")

    def test_generates_the_signed_release_feed_with_embedded_notes(self):
        self.assertIn(b"releases/download/v0.2.0/", self.generate())

    def test_rejects_a_feed_for_another_version(self):
        with self.assertRaisesRegex(ValueError, "app version"):
            self.generate(version="0.1.0")

    def test_rejects_unsigned_archives(self):
        with self.assertRaisesRegex(ValueError, "signed release archive"):
            self.generate(signature="")

    def test_rejects_a_wrong_download_url_or_file_size(self):
        for options in [{"url": "https://example.com/archive.zip"}, {"length": "6"}]:
            with self.subTest(**options), self.assertRaisesRegex(ValueError, "signed release archive"):
                self.generate(**options)
