#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# با مدیریت خطای کامل
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

# ── پاکسازی PID قدیمی ──
if [ -f "$SOCKS_PID_FILE" ]; then
    OLD_PID=$(cat "$SOCKS_PID_FILE")
    kill "$OLD_PID" 2>/dev/null || true
    rm -f "$SOCKS_PID_FILE"
fi

# ── بررسی پورت آزاد ──
check_port() {
    local port=$1
    if ss -tuln 2>/dev/null | grep -q ":$port " || \
       netstat -tuln 2>/dev/null | grep -q ":$port "; then
        return 1  # پورت اشغال است
    fi
    return 0
}

set_proxy() {
    local addr="127.0.0.1:${MITM_PORT}"
    settings put global http_proxy "$addr" 2>/dev/null && PROXY_SET=1 && \
        ok "پروکسی خودکار فعال (بدون روت)" && return 0
    command -v su &>/dev/null && su -c "settings put global http_proxy '$addr'" 2>/dev/null && \
        PROXY_SET=1 && ok "پروکسی خودکار فعال (روت)" && return 0
    command -v adb &>/dev/null && adb shell settings put global http_proxy "$addr" 2>/dev/null && \
        PROXY_SET=1 && ok "پروکسی خودکار فعال (ADB)" && return 0
    return 1
}

clear_proxy() {
    [ "$PROXY_SET" = "0" ] && return
    settings delete global http_proxy 2>/dev/null || \
    { command -v su &>/dev/null && su -c "settings delete global http_proxy" 2>/dev/null; } || \
    { command -v adb &>/dev/null && adb shell settings delete global http_proxy 2>/dev/null; } || true
    ok "پروکسی سیستم پاک شد"
}

cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف...${NC}"
    if [ -f "$SOCKS_PID_FILE" ]; then
        kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null || true
        rm -f "$SOCKS_PID_FILE"
    fi
    # کشتن mitmdump
    pkill -f "mitmdump" 2>/dev/null || true
    clear_proxy
    echo ""
    echo -e "${GREEN}لینک‌های ضبط‌شده در:${NC}"
    echo -e "  ${YELLOW}$LOG_DIR/links_only.txt${NC}"
    echo -e "  ${YELLOW}$LOG_DIR/tokens.txt${NC}"
    echo ""
    echo -e "برای خروجی: ${YELLOW}bash export_links.sh${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# ─────────────────────────────────────────
clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── بررسی پیش‌نیازها ──
echo -e "${CYAN}[بررسی] پیش‌نیازها...${NC}"

! command -v mitmdump &>/dev/null && err "mitmproxy نصب نیست — اول: bash install.sh"
ok "mitmproxy موجود است"

! command -v python3 &>/dev/null && err "Python نصب نیست — اول: bash install.sh"
ok "Python موجود است"

[ ! -f "$SCRIPT_DIR/shad_capture.py" ] && err "فایل shad_capture.py یافت نشد"
ok "shad_capture.py موجود است"

[ ! -f "$SCRIPT_DIR/builtin_proxy.py" ] && err "فایل builtin_proxy.py یافت نشد"
ok "builtin_proxy.py موجود است"

# ── [۱] پروکسی SOCKS5 ──
echo ""
echo -e "${CYAN}[۱/۳] راه‌اندازی پروکسی داخلی...${NC}"

if ! check_port "$SOCKS_PORT"; then
    warn "پورت $SOCKS_PORT اشغال است — تلاش با پورت 1081"
    SOCKS_PORT=1081
fi

python3 "$SCRIPT_DIR/builtin_proxy.py" "$SOCKS_PORT" > "$LOG_DIR/socks5.log" 2>&1 &
SOCKS_PID=$!
echo "$SOCKS_PID" > "$SOCKS_PID_FILE"
sleep 1

if ! kill -0 "$SOCKS_PID" 2>/dev/null; then
    echo -e "${RED}   خطا در راه‌اندازی SOCKS5:${NC}"
    cat "$LOG_DIR/socks5.log"
    err "SOCKS5 راه‌اندازی نشد"
fi
ok "SOCKS5 فعال — 127.0.0.1:${SOCKS_PORT}"

# ── [۲] پروکسی سیستم ──
echo ""
echo -e "${CYAN}[۲/۳] تنظیم پروکسی سیستم اندروید...${NC}"
if set_proxy; then
    echo -e "${GREEN}   📱 نیازی به تنظیم دستی نیست!${NC}"
else
    warn "تنظیم خودکار ممکن نشد"
    LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
    [ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"
    echo ""
    echo -e "   برای تنظیم دستی:"
    echo -e "   ${YELLOW}WiFi ← پروکسی دستی ← آدرس: $LOCAL_IP ← پورت: $MITM_PORT${NC}"
    echo ""
    echo -e "   یا یک‌بار: ${YELLOW}bash setup_permission.sh${NC}"
    echo ""
    read -rp "   Enter برای ادامه..." _
fi

# ── [۳] ضبط ترافیک ──
echo ""
echo -e "${CYAN}[۳/۳] شروع ضبط ترافیک...${NC}"
echo ""
echo -e "${GREEN}▶ شاد را باز کنید — Ctrl+C برای توقف${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"
echo ""

if ! mitmdump \
    --listen-host 0.0.0.0 \
    --listen-port "$MITM_PORT" \
    --mode "upstream:socks5h://127.0.0.1:${SOCKS_PORT}" \
    --script "$SCRIPT_DIR/shad_capture.py" \
    --ssl-insecure \
    --set flow_detail=1 \
    2>&1; then
    echo ""
    warn "mitmdump با خطا متوقف شد — لاگ کامل در: $LOG_DIR/socks5.log"
fi
