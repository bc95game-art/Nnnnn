#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
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

cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف...${NC}"
    [ -f "$SOCKS_PID_FILE" ] && kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null && rm -f "$SOCKS_PID_FILE"
    echo -e "${GREEN}خروجی لینک‌ها: ${YELLOW}bash export_links.sh${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM

clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   🔗 Shad Link Extractor                 ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

if ! command -v mitmdump &>/dev/null; then
    echo -e "${RED}❌ mitmproxy نصب نیست — اول: bash install.sh${NC}"
    exit 1
fi

# ── راه‌اندازی SOCKS5 محلی ──
echo -e "${CYAN}[۱/۲] راه‌اندازی پروکسی داخلی...${NC}"
python3 "$SCRIPT_DIR/builtin_proxy.py" "$SOCKS_PORT" > "$LOG_DIR/socks5.log" 2>&1 &
SOCKS_PID=$!
echo "$SOCKS_PID" > "$SOCKS_PID_FILE"
sleep 1

if ! kill -0 "$SOCKS_PID" 2>/dev/null; then
    echo -e "${RED}❌ خطا در راه‌اندازی پروکسی:${NC}"
    cat "$LOG_DIR/socks5.log"
    exit 1
fi
echo -e "${GREEN}   ✅ SOCKS5 فعال — 127.0.0.1:${SOCKS_PORT}${NC}"

# ── آدرس WiFi ──
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

echo ""
echo -e "${CYAN}[۲/۲] راه‌اندازی ضبط ترافیک...${NC}"
echo ""
echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  تنظیم WiFi گوشی:                        │${NC}"
echo -e "${YELLOW}│  پروکسی: دستی                            │${NC}"
echo -e "${YELLOW}│  آدرس  : $LOCAL_IP                    │${NC}"
echo -e "${YELLOW}│  پورت  : $MITM_PORT                          │${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}▶ در حال ضبط... (Ctrl+C برای توقف)${NC}"
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
