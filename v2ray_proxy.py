"""
V2Ray Link Parser + Config Generator
پشتیبانی از: vmess, vless, trojan, shadowsocks (ss)
"""

import base64
import json
import re
import sys
import os
from urllib.parse import urlparse, parse_qs, unquote

# ─────────────────────────────────────────
# پارسرها
# ─────────────────────────────────────────

def decode_b64(s: str) -> str:
    s = s.strip().replace("-", "+").replace("_", "/")
    pad = 4 - len(s) % 4
    if pad != 4:
        s += "=" * pad
    return base64.b64decode(s).decode("utf-8", errors="replace")


def parse_vmess(link: str) -> dict:
    """vmess://BASE64"""
    raw = link.replace("vmess://", "").strip()
    try:
        data = json.loads(decode_b64(raw))
    except Exception as e:
        raise ValueError(f"vmess parse error: {e}")
    return {
        "protocol": "vmess",
        "address":  data.get("add", ""),
        "port":     int(data.get("port", 443)),
        "uuid":     data.get("id", ""),
        "alter_id": int(data.get("aid", 0)),
        "network":  data.get("net", "tcp"),
        "tls":      data.get("tls", ""),
        "sni":      data.get("sni", data.get("host", "")),
        "path":     data.get("path", "/"),
        "host":     data.get("host", ""),
        "name":     data.get("ps", "vmess-server"),
        "type":     data.get("type", "none"),
    }


def parse_vless(link: str) -> dict:
    """vless://UUID@HOST:PORT?params#name"""
    parsed = urlparse(link)
    params = parse_qs(parsed.query)
    def p(k, d=""): return params.get(k, [d])[0]
    return {
        "protocol":   "vless",
        "uuid":       parsed.username or "",
        "address":    parsed.hostname or "",
        "port":       parsed.port or 443,
        "flow":       p("flow"),
        "encryption": p("encryption", "none"),
        "security":   p("security", "none"),
        "sni":        p("sni"),
        "fp":         p("fp"),
        "pbk":        p("pbk"),
        "sid":        p("sid"),
        "network":    p("type", "tcp"),
        "path":       p("path", "/"),
        "host":       p("host"),
        "name":       unquote(parsed.fragment) if parsed.fragment else "vless-server",
    }


def parse_trojan(link: str) -> dict:
    """trojan://PASSWORD@HOST:PORT?params#name"""
    parsed = urlparse(link)
    params = parse_qs(parsed.query)
    def p(k, d=""): return params.get(k, [d])[0]
    return {
        "protocol": "trojan",
        "password": parsed.username or parsed.password or "",
        "address":  parsed.hostname or "",
        "port":     parsed.port or 443,
        "sni":      p("sni"),
        "security": p("security", "tls"),
        "network":  p("type", "tcp"),
        "path":     p("path", "/"),
        "host":     p("host"),
        "name":     unquote(parsed.fragment) if parsed.fragment else "trojan-server",
    }


def parse_ss(link: str) -> dict:
    """ss://BASE64@HOST:PORT#name  یا  ss://BASE64(method:pass@host:port)#name"""
    raw = link.replace("ss://", "")
    name = ""
    if "#" in raw:
        raw, name = raw.rsplit("#", 1)
        name = unquote(name)

    # حالت جدید: method:pass در base64، بعد @host:port
    if "@" in raw:
        b64_part, hostport = raw.rsplit("@", 1)
        try:
            decoded = decode_b64(b64_part)
            method, password = decoded.split(":", 1)
        except Exception:
            method, password = "chacha20-ietf-poly1305", b64_part
        host, port_str = hostport.rsplit(":", 1)
        port = int(port_str)
    else:
        try:
            decoded = decode_b64(raw)
            # method:pass@host:port
            m = re.match(r'([^:]+):([^@]+)@([^:]+):(\d+)', decoded)
            if m:
                method, password, host, port = m.group(1), m.group(2), m.group(3), int(m.group(4))
            else:
                raise ValueError("format unrecognized")
        except Exception as e:
            raise ValueError(f"ss parse error: {e}")

    return {
        "protocol": "shadowsocks",
        "method":   method,
        "password": password,
        "address":  host,
        "port":     port,
        "name":     name or "ss-server",
    }


def parse_link(link: str) -> dict:
    link = link.strip()
    if link.startswith("vmess://"):
        return parse_vmess(link)
    elif link.startswith("vless://"):
        return parse_vless(link)
    elif link.startswith("trojan://"):
        return parse_trojan(link)
    elif link.startswith("ss://"):
        return parse_ss(link)
    else:
        raise ValueError(f"پروتکل شناخته‌شده نیست. پشتیبانی از: vmess, vless, trojan, ss")


# ─────────────────────────────────────────
# سازنده کانفیگ V2Ray/Xray
# ─────────────────────────────────────────

