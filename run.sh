#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# پروکسی خودکار — بدون دست زدن به WiFi
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"

SOCKS_PID_FILE="$HOME/shad-extractor/.socks.pid"
SOCKS_PORT=1080
MITM_PORT=8080
PROXY_SET=0   # آیا پروکسی سیستم تنظیم شد؟

# ─────────────────────────────────────────
# توابع تنظیم پروکسی سیستم‌عامل
# ─────────────────────────────────────────

set_proxy() {
    local addr="127.0.0.1:${MITM_PORT}"

    # روش ۱: مستقیم (اگر WRITE_SECURE_SETTINGS داده شده)
    if settings put global http_proxy "$addr" 2>/dev/null; then
        PROXY_SET=1
        echo -e "${GREEN}   ✅ پروکسی سیستم تنظیم شد (بدون روت)${NC}"
        return 0
    fi

    # روش ۲: روت
    if command -v su &>/dev/null; then
        if su -c "settings put global http_proxy '$addr'" 2>/dev/null; then
            PROXY_SET=1
            echo -e "${GREEN}   ✅ پروکسی سیستم تنظیم شد (روت)${NC}"
            return 0
        fi
    fi

    # روش ۳: ADB محلی (adb shell در همان گوشی)
    if command -v adb &>/dev/null; then
        if adb shell settings put global http_proxy "$addr" 2>/dev/null; then
            PROXY_SET=1
            echo -e "${GREEN}   ✅ پروکسی سیستم تنظیم شد (ADB)${NC}"
            return 0
        fi
    fi

    # هیچ‌کدام کار نکرد — دستی
    return 1
}

clear_proxy() {
    [ "$PROXY_SET" = "0" ] && return
    local cleared=0

    settings delete global http_proxy 2>/dev/null && cleared=1
    [ "$cleared" = "0" ] && command -v su &>/dev/null && \
        su -c "settings delete global http_proxy" 2>/dev/null && cleared=1
    [ "$cleared" = "0" ] && command -v adb &>/dev/null && \
        adb shell settings delete global http_proxy 2>/dev/null && cleared=1

    [ "$cleared" = "1" ] && echo -e "${GREEN}   ✅ پروکسی سیستم پاک شد${NC}"
}

# ─────────────────────────────────────────
cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف...${NC}"
    [ -f "$SOCKS_PID_FILE" ] && kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null && rm -f "$SOCKS_PID_FILE"
    clear_proxy
    echo -e "${GREEN}خروجی لینک‌ها: ${YELLOW}bash export_links.sh${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

# ─────────────────────────────────────────
clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

if ! command -v mitmdump &>/dev/null; then
    echo -e "${RED}❌ mitmproxy نصب نیست — اول: bash install.sh${NC}"
    exit 1
fi

# ── [۱] پروکسی SOCKS5 داخلی ──
echo -e "${CYAN}[۱/۳] راه‌اندازی پروکسی داخلی...${NC}"
python3 "$SCRIPT_DIR/builtin_proxy.py" "$SOCKS_PORT" > "$LOG_DIR/socks5.log" 2>&1 &
SOCKS_PID=$!
echo "$SOCKS_PID" > "$SOCKS_PID_FILE"
sleep 1

if ! kill -0 "$SOCKS_PID" 2>/dev/null; then
    echo -e "${RED}❌ خطا:${NC}"
    cat "$LOG_DIR/socks5.log"
    exit 1
fi
echo -e "${GREEN}   ✅ SOCKS5 فعال — 127.0.0.1:${SOCKS_PORT}${NC}"

# ── [۲] تنظیم خودکار پروکسی سیستم ──
echo -e "${CYAN}[۲/۳] تنظیم پروکسی سیستم اندروید...${NC}"
if set_proxy; then
    echo ""
    echo -e "${GREEN}   📱 پروکسی خودکار فعال شد — نیازی به تنظیم WiFi نیست!${NC}"
else
    echo -e "${YELLOW}   ⚠️  تنظیم خودکار ممکن نشد.${NC}"
    echo -e "${YELLOW}   یکی از کارها را انجام دهید:${NC}"
    echo ""
    echo -e "   الف) یک‌بار از PC بزنید:"
    echo -e "   ${CYAN}adb shell pm grant com.termux android.permission.WRITE_SECURE_SETTINGS${NC}"
    echo -e "   بعد دوباره ${YELLOW}bash run.sh${NC} را اجرا کنید."
    echo ""
    echo -e "   ب) یا WiFi را دستی تنظیم کنید:"
    LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"
    echo -e "   ${YELLOW}آدرس: $LOCAL_IP  |  پورت: $MITM_PORT${NC}"
    echo ""
    read -rp "   ادامه می‌دهید؟ [Enter] " _
fi

# ── [۳] ضبط ترافیک ──
echo ""
echo -e "${CYAN}[۳/۳] شروع ضبط ترافیک...${NC}"
echo ""
echo -e "${GREEN}▶ در حال ضبط — شاد را باز کنید (Ctrl+C برای توقف)${NC}"
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
