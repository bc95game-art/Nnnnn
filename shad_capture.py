"""
Shad Link Extractor — mitmproxy addon
ضبط لینک‌ها، توکن‌ها و اطلاعات احراز هویت برنامه شاد
"""

import os
import re
import json
from datetime import datetime
from mitmproxy import http, ctx

# آدرس‌هایی که می‌خواهیم ضبط کنیم
TARGET_HOSTS = [
    "ir.medu.shad",
    "shad.ir",
    "app.shad.ir",
    "api.shad.ir",
    "shadmessenger.ir",
    "medu.ir",
    "medu.gov.ir",
]

# هدرهایی که ممکن است توکن داشته باشند
TOKEN_HEADERS = [
    "authorization",
    "x-auth-token",
    "x-access-token",
    "x-api-key",
    "x-token",
    "token",
    "bearer",
    "x-user-token",
    "x-session-token",
    "x-device-token",
]

LOG_DIR = os.path.expanduser("~/shad-extractor/logs")
LOG_FILE      = os.path.join(LOG_DIR, "captured.log")
LINKS_FILE    = os.path.join(LOG_DIR, "links_only.txt")
TOKENS_FILE   = os.path.join(LOG_DIR, "tokens.txt")
SUMMARY_FILE  = os.path.join(LOG_DIR, "summary.txt")

os.makedirs(LOG_DIR, exist_ok=True)


# ─────────────────────────────────────────
# ابزارهای کمکی
# ─────────────────────────────────────────

def is_target(host: str) -> bool:
    host = host.lower()
    return any(t in host for t in TARGET_HOSTS)


def extract_urls(text: str) -> list:
    pattern = re.compile(r'https?://[^\s"\'<>{}\[\]\\]+', re.IGNORECASE)
    return list(set(pattern.findall(text)))


def extract_deep_links(text: str) -> list:
    pattern = re.compile(r'[a-zA-Z][a-zA-Z0-9+\-.]*://[^\s"\'<>{}\[\]\\]+', re.IGNORECASE)
    all_links = pattern.findall(text)
    return list(set(l for l in all_links if not l.lower().startswith(("http://", "https://"))))


def extract_tokens_from_headers(headers: dict) -> dict:
    """استخراج توکن از هدرها"""
    found = {}
    for key, val in headers.items():
        k = key.lower()
        if k in TOKEN_HEADERS:
            found[key] = val
        # Bearer token
        if k == "authorization" and val.lower().startswith("bearer "):
            found["__bearer_token"] = val.split(" ", 1)[1].strip()
        # Basic auth
        if k == "authorization" and val.lower().startswith("basic "):
            found["__basic_auth"] = val.split(" ", 1)[1].strip()
    return found


def extract_tokens_from_body(text: str) -> dict:
    """استخراج توکن از بدنه JSON"""
    found = {}
    # توکن‌های رایج در JSON
    token_keys = [
        "token", "access_token", "refresh_token", "auth_token",
        "jwt", "session_token", "api_key", "secret", "key",
        "authorization", "bearer", "id_token", "user_token",
    ]
    try:
        data = json.loads(text)
        if isinstance(data, dict):
            _find_tokens_in_dict(data, token_keys, found, prefix="")
    except (json.JSONDecodeError, Exception):
        # بدنه JSON نیست — جستجوی regex
        for key in token_keys:
            patterns = [
                rf'"{key}"\s*:\s*"([^"]+)"',
                rf"'{key}'\s*:\s*'([^']+)'",
                rf'{key}=([^&\s"\'<>]+)',
            ]
            for pat in patterns:
                m = re.search(pat, text, re.IGNORECASE)
                if m:
                    found[key] = m.group(1)
    return found


def _find_tokens_in_dict(obj, token_keys, found, prefix):
    if isinstance(obj, dict):
        for k, v in obj.items():
            full_key = f"{prefix}.{k}" if prefix else k
            if k.lower() in token_keys and isinstance(v, str) and len(v) > 8:
                found[full_key] = v
            elif isinstance(v, (dict, list)):
                _find_tokens_in_dict(v, token_keys, found, full_key)
    elif isinstance(obj, list):
        for i, item in enumerate(obj[:5]):  # حداکثر ۵ آیتم اول
            _find_tokens_in_dict(item, token_keys, found, f"{prefix}[{i}]")


