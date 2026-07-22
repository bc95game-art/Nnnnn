"""
Shad Link Extractor — mitmproxy addon
ضبط لینک‌ها، توکن‌های path، query string و احراز هویت برنامه شاد
"""

import os
import re
import json
from urllib.parse import urlparse, parse_qs
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
    "x-refresh-token",
]

# کلیدهای query string که ممکن است توکن باشند
TOKEN_QUERY_KEYS = [
    "token", "access_token", "refresh_token", "auth_token",
    "code", "auth", "key", "api_key", "session", "jwt",
    "id_token", "user_token", "t", "tk", "hash",
]

# کلیدهای JSON که ممکن است توکن باشند
TOKEN_JSON_KEYS = [
    "token", "access_token", "refresh_token", "auth_token",
    "jwt", "session_token", "api_key", "secret", "key",
    "authorization", "bearer", "id_token", "user_token",
    "hash", "code", "auth_code",
]

LOG_DIR      = os.path.expanduser("~/shad-extractor/logs")
LOG_FILE     = os.path.join(LOG_DIR, "captured.log")
LINKS_FILE   = os.path.join(LOG_DIR, "links_only.txt")
TOKENS_FILE  = os.path.join(LOG_DIR, "tokens.txt")

os.makedirs(LOG_DIR, exist_ok=True)

# ─────────────────────────────────────────
# ابزارهای استخراج
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


def extract_path_token(url: str) -> list:
    """
    استخراج توکن از مسیر URL
    مثال: https://api.shad.ir/file/TOKEN_HERE/view  →  TOKEN_HERE
    """
    try:
        parsed = urlparse(url)
        path = parsed.path
        # رشته‌های بلند در path که احتمالاً توکن یا hash هستند
        tokens = re.findall(r'/([A-Za-z0-9_\-]{20,})', path)
        return tokens
    except Exception:
        return []


def extract_query_tokens(url: str) -> dict:
    """
    استخراج توکن از query string
    مثال: ?token=abc123&code=xyz  →  {"token": "abc123", "code": "xyz"}
    """
    found = {}
    try:
        parsed  = urlparse(url)
        params  = parse_qs(parsed.query, keep_blank_values=False)
        for key, vals in params.items():
            if key.lower() in TOKEN_QUERY_KEYS and vals:
                found[key] = vals[0]
    except Exception:
        pass
    return found


def extract_header_tokens(headers: dict) -> dict:
    """استخراج توکن از هدرهای HTTP"""
    found = {}
    for key, val in headers.items():
        k = key.lower()
        if k in TOKEN_HEADERS:
            found[key] = val
        if k == "authorization":
            val_lower = val.lower()
            if val_lower.startswith("bearer "):
                found["bearer_token"] = val.split(" ", 1)[1].strip()
            elif val_lower.startswith("basic "):
                found["basic_auth_b64"] = val.split(" ", 1)[1].strip()
            else:
                found["authorization_raw"] = val
    return found


def extract_json_tokens(text: str) -> dict:
    """استخراج توکن از بدنه JSON"""
    found = {}

    def _scan(obj, prefix=""):
        if isinstance(obj, dict):
            for k, v in obj.items():
                full = f"{prefix}.{k}" if prefix else k
                if k.lower() in TOKEN_JSON_KEYS and isinstance(v, str) and len(v) > 6:
                    found[full] = v
                elif isinstance(v, (dict, list)):
                    _scan(v, full)
        elif isinstance(obj, list):
            for i, item in enumerate(obj[:5]):
                _scan(item, f"{prefix}[{i}]")

    try:
        data = json.loads(text)
        _scan(data)
    except Exception:
        # fallback: regex روی متن
        for key in TOKEN_JSON_KEYS:
            m = re.search(rf'"{key}"\s*:\s*"([^"]+)"', text, re.IGNORECASE)
            if m and len(m.group(1)) > 6:
                found[key] = m.group(1)
    return found

# ─────────────────────────────────────────
# ذخیره و نمایش
# ─────────────────────────────────────────

def ts() -> str:
    return datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def save_link(link: str, label: str):
    with open(LINKS_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts()}] [{label}] {link}\n")


def save_token(key: str, val: str, source_url: str):
    with open(TOKENS_FILE, "a", encoding="utf-8") as f:
        f.write(f"[{ts()}] {key}: {val}   (از: {source_url})\n")


def log_full(entry: dict):
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")


def _short(s: str, n=70) -> str:
    return (s[:n] + "...") if len(s) > n else s


def display_links(links: list, label: str):
    if not links:
        return
    print(f"\n{'─'*55}")
    print(f"🔗  {label}")
    for l in links:
        print(f"    {_short(l)}")
    print(f"{'─'*55}")