def build_config(info: dict, socks_port=1080, http_port=1081) -> dict:
    proto = info["protocol"]

    # ── inbounds ──
    inbounds = [
        {
            "tag":      "socks-in",
            "listen":   "127.0.0.1",
            "port":     socks_port,
            "protocol": "socks",
            "settings": {"auth": "noauth", "udp": True},
            "sniffing": {"enabled": True, "destOverride": ["http", "tls"]}
        },
        {
            "tag":      "http-in",
            "listen":   "127.0.0.1",
            "port":     http_port,
            "protocol": "http",
            "settings": {}
        }
    ]

    # ── outbound بر اساس پروتکل ──
    if proto == "vmess":
        network  = info.get("network", "tcp")
        tls_type = "tls" if info.get("tls") in ("tls", "xtls") else "none"

        stream = {"network": network, "security": tls_type}
        if tls_type == "tls":
            stream["tlsSettings"] = {"serverName": info.get("sni") or info.get("address"), "allowInsecure": False}

        if network == "ws":
            stream["wsSettings"] = {"path": info.get("path", "/"), "headers": {"Host": info.get("host", "")}}
        elif network == "grpc":
            stream["grpcSettings"] = {"serviceName": info.get("path", "")}
        elif network == "h2":
            stream["httpSettings"] = {"path": info.get("path", "/"), "host": [info.get("host", "")]}

        outbound = {
            "tag":      "proxy",
            "protocol": "vmess",
            "settings": {
                "vnext": [{
                    "address": info["address"],
                    "port":    info["port"],
                    "users":   [{"id": info["uuid"], "alterId": info.get("alter_id", 0), "security": "auto"}]
                }]
            },
            "streamSettings": stream
        }

    elif proto == "vless":
        network  = info.get("network", "tcp")
        security = info.get("security", "none")

        stream = {"network": network, "security": security}
        if security == "tls":
            stream["tlsSettings"] = {"serverName": info.get("sni") or info.get("address"), "allowInsecure": False}
        elif security == "reality":
            stream["realitySettings"] = {
                "serverName": info.get("sni", ""),
                "fingerprint": info.get("fp", "chrome"),
                "publicKey":   info.get("pbk", ""),
                "shortId":     info.get("sid", ""),
            }

        if network == "ws":
            stream["wsSettings"] = {"path": info.get("path", "/"), "headers": {"Host": info.get("host", "")}}
        elif network == "grpc":
            stream["grpcSettings"] = {"serviceName": info.get("path", "")}

        user = {"id": info["uuid"], "encryption": info.get("encryption", "none")}
        if info.get("flow"):
            user["flow"] = info["flow"]

        outbound = {
            "tag":      "proxy",
            "protocol": "vless",
            "settings": {
                "vnext": [{"address": info["address"], "port": info["port"], "users": [user]}]
            },
            "streamSettings": stream
        }

    elif proto == "trojan":
        network  = info.get("network", "tcp")
        security = info.get("security", "tls")
        stream   = {"network": network, "security": security}
        if security == "tls":
            stream["tlsSettings"] = {"serverName": info.get("sni") or info.get("address"), "allowInsecure": False}
        if network == "ws":
            stream["wsSettings"] = {"path": info.get("path", "/"), "headers": {"Host": info.get("host", "")}}

        outbound = {
            "tag":      "proxy",
            "protocol": "trojan",
            "settings": {
                "servers": [{"address": info["address"], "port": info["port"], "password": info["password"]}]
            },
            "streamSettings": stream
        }

    elif proto == "shadowsocks":
        outbound = {
            "tag":      "proxy",
            "protocol": "shadowsocks",
            "settings": {
                "servers": [{
                    "address":  info["address"],
                    "port":     info["port"],
                    "method":   info["method"],
                    "password": info["password"],
                    "ota":      False
                }]
            }
        }

    else:
        raise ValueError(f"پروتکل {proto} پشتیبانی نمی‌شود")

    config = {
        "log":       {"loglevel": "warning"},
        "inbounds":  inbounds,
        "outbounds": [
            outbound,
            {"tag": "direct",  "protocol": "freedom", "settings": {}},
            {"tag": "blocked", "protocol": "blackhole","settings": {}}
        ],
        "routing": {
            "domainStrategy": "IPIfNonMatch",
            "rules": [
                {"type": "field", "ip":     ["geoip:private"], "outboundTag": "direct"},
                {"type": "field", "domain": ["geosite:category-ads-all"], "outboundTag": "blocked"}
            ]
        }
    }
    return config


# ─────────────────────────────────────────
# اجرا از CLI
# ─────────────────────────────────────────

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("استفاده: python3 v2ray_proxy.py 'LINK' [SOCKS_PORT] [HTTP_PORT]")
        print("مثال:   python3 v2ray_proxy.py 'vmess://...' 1080 1081")
        sys.exit(1)

    link       = sys.argv[1]
    socks_port = int(sys.argv[2]) if len(sys.argv) > 2 else 1080
    http_port  = int(sys.argv[3]) if len(sys.argv) > 3 else 1081

    try:
        info   = parse_link(link)
        config = build_config(info, socks_port, http_port)

        out_path = os.path.expanduser("~/shad-extractor/v2ray_config.json")
        os.makedirs(os.path.dirname(out_path), exist_ok=True)
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(config, f, ensure_ascii=False, indent=2)

        print(f"OK|{info['protocol']}|{info['address']}:{info['port']}|{info['name']}|{out_path}")
    except Exception as e:
        print(f"ERR|{e}")
        sys.exit(1)
