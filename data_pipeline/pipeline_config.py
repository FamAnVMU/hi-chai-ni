import json
import os
from pathlib import Path
import ssl
import sys
import urllib.request


def get_project_root() -> Path:
    env_root = os.getenv("HI_CHINESE_PROJECT_ROOT")
    if env_root:
        candidate = Path(env_root).resolve()
        if candidate.exists() and candidate.is_dir():
            return candidate

    return Path(__file__).resolve().parent.parent


def get_data_pipeline_dir() -> Path:
    env_dir = os.getenv("HI_CHINESE_DATA_PIPELINE_DIR")
    if env_dir:
        candidate = Path(env_dir).resolve()
        if candidate.exists() and candidate.is_dir():
            return candidate

    return get_project_root() / "data_pipeline"


def get_raw_dir(category: str = "") -> Path:
    env_raw = os.getenv("HI_CHINESE_RAW_DIR")
    base = Path(env_raw).resolve() if env_raw else get_data_pipeline_dir() / "raw"
    target = base / category if category else base
    target.mkdir(parents=True, exist_ok=True)
    return target


def get_processed_dir() -> Path:
    env_proc = os.getenv("HI_CHINESE_PROCESSED_DIR")
    target = Path(env_proc).resolve() if env_proc else get_data_pipeline_dir() / "processed"
    target.mkdir(parents=True, exist_ok=True)
    return target


def get_reports_dir() -> Path:
    env_rep = os.getenv("HI_CHINESE_REPORTS_DIR")
    target = Path(env_rep).resolve() if env_rep else get_data_pipeline_dir() / "reports"
    target.mkdir(parents=True, exist_ok=True)
    return target


def get_assets_data_dir() -> Path:
    env_assets = os.getenv("HI_CHINESE_ASSETS_DATA_DIR")
    target = Path(env_assets).resolve() if env_assets else get_project_root() / "assets" / "data"
    target.mkdir(parents=True, exist_ok=True)
    return target


def get_secure_ssl_context() -> ssl.SSLContext:
    ca_bundle = os.getenv("SSL_CERT_FILE") or os.getenv("REQUESTS_CA_BUNDLE")
    if ca_bundle and Path(ca_bundle).exists():
        return ssl.create_default_context(cafile=ca_bundle)
    return ssl.create_default_context()


DEFAULT_USER_AGENT = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 HI-Chinese-DataPipeline/1.0"
DEFAULT_TIMEOUT = 30


def secure_open_url(url: str, headers: dict | None = None, timeout: int = DEFAULT_TIMEOUT):
    req_headers = {"User-Agent": DEFAULT_USER_AGENT}
    if headers:
        req_headers.update(headers)

    ctx = get_secure_ssl_context()
    req = urllib.request.Request(url, headers=req_headers)
    return urllib.request.urlopen(req, context=ctx, timeout=timeout)


def download_file_secure(url: str, out_path: Path | str, headers: dict | None = None, timeout: int = DEFAULT_TIMEOUT) -> int:
    target = Path(out_path).resolve()
    target.parent.mkdir(parents=True, exist_ok=True)

    with secure_open_url(url, headers=headers, timeout=timeout) as resp:
        data = resp.read()
        target.write_bytes(data)
        return len(data)