def save_link(link: str, source: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(LINKS_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] [{source}] {link}\n")


def save_token(token_key: str, token_val: str, source_url: str):
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with open(TOKENS_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts}] {token_key}: {token_val}  (از: {source_url})\n")


def log_full(entry: dict):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def print_tokens(tokens: dict, url: str):
    if not tokens:
        return
    print(f"\n{'='*55}")
    print(f"🔑 توکن/احراز هویت یافت شد!")
    print(f"   URL: {url}")
    for k, v in tokens.items():
        short = v[:60] + "..." if len(v) > 60 else v
        print(f"   {k}: {short}")
    print(f"{'='*55}\n")


def print_links(links: list, url: str):
    if not links:
        return
    print(f"\n{'='*55}")
    print(f"🔗 لینک یافت شد از: {url}")
    for l in links:
        print(f"   {l}")
    print(f"{'='*55}\n")


# ─────────────────────────────────────────
# addon اصلی
# ─────────────────────────────────────────

class ShadCapture:

    def request(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url    = flow.request.pretty_url
        method = flow.request.method
        all_headers = dict(flow.request.headers)

        ctx.log.info(f"[SHAD] ← {method} {url}")

        entry = {
            "type": "request",
            "method": method,
            "url": url,
            "host": host,
            "path": flow.request.path,
            "urls": [],
            "deep_links": [],
            "tokens": {},
        }

        # ── توکن در هدرها ──
        header_tokens = extract_tokens_from_headers(all_headers)
        entry["tokens"].update(header_tokens)
        if header_tokens:
            print_tokens(header_tokens, url)
            for k, v in header_tokens.items():
                save_token(k, v, url)

        # ── توکن و لینک در body ──
        try:
            body = flow.request.get_text()
            if body and len(body) < 500_000:
                entry["urls"]       = extract_urls(body)
                entry["deep_links"] = extract_deep_links(body)
                body_tokens         = extract_tokens_from_body(body)
                entry["tokens"].update(body_tokens)

                if entry["urls"] or entry["deep_links"]:
                    print_links(entry["urls"] + entry["deep_links"], url)
                    for l in entry["urls"] + entry["deep_links"]:
                        save_link(l, f"req-body:{host}")

                if body_tokens:
                    print_tokens(body_tokens, url)
                    for k, v in body_tokens.items():
                        save_token(k, v, url)
        except Exception as e:
            ctx.log.warn(f"[SHAD] خطا در خواندن body درخواست: {e}")

        # ── URL خود درخواست ──
        save_link(url, f"req:{method}")
        log_full(entry)

    def response(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url    = flow.request.pretty_url
        status = flow.response.status_code

        ctx.log.info(f"[SHAD] → {status} {url}")

        entry = {
            "type": "response",
            "url": url,
            "host": host,
            "status": status,
            "content_type": flow.response.headers.get("content-type", ""),
            "urls": [],
            "deep_links": [],
            "tokens": {},
        }

        # ── توکن در هدرهای پاسخ ──
        resp_headers = dict(flow.response.headers)
        header_tokens = extract_tokens_from_headers(resp_headers)
        entry["tokens"].update(header_tokens)
        if header_tokens:
            print_tokens(header_tokens, url)
            for k, v in header_tokens.items():
                save_token(k, v, url)

        # ── لینک و توکن در بدنه پاسخ ──
        try:
            ct = entry["content_type"].lower()
            parseable = any(t in ct for t in ("json", "text", "html", "xml", "javascript"))
            if parseable:
                body = flow.response.get_text()
                if body and len(body) < 1_000_000:
                    entry["urls"]       = extract_urls(body)
                    entry["deep_links"] = extract_deep_links(body)
                    body_tokens         = extract_tokens_from_body(body)
                    entry["tokens"].update(body_tokens)

                    if entry["urls"] or entry["deep_links"]:
                        print_links(entry["urls"] + entry["deep_links"], url)
                        for l in entry["urls"] + entry["deep_links"]:
                            save_link(l, f"resp-body:{host}")

                    if body_tokens:
                        print_tokens(body_tokens, url)
                        for k, v in body_tokens.items():
                            save_token(k, v, url)
        except Exception as e:
            ctx.log.warn(f"[SHAD] خطا در خواندن body پاسخ: {e}")

        log_full(entry)


addons = [ShadCapture()]
