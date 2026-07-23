#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}   ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}   ⚠️  $1${NC}"; }
err()  { echo -e "${RED}   ❌ $1${NC}"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"

SOCKS_PID_FILE="$HOME/shad-extractor/.socks.pid"
SOCKS_PORT=1080
MITM_PORT=8080
PROXY_SET=0

# ── پاکسازی قبلی ──
[ -f "$SOCKS_PID_FILE" ] && kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null && rm -f "$SOCKS_PID_FILE"
pkill -f "mitmdump" 2>/dev/null || true

set_proxy() {
    local addr="127.0.0.1:${MITM_PORT}"

    # روش ۱: مستقیم
    if settings put global http_proxy "$addr" 2>/dev/null; then
        PROXY_SET=1; ok "پروکسی خودکار (مستقیم)"; return 0
    fi

    # روش ۲: روت
    if command -v su &>/dev/null; then
        if su -c "settings put global http_proxy '$addr'" 2>/dev/null; then
            PROXY_SET=1; ok "پروکسی خودکار (روت)"; return 0
        fi
    fi

    # روش ۳: ADB — اگر وصل است
    if command -v adb &>/dev/null && adb devices 2>/dev/null | grep -q "device$"; then
        if adb shell settings put global http_proxy "$addr" 2>/dev/null; then
            PROXY_SET=2; ok "پروکسی خودکار (ADB)"; return 0
        fi
    fi

    return 1
}

clear_proxy() {
    [ "$PROXY_SET" = "0" ] && return
    if [ "$PROXY_SET" = "2" ]; then
        adb shell settings delete global http_proxy 2>/dev/null || true
    else
        settings delete global http_proxy 2>/dev/null || \
        su -c "settings delete global http_proxy" 2>/dev/null || true
    fi
    ok "پروکسی سیستم پاک شد"
}

cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف...${NC}"
    [ -f "$SOCKS_PID_FILE" ] && kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null; rm -f "$SOCKS_PID_FILE"
    pkill -f "mitmdump" 2>/dev/null || true
    clear_proxy
    echo ""
    echo -e "لینک‌ها: ${YELLOW}$LOG_DIR/links_only.txt${NC}"
    echo -e "توکن‌ها: ${YELLOW}$LOG_DIR/tokens.txt${NC}"
    echo -e "خروجی:   ${YELLOW}bash export_links.sh${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ─────────────────────────────────────────
clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── بررسی پیش‌نیازها ──
echo -e "${CYAN}[بررسی] پیش‌نیازها...${NC}"
! command -v mitmdump &>/dev/null && err "mitmproxy نصب نیست — اول: bash install.sh"
! python3 -c "from mitmproxy.tools.main import mitmdump" 2>/dev/null && \
    err "mitmproxy خراب است — دوباره: bash install.sh"
ok "mitmproxy سالم است"
[ ! -f "$SCRIPT_DIR/shad_capture.py" ]  && err "shad_capture.py یافت نشد"
[ ! -f "$SCRIPT_DIR/builtin_proxy.py" ] && err "builtin_proxy.py یافت نشد"
ok "فایل‌های پروژه موجودند"

# ── [۱] SOCKS5 ──
echo ""
echo -e "${CYAN}[۱/۳] راه‌اندازی پروکسی داخلی...${NC}"
python3 "$SCRIPT_DIR/builtin_proxy.py" "$SOCKS_PORT" > "$LOG_DIR/socks5.log" 2>&1 &
echo $! > "$SOCKS_PID_FILE"
sleep 1
if ! kill -0 "$(cat "$SOCKS_PID_FILE")" 2>/dev/null; then
    cat "$LOG_DIR/socks5.log"; err "SOCKS5 راه‌اندازی نشد"
fi
ok "SOCKS5 فعال — 127.0.0.1:${SOCKS_PORT}"

# ── [۲] پروکسی سیستم ──
echo ""
echo -e "${CYAN}[۲/۳] تنظیم پروکسی سیستم...${NC}"
if set_proxy; then
    echo -e "${GREEN}   📱 پروکسی خودکار — نیازی به تنظیم WiFi نیست!${NC}"
else
    warn "تنظیم خودکار ممکن نشد"
    LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"
    echo ""
    echo -e "   ${YELLOW}WiFi ← پروکسی دستی ← آدرس: $LOCAL_IP ← پورت: $MITM_PORT${NC}"
    echo ""
    read -rp "   Enter برای ادامه..." _
fi

# ── [۳] ضبط ─
echo ""
echo -e "${CYAN}[۳/۳] شروع ضبط ترافیک...${NC}"
echo ""
echo -e "${GREEN}▶ شاد را باز کنید — Ctrl+C برای توقف${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"
echo ""

mitmdump \
    --listen-host 0.0.0.0 \
    --listen-port "$MITM_PORT" \
    --mode "upstream:socks5h://127.0.0.1:${SOCKS_PORT}" \
    --script "$SCRIPT_DIR/shad_capture.py" \
    --ssl-insecure \
    --set flow_detail=1 \
    2>&1
