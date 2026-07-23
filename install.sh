#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — نصب کامل
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

ok()   { echo -e "${GREEN}   ✅ $1${NC}"; }
warn() { echo -e "${YELLOW}   ⚠️  $1${NC}"; }
err()  { echo -e "${RED}   ❌ $1${NC}"; exit 1; }
step() { echo -e "\n${CYAN}[$1] $2...${NC}"; }

clear
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Shad Link Extractor — نصب              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

step "۱/۵" "بررسی محیط"
[ -d "/data/data/com.termux" ] || err "فقط در Termux اجرا کنید"
ok "Termux تشخیص داده شد"

step "۲/۵" "به‌روزرسانی و ابزارهای پایه"
pkg update -y 2>/dev/null || warn "به‌روزرسانی با مشکل — ادامه می‌دهیم"
pkg install -y python python-pip openssl curl git 2>/dev/null
ok "ابزارهای پایه آماده"

step "۳/۵" "دسترسی به فضای ذخیره‌سازی"
termux-setup-storage 2>/dev/null || true
sleep 2
ok "دسترسی به فضای ذخیره‌سازی"

step "۴/۵" "نصب mitmproxy"

# حذف نسخه ناسازگار
pip uninstall -y mitmproxy mitmproxy-rs 2>/dev/null || true

# تست سازگاری Python
PY_VER=$(python3 -c "import sys; print(sys.version_info.minor)")
echo "   Python 3.$PY_VER تشخیص داده شد"

install_mitm() {
    local ver=$1
    echo "   تلاش با mitmproxy $ver ..."
    if pip install "mitmproxy==$ver" --break-system-packages -q 2>/dev/null; then
        # تست واقعی
        if python3 -c "from mitmproxy.tools.main import mitmdump" 2>/dev/null; then
            ok "mitmproxy $ver نصب و تست شد"
            return 0
        fi
        pip uninstall -y mitmproxy 2>/dev/null || true
    fi
    return 1
}

if command -v mitmdump &>/dev/null && python3 -c "from mitmproxy.tools.main import mitmdump" 2>/dev/null; then
    ok "mitmproxy از قبل سالم نصب است"
else
    # نسخه‌ها به ترتیب اولویت — از قدیمی به جدید
    INSTALLED=0
    for VER in "8.1.1" "9.0.1" "10.1.6" "10.2.4" "10.3.1"; do
        if install_mitm "$VER"; then
            INSTALLED=1
            break
        fi
    done
    [ "$INSTALLED" = "0" ] && err "نصب mitmproxy شکست خورد — اینترنت را بررسی کنید"
fi

step "۵/۵" "ساخت پوشه‌ها"
mkdir -p ~/shad-extractor/logs
ok "پوشه‌ها آماده"

# ── تست نهایی ──
echo ""
echo -e "${CYAN}────────────────────────────────────${NC}"
echo -e "${CYAN}تست نهایی:${NC}"

PASS=0; FAIL=0
check() {
    if eval "$2" &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $1"; PASS=$((PASS+1))
    else
        echo -e "  ${RED}❌${NC} $1"; FAIL=$((FAIL+1))
    fi
}

check "Python3"                    "command -v python3"
check "mitmdump"                   "command -v mitmdump"
check "mitmproxy قابل import"      "python3 -c 'from mitmproxy.tools.main import mitmdump'"
check "shad_capture.py"            "[ -f 'shad_capture.py' ]"
check "builtin_proxy.py"           "[ -f 'builtin_proxy.py' ]"
check "پوشه logs"                  "[ -d '$HOME/shad-extractor/logs' ]"

echo ""
echo -e "نتیجه: ${GREEN}$PASS موفق${NC} | ${RED}$FAIL ناموفق${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✅ نصب کامل شد!${NC}"
    echo -e "قدم بعدی: ${YELLOW}bash install_cert.sh${NC}"
else
    echo ""
    warn "دوباره bash install.sh را اجرا کنید"
fi
