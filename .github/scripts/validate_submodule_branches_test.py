import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT_PATH = Path(__file__).with_name("validate_submodule_branches.py")
ZERO_OBJECT_NAME = "0" * 40


class ValidateSubmoduleBranchesTest(unittest.TestCase):
  def setUp(self) -> None:
    self.temporary_directory = tempfile.TemporaryDirectory()
    self.root = Path(self.temporary_directory.name)
    self.dependency = self.root / "dependency"
    self.repository = self.root / "repository"
    self._init_repository(self.dependency)
    self._write(self.dependency / "value", "base\n")
    self.base = self._commit(self.dependency, "base")
    self._write(self.dependency / "value", "main\n")
    self.main = self._commit(self.dependency, "main")
    self._git(self.dependency, "switch", "-c", "other", self.base)
    self._write(self.dependency / "value", "other\n")
    self.other = self._commit(self.dependency, "other")
    self._git(self.dependency, "switch", "main")

  def tearDown(self) -> None:
    self.temporary_directory.cleanup()

  def test_accepts_pin_reachable_from_required_branch(self) -> None:
    revision = self._create_parent(self.base)

    result = self._validate(revision, "refs/heads/main")

    self.assertEqual(result.returncode, 0, result.stderr)

  def test_rejects_pin_from_another_branch(self) -> None:
    revision = self._create_parent(self.other)

    result = self._validate(revision, "refs/heads/main")

    self.assertNotEqual(result.returncode, 0)
    self.assertIn("vendor/dependency", result.stderr)
    self.assertIn(self.other, result.stderr)
    self.assertIn("main", result.stderr)

  def test_skips_pushes_that_do_not_update_main(self) -> None:
    revision = self._create_parent(self.other)

    result = self._validate(revision, "refs/heads/topic")

    self.assertEqual(result.returncode, 0, result.stderr)

  def _create_parent(self, pin: str) -> str:
    self._init_repository(self.repository)
    clone = self.repository / "vendor/dependency"
    clone.parent.mkdir(parents=True)
    self._git(self.repository, "clone", "--quiet", str(self.dependency), str(clone))
    self._write(
      self.repository / ".gitmodules",
      "\n".join(
        [
          '[submodule "dependency"]',
          "\tpath = vendor/dependency",
          f"\turl = {self.dependency}",
          "\tbranch = main",
          "",
        ]
      ),
    )
    self._git(self.repository, "add", ".gitmodules")
    self._git(
      self.repository,
      "update-index",
      "--add",
      "--cacheinfo",
      f"160000,{pin},vendor/dependency",
    )
    self._git(self.repository, "commit", "--quiet", "--message", "parent")
    return self._git(self.repository, "rev-parse", "HEAD").stdout.strip()

  def _validate(self, revision: str, remote_ref: str) -> subprocess.CompletedProcess[str]:
    update = f"refs/heads/main {revision} {remote_ref} {ZERO_OBJECT_NAME}\n"
    return subprocess.run(
      ["python3", str(SCRIPT_PATH), "--repo", str(self.repository)],
      input=update,
      text=True,
      capture_output=True,
      check=False,
    )

  def _init_repository(self, repository: Path) -> None:
    repository.mkdir()
    self._git(repository, "init", "--quiet", "--initial-branch", "main")
    self._git(repository, "config", "user.name", "Test")
    self._git(repository, "config", "user.email", "test@example.com")

  def _commit(self, repository: Path, message: str) -> str:
    self._git(repository, "add", "--all")
    self._git(repository, "commit", "--quiet", "--message", message)
    return self._git(repository, "rev-parse", "HEAD").stdout.strip()

  def _git(self, repository: Path, *arguments: str) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
      ["git", *arguments],
      cwd=repository,
      text=True,
      capture_output=True,
      check=True,
    )

  def _write(self, path: Path, content: str) -> None:
    path.write_text(content, encoding="utf-8")


if __name__ == "__main__":
  unittest.main()
