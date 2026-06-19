import hashlib
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from generate_release_checksums import release_checksums


SCRIPT_PATH = Path(__file__).with_name("generate_release_checksums.py")


class GenerateReleaseChecksumsTest(unittest.TestCase):
  def test_release_checksums_sorts_assets_by_name(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      temp_path = Path(temp_dir)
      dmg = temp_path / "supaterm.dmg"
      zip_path = temp_path / "supaterm.app.zip"
      dmg.write_bytes(b"dmg")
      zip_path.write_bytes(b"zip")

      manifest = release_checksums("v26.0.0", [zip_path, dmg])

      self.assertEqual(list(manifest["assets"]), ["supaterm.app.zip", "supaterm.dmg"])
      self.assertEqual(manifest["tag"], "v26.0.0")
      self.assertEqual(
        manifest["assets"]["supaterm.dmg"],
        {
          "sha256": hashlib.sha256(b"dmg").hexdigest(),
          "size": 3,
        },
      )

  def test_command_writes_checksum_manifest(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      temp_path = Path(temp_dir)
      dmg = temp_path / "supaterm.dmg"
      output = temp_path / "checksums.json"
      dmg.write_bytes(b"dmg")

      subprocess.run(["python3", str(SCRIPT_PATH), "tip", str(output), str(dmg)], check=True)

      self.assertEqual(
        json.loads(output.read_text(encoding="utf-8")),
        {
          "assets": {
            "supaterm.dmg": {
              "sha256": hashlib.sha256(b"dmg").hexdigest(),
              "size": 3,
            },
          },
          "tag": "tip",
        },
      )

  def test_missing_assets_fail(self) -> None:
    with tempfile.TemporaryDirectory() as temp_dir:
      with self.assertRaisesRegex(SystemExit, "asset not found"):
        release_checksums("tip", [Path(temp_dir) / "missing.dmg"])


if __name__ == "__main__":
  unittest.main()
