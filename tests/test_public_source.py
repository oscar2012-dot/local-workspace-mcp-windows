import importlib.util
from pathlib import Path
import unittest


SPEC = importlib.util.spec_from_file_location("public_check", Path(__file__).resolve().parents[1] / "scripts/check_public_source.py")
check = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check)


class PublicSourceTests(unittest.TestCase):
    def test_clean_source(self):
        self.assertEqual([], check.check_content("README.md", b"Use a dedicated workspace."))

    def test_key_not_printed(self):
        secret = "sk-" + "x" * 40
        findings = check.check_content("README.md", secret.encode())
        self.assertTrue(any("API credential" in item for item in findings))
        self.assertNotIn(secret, str(findings))

    def test_tunnel_id(self):
        value = "tunnel_" + "a" * 32
        self.assertTrue(check.check_content("README.md", value.encode()))

    def test_user_paths(self):
        for value in ("C:" + "\\Users\\" + "example\\workspace", "/home/" + "example/workspace"):
            self.assertTrue(check.check_content("README.md", value.encode()))

    def test_placeholder_paths(self):
        self.assertEqual([], check.check_content("README.md", b"/home/<user>/workspace"))

    def test_email(self):
        self.assertTrue(check.check_content("README.md", ("person" + "@" + "example.com").encode()))

    def test_private_file(self):
        self.assertTrue(check.check_content("private/config.json", b"{}"))

    def test_binary_and_large(self):
        self.assertTrue(check.check_content("data.zip", b"\x00\xff"))
        self.assertTrue(check.check_content("README.md", b"a" * 1_000_001))


if __name__ == "__main__":
    unittest.main()