def display_tokens(tokens: dict, label: str):
    if not tokens:
        return
    print(f"\n{'═'*55}")
    print(f"🔑  {label}")
    for k, v in tokens.items():
        print(f"    {k}: {_short(v)}")
    print(f"{'═'*55}")


def display_path_tokens(path_tokens: list, url: str):
    if not path_tokens:
        return
    print(f"\n{'─'*55}")
    print(f"🔑  توکن در مسیر URL")
    print(f"    آدرس: {_short(url)}")
    for t in path_tokens:
        print(f"    /***{_short(t)}***")
    print(f"{'─'*55}")


# ─────────────────────────────────────────
# addon اصلی mitmproxy
# ─────────────────────────────────────────

class ShadCapture:

    def _process_url(self, url: str, label: str, entry: dict):
        """پردازش یک URL: استخراج لینک، توکن query و توکن path"""
        # ذخیره خود URL
        save_link(url, label)

        # توکن در query string
        q_tokens = extract_query_tokens(url)
        if q_tokens:
            display_tokens(q_tokens, f"توکن در query string  ←  {_short(url, 40)}")
            for k, v in q_tokens.items():
                save_token(f"qs:{k}", v, url)
            entry.setdefault("query_tokens", {}).update(q_tokens)

        # توکن در path (رشته بلند بین /)
        p_tokens = extract_path_token(url)
        if p_tokens:
            display_path_tokens(p_tokens, url)
            for t in p_tokens:
                save_token("path_token", t, url)
            entry.setdefault("path_tokens", []).extend(p_tokens)

    def request(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url    = flow.request.pretty_url
        method = flow.request.method
        ctx.log.info(f"[SHAD] ← {method} {url}")

        entry = {"type": "request", "method": method, "url": url, "host": host}

        # ── توکن در هدرهای درخواست ──
        h_tokens = extract_header_tokens(dict(flow.request.headers))
        if h_tokens:
            display_tokens(h_tokens, f"احراز هویت در هدر  ←  {_short(url, 35)}")
            for k, v in h_tokens.items():
                save_token(f"header:{k}", v, url)
            entry["header_tokens"] = h_tokens

        # ── پردازش URL درخواست ──
        self._process_url(url, f"req:{method}", entry)

        # ── بدنه درخواست ──
        try:
            body = flow.request.get_text()
            if body and len(body) < 500_000:
                urls       = extract_urls(body)
                deep_links = extract_deep_links(body)
                j_tokens   = extract_json_tokens(body)

                for l in urls + deep_links:
                    display_links([l], f"لینک در body درخواست  ←  {host}")
                    self._process_url(l, "req-body", entry)

                if j_tokens:
                    display_tokens(j_tokens, f"توکن در body درخواست  ←  {host}")
                    for k, v in j_tokens.items():
                        save_token(f"body:{k}", v, url)
                    entry["body_tokens"] = j_tokens
        except Exception as e:
            ctx.log.warn(f"[SHAD] خطا در body درخواست: {e}")

        log_full(entry)

    def response(self, flow: http.HTTPFlow) -> None:
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url    = flow.request.pretty_url
        status = flow.response.status_code
        ctx.log.info(f"[SHAD] → {status} {url}")

        entry = {"type": "response", "url": url, "host": host, "status": status}

        # ── توکن در هدرهای پاسخ ──
        h_tokens = extract_header_tokens(dict(flow.response.headers))
        if h_tokens:
            display_tokens(h_tokens, f"توکن در هدر پاسخ  ←  {host}")
            for k, v in h_tokens.items():
                save_token(f"resp-header:{k}", v, url)
            entry["header_tokens"] = h_tokens

        # ── بدنه پاسخ ──
        try:
            ct = flow.response.headers.get("content-type", "").lower()
            if any(t in ct for t in ("json", "text", "html", "xml", "javascript")):
                body = flow.response.get_text()
                if body and len(body) < 1_000_000:
                    urls       = extract_urls(body)
                    deep_links = extract_deep_links(body)
                    j_tokens   = extract_json_tokens(body)

                    for l in urls:
                        display_links([l], f"لینک در پاسخ  ←  {host}")
                        self._process_url(l, "resp-body", entry)

                    for l in deep_links:
                        display_links([l], f"Deep Link در پاسخ  ←  {host}")
                        self._process_url(l, "resp-deep", entry)

                    if j_tokens:
                        display_tokens(j_tokens, f"توکن در پاسخ JSON  ←  {host}")
                        for k, v in j_tokens.items():
                            save_token(f"resp-body:{k}", v, url)
                        entry["body_tokens"] = j_tokens
        except Exception as e:
            ctx.log.warn(f"[SHAD] خطا در body پاسخ: {e}")

        log_full(entry)


addons = [ShadCapture()]
