#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — اجرا
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$HOME/shad-extractor/logs"
mkdir -p "$LOG_DIR"

V2RAY_PID_FILE="$HOME/shad-extractor/.v2ray.pid"
SOCKS_PID_FILE="$HOME/shad-extractor/.socks.pid"
SOCKS_PORT=1080
MITM_PORT=8080

cleanup() {
    echo ""
    echo -e "${YELLOW}در حال توقف...${NC}"
    [ -f "$V2RAY_PID_FILE" ] && kill "$(cat "$V2RAY_PID_FILE")" 2>/dev/null && rm -f "$V2RAY_PID_FILE"
    [ -f "$SOCKS_PID_FILE" ] && kill "$(cat "$SOCKS_PID_FILE")" 2>/dev/null && rm -f "$SOCKS_PID_FILE"
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

# ── انتخاب نوع پروکسی ──
echo -e "${CYAN}${BOLD}نوع پروکسی را انتخاب کنید:${NC}"
echo ""
echo -e "  ${YELLOW}1${NC}  پروکسی داخلی (بدون سرور — همین گوشی)"
echo -e "      ${CYAN}↳ شاد ← mitmproxy ← SOCKS5 محلی ← اینترنت${NC}"
echo ""
echo -e "  ${YELLOW}2${NC}  لینک V2Ray شخصی"
echo -e "      ${CYAN}↳ شاد ← mitmproxy ← V2Ray ← سرور شما${NC}"
echo ""
echo -e "  ${YELLOW}3${NC}  اتصال مستقیم (بدون پروکسی)"
echo -e "      ${CYAN}↳ شاد ← mitmproxy ← اینترنت${NC}"
echo ""
read -rp "انتخاب [1/2/3]: " MODE

PROXY_MODE="direct"
PROXY_OK=0

# ─── حالت ۱: پروکسی داخلی ───
if [ "$MODE" = "1" ]; then
    echo ""
    echo -e "${CYAN}راه‌اندازی SOCKS5 داخلی روی پورت ${SOCKS_PORT}...${NC}"
    python3 "$SCRIPT_DIR/builtin_proxy.py" "$SOCKS_PORT" > "$LOG_DIR/socks5.log" 2>&1 &
    SOCKS_PID=$!
    echo "$SOCKS_PID" > "$SOCKS_PID_FILE"
    sleep 1
    if kill -0 "$SOCKS_PID" 2>/dev/null; then
        echo -e "${GREEN}✅ SOCKS5 داخلی فعال — 127.0.0.1:${SOCKS_PORT}${NC}"
        PROXY_MODE="socks"
        PROXY_OK=1
    else
        echo -e "${RED}❌ خطا در راه‌اندازی پروکسی داخلی${NC}"
        cat "$LOG_DIR/socks5.log"
    fi

# ─── حالت ۲: لینک V2Ray ───
elif [ "$MODE" = "2" ]; then
    echo ""
    echo -e "${CYAN}لینک V2Ray را وارد کنید:${NC}"
    echo -e "(vmess:// | vless:// | trojan:// | ss://)"
    echo ""
    read -rp "لینک: " V2RAY_LINK

    if [ -z "$V2RAY_LINK" ]; then
        echo -e "${YELLOW}⚠️  لینک خالی — ادامه با اتصال مستقیم${NC}"
    else
        echo -e "${CYAN}در حال پارس لینک...${NC}"
        RESULT=$(python3 "$SCRIPT_DIR/v2ray_proxy.py" "$V2RAY_LINK" "$SOCKS_PORT" 2>&1)

        if echo "$RESULT" | grep -q "^ERR|"; then
            echo -e "${RED}❌ خطا: $(echo "$RESULT" | sed 's/^ERR|//')${NC}"
            echo -e "${YELLOW}ادامه با اتصال مستقیم${NC}"
        else
            PROTO=$(echo "$RESULT"  | cut -d'|' -f2)
            SERVER=$(echo "$RESULT" | cut -d'|' -f3)
            NAME=$(echo "$RESULT"   | cut -d'|' -f4)
            CFG_PATH=$(echo "$RESULT" | cut -d'|' -f5)

            # شناسایی باینری
            V2RAY_BIN=""
            for b in xray v2ray; do command -v $b &>/dev/null && V2RAY_BIN=$b && break; done

            if [ -z "$V2RAY_BIN" ]; then
                echo -e "${RED}❌ xray/v2ray نصب نیست — اجرا کنید: bash install_v2ray.sh${NC}"
            else
                "$V2RAY_BIN" run -config "$CFG_PATH" > "$LOG_DIR/v2ray.log" 2>&1 &
                V2RAY_PID=$!
                echo "$V2RAY_PID" > "$V2RAY_PID_FILE"
                sleep 2

                if kill -0 "$V2RAY_PID" 2>/dev/null; then
                    echo -e "${GREEN}✅ ${PROTO} فعال — ${NAME} — ${SERVER}${NC}"
                    PROXY_MODE="socks"
                    PROXY_OK=1
                else
                    echo -e "${RED}❌ V2Ray راه‌اندازی نشد:${NC}"
                    tail -5 "$LOG_DIR/v2ray.log"
                fi
            fi
        fi
    fi

# ─── حالت ۳: مستقیم ───
elif [ "$MODE" = "3" ]; then
    PROXY_MODE="direct"
    PROXY_OK=1
    echo -e "${CYAN}اتصال مستقیم انتخاب شد.${NC}"
fi

echo ""

# ── آدرس WiFi ──
LOCAL_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' | head -1)
[ -z "$LOCAL_IP" ] && LOCAL_IP="127.0.0.1"

echo -e "${YELLOW}┌──────────────────────────────────────────┐${NC}"
echo -e "${YELLOW}│  تنظیم WiFi گوشی:                        │${NC}"
echo -e "${YELLOW}│  پروکسی: دستی  آدرس: $LOCAL_IP       │${NC}"
echo -e "${YELLOW}│  پورت  : $MITM_PORT                          │${NC}"
echo -e "${YELLOW}└──────────────────────────────────────────┘${NC}"
echo ""
echo -e "${GREEN}▶ در حال ضبط... (Ctrl+C برای توقف)${NC}"
echo -e "${CYAN}────────────────────────────────────────────${NC}"

# ── اجرای mitmproxy ──
if [ "$PROXY_MODE" = "socks" ]; then
    mitmdump \
        --listen-host 0.0.0.0 \
        --listen-port "$MITM_PORT" \
        --mode "upstream:socks5h://127.0.0.1:${SOCKS_PORT}" \
        --script "$SCRIPT_DIR/shad_capture.py" \
        --ssl-insecure \
        --set flow_detail=1 \
        2>&1
else
    mitmdump \
        --listen-host 0.0.0.0 \
        --listen-port "$MITM_PORT" \
        --script "$SCRIPT_DIR/shad_capture.py" \
        --set flow_detail=1 \
        2>&1
fi
