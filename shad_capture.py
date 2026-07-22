"""
Shad Link Extractor — mitmproxy addon
ضبط و ذخیره لینک‌های برنامه شاد
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
]

# پوشه ذخیره لاگ
LOG_DIR = os.path.expanduser("~/shad-extractor/logs")
LOG_FILE = os.path.join(LOG_DIR, "captured.log")
LINKS_FILE = os.path.join(LOG_DIR, "links_only.txt")

os.makedirs(LOG_DIR, exist_ok=True)


def is_target(host: str) -> bool:
    """بررسی اینکه آیا درخواست از شاد است"""
    host = host.lower()
    return any(t in host for t in TARGET_HOSTS)


def extract_urls_from_body(body_text: str) -> list:
    """استخراج URL از بدنه پاسخ"""
    url_pattern = re.compile(
        r'https?://[^\s\'"<>\{\}\[\]\\]+',
        re.IGNORECASE
    )
    return url_pattern.findall(body_text)


def extract_deep_links(body_text: str) -> list:
    """استخراج deep link های شاد"""
    deep_pattern = re.compile(
        r'[a-zA-Z][a-zA-Z0-9+\-.]*://[^\s\'"<>\{\}\[\]\\]+',
        re.IGNORECASE
    )
    links = deep_pattern.findall(body_text)
    # فیلتر کردن لینک‌های معمولی http/https (قبلاً گرفتیم)
    return [l for l in links if not l.startswith(('http://', 'https://'))]


def log_entry(entry: dict):
    """ذخیره اطلاعات در فایل لاگ"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    entry['timestamp'] = timestamp

    # لاگ کامل
    with open(LOG_FILE, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False) + "\n")

    # فقط لینک‌ها
    all_links = entry.get('urls', []) + entry.get('deep_links', [])
    if all_links:
        with open(LINKS_FILE, "a", encoding="utf-8") as f:
            for link in all_links:
                f.write(f"[{timestamp}] {link}\n")


class ShadCapture:
    """ضبط‌کننده اصلی ترافیک شاد"""

    def request(self, flow: http.HTTPFlow) -> None:
        """ضبط درخواست‌ها"""
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url = flow.request.pretty_url
        method = flow.request.method
        headers = dict(flow.request.headers)

        ctx.log.info(f"[SHAD] ← {method} {url}")

        entry = {
            "type": "request",
            "method": method,
            "url": url,
            "host": host,
            "path": flow.request.path,
            "headers": {
                k: v for k, v in headers.items()
                if k.lower() in ('authorization', 'content-type', 'user-agent', 'x-app-version')
            },
            "urls": [],
            "deep_links": [],
        }

        # بررسی body درخواست
        try:
            body = flow.request.get_text()
            if body:
                entry['urls'] = extract_urls_from_body(body)
                entry['deep_links'] = extract_deep_links(body)
                if entry['urls'] or entry['deep_links']:
                    ctx.log.info(f"[SHAD] 🔗 لینک در درخواست: {entry['urls'] + entry['deep_links']}")
        except Exception:
            pass

        log_entry(entry)

    def response(self, flow: http.HTTPFlow) -> None:
        """ضبط پاسخ‌ها"""
        host = flow.request.pretty_host
        if not is_target(host):
            return

        url = flow.request.pretty_url
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
        }

        # استخراج لینک از بدنه پاسخ
        try:
            content_type = entry['content_type'].lower()
            if any(t in content_type for t in ('json', 'text', 'html', 'xml')):
                body = flow.response.get_text()
                if body:
                    entry['urls'] = extract_urls_from_body(body)
                    entry['deep_links'] = extract_deep_links(body)
                    if entry['urls']:
                        ctx.log.info(f"[SHAD] 🔗 لینک یافت شد: {entry['urls']}")
                    if entry['deep_links']:
                        ctx.log.info(f"[SHAD] 🔗 Deep Link: {entry['deep_links']}")
        except Exception:
            pass

        log_entry(entry)

        # نمایش خلاصه در ترمینال
        all_links = entry['urls'] + entry['deep_links']
        if all_links:
            print(f"\n{'='*50}")
            print(f"🔗 لینک جدید از {host}:")
            for link in all_links:
                print(f"   {link}")
            print(f"{'='*50}\n")


addons = [ShadCapture()]
