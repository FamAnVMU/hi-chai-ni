import os
import ssl
import sys
import tempfile
from pathlib import Path
import unittest
import urllib.error

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent / "data_pipeline"))
import pipeline_config


class TestDataPipelineSecurityAndPortability(unittest.TestCase):

    def test_no_cert_none_in_pipeline(self):
        pipeline_dir = Path(__file__).resolve().parent.parent.parent / "data_pipeline"
        violations = []
        for py_file in pipeline_dir.glob("*.py"):
            content = py_file.read_text(encoding="utf-8")
            if "CERT_NONE" in content:
                violations.append(f"{py_file.name}: contains CERT_NONE")
            if "verify=False" in content:
                violations.append(f"{py_file.name}: contains verify=False")
            if "_create_unverified_context" in content:
                violations.append(f"{py_file.name}: contains _create_unverified_context")

        self.assertEqual(violations, [], f"Found SSL verification bypasses: {violations}")

    def test_no_hardcoded_machine_specific_paths(self):
        pipeline_dir = Path(__file__).resolve().parent.parent.parent / "data_pipeline"
        violations = []
        forbidden_patterns = [r"C:\Users", r"c:\users", r"C:/Users", r"/Users/"]
        for py_file in pipeline_dir.glob("*.py"):
            content = py_file.read_text(encoding="utf-8")
            for pat in forbidden_patterns:
                if pat.lower() in content.lower():
                    violations.append(f"{py_file.name}: contains machine-specific path pattern '{pat}'")

        self.assertEqual(violations, [], f"Found machine-specific paths: {violations}")

    def test_project_root_detection(self):
        expected_root = Path(__file__).resolve().parent.parent.parent
        detected_root = pipeline_config.get_project_root()
        self.assertEqual(detected_root, expected_root)
        self.assertTrue((detected_root / "pubspec.yaml").exists())

    def test_env_var_override_project_root(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            os.environ["HI_CHINESE_PROJECT_ROOT"] = tmpdir
            try:
                root = pipeline_config.get_project_root()
                self.assertEqual(root, Path(tmpdir).resolve())
            finally:
                del os.environ["HI_CHINESE_PROJECT_ROOT"]

    def test_env_var_override_directories(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            custom_raw = Path(tmpdir) / "custom_raw"
            os.environ["HI_CHINESE_RAW_DIR"] = str(custom_raw)
            try:
                raw_dir = pipeline_config.get_raw_dir("test_cat")
                self.assertEqual(raw_dir, custom_raw / "test_cat")
                self.assertTrue(raw_dir.exists())
            finally:
                del os.environ["HI_CHINESE_RAW_DIR"]

    def test_secure_ssl_context_enforces_verification(self):
        ctx = pipeline_config.get_secure_ssl_context()
        self.assertEqual(ctx.verify_mode, ssl.CERT_REQUIRED)
        self.assertTrue(ctx.check_hostname)

    def test_bad_ssl_cert_is_rejected(self):
        url = "https://self-signed.badssl.com/"
        with self.assertRaises((urllib.error.URLError, ssl.SSLError)):
            pipeline_config.secure_open_url(url, timeout=5)

    def test_valid_https_works_with_verification(self):
        url = "https://raw.githubusercontent.com/krmanik/Chinese-Grammar/master/README.md"
        with pipeline_config.secure_open_url(url, timeout=10) as resp:
            self.assertEqual(resp.status, 200)
            data = resp.read()
            self.assertGreater(len(data), 0)

    def test_chinese_unicode_handling(self):
        with tempfile.TemporaryDirectory() as tmpdir:
            test_file = Path(tmpdir) / "test_hanzi_汉字.json"
            payload = {"hsk": 1, "character": "你好世界", "pinyin": "nǐ hǎo shì jiè"}
            test_file.write_text(pipeline_config.json.dumps(payload, ensure_ascii=False), encoding="utf-8")

            read_back = pipeline_config.json.loads(test_file.read_text(encoding="utf-8"))
            self.assertEqual(read_back["character"], "你好世界")
            self.assertEqual(read_back["pinyin"], "nǐ hǎo shì jiè")


if __name__ == "__main__":
    unittest.main()
