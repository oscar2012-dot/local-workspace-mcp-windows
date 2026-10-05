"""Offline checks for the public beginner-facing documentation."""
from pathlib import Path
import re
import unittest
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]


class DocumentationTests(unittest.TestCase):
    def test_relative_links_exist_and_stay_in_repository(self):
        documents = [*ROOT.glob("*.md"), *ROOT.joinpath("docs").glob("*.md")]
        for document in documents:
            text = document.read_text(encoding="utf-8-sig")
            for raw in re.findall(r"\]\(([^)]+)\)", text):
                target = raw.strip("<>").split(' "', 1)[0]
                parsed = urlsplit(target)
                if parsed.scheme or parsed.netloc or not parsed.path:
                    continue
                with self.subTest(file=document.name, target=target):
                    resolved = (document.parent / unquote(parsed.path)).resolve()
                    self.assertTrue(resolved.is_relative_to(ROOT))
                    self.assertTrue(resolved.is_file(), target)

    def test_beginner_guides_are_linked_and_bilingual(self):
        for readme, guide in (("README.md", "docs/INSTALL.md"),
                              ("README.en.md", "docs/INSTALL.en.md")):
            with self.subTest(readme=readme):
                content = (ROOT / readme).read_text(encoding="utf-8-sig")
                self.assertIn(guide, content)
                self.assertIn("Setup.cmd", content)
                instructions = (ROOT / guide).read_text(encoding="utf-8-sig")
                for marker in ("Setup.cmd", "LOCAL_INSTALL_READY=PASS",
                               "CHATGPT_CONNECTION=NOT_CONFIGURED"):
                    self.assertIn(marker, instructions)

    def test_real_chatgpt_test_is_separate_from_local_readiness(self):
        for filename in ("docs/CHATGPT.md", "docs/CHATGPT.en.md"):
            with self.subTest(filename=filename):
                content = (ROOT / filename).read_text(encoding="utf-8-sig")
                self.assertIn("WINDOWS_TUNNEL_READY=PASS", content)
                self.assertIn("hello.txt", content)


if __name__ == "__main__":
    unittest.main()
