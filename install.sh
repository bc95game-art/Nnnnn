#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — نصب کامل
# با مدیریت خطا و تست خودکار
# ==============================

set -euo pipefail

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
echo -e "${GREEN}║   Shad Link Extractor — نصب کامل        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── بررسی محیط ──
step "۱/۷" "بررسی محیط Termux"
[ -d "/data/data/com.termux" ] || err "این ابزار فقط در Termux اجرا می‌شود"
ok "Termux تشخیص داده شد"

# ── به‌روزرسانی ──
step "۲/۷" "به‌روزرسانی پکیج‌ها"
pkg update -y 2>/dev/null || warn "به‌روزرسانی با مشکل مواجه شد — ادامه می‌دهیم"
ok "به‌روزرسانی انجام شد"

# ── ابزارهای پایه ──
step "۳/۷" "نصب ابزارهای پایه"
PKGS="python python-pip openssl curl git"
for pkg_name in $PKGS; do
    if ! pkg list-installed 2>/dev/null | grep -q "^$pkg_name"; then
        pkg install -y "$pkg_name" 2>/dev/null || warn "$pkg_name نصب نشد"
    fi
done
ok "ابزارهای پایه نصب شدند"

# ── Rust ──
step "۴/۷" "بررسی و نصب Rust"
if ! command -v rustc &>/dev/null; then
    echo "   نصب Rust (ممکن است چند دقیقه طول بکشد)..."
    pkg install -y rust 2>/dev/null || warn "Rust از pkg نصب نشد — تلاش با روش دیگر"
fi

if command -v rustc &>/dev/null; then
    ok "Rust نصب است: $(rustc --version 2>/dev/null)"
else
    warn "Rust یافت نشد — نصب mitmproxy ممکن است با خطا مواجه شود"
fi

# ── دسترسی به فایل‌ها ──
step "۵/۷" "دسترسی به فضای ذخیره‌سازی"
if [ ! -d "$HOME/storage/downloads" ]; then
    termux-setup-storage || warn "دسترسی به ذخیره‌سازی داده نشد — بعداً انجام دهید"
    sleep 2
fi
ok "دسترسی به فضای ذخیره‌سازی"

# ── mitmproxy ──
step "۶/۷" "نصب mitmproxy"
if command -v mitmdump &>/dev/null; then
    ok "mitmproxy از قبل نصب است: $(mitmdump --version 2>/dev/null | head -1)"
else
    echo "   در حال نصب mitmproxy (ممکن است ۱۰-۲۰ دقیقه طول بکشد)..."
    
    # تلاش ۱: نصب معمولی
    if pip install mitmproxy --break-system-packages 2>/dev/null; then
        ok "mitmproxy نصب شد"
    # تلاش ۲: بدون break-system-packages
    elif pip install mitmproxy 2>/dev/null; then
        ok "mitmproxy نصب شد"
    # تلاش ۳: نسخه قدیمی‌تر که Rust نیاز ندارد
    elif pip install "mitmproxy==9.0.1" --break-system-packages 2>/dev/null; then
        ok "mitmproxy 9.0.1 نصب شد"
    else
        err "نصب mitmproxy شکست خورد. اینترنت را بررسی کنید و دوباره اجرا کنید."
    fi
fi

# ── ساخت پوشه‌ها ──
step "۷/۷" "ساخت پوشه‌های لازم"
mkdir -p ~/shad-extractor/logs
ok "پوشه‌ها ساخته شدند"

# ── تست نهایی ──
echo ""
echo -e "${CYAN}────────────────────────────────────${NC}"
echo -e "${CYAN}تست نهایی:${NC}"

PASS=0
FAIL=0

check() {
    if eval "$2" &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $1"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}❌${NC} $1"
        FAIL=$((FAIL+1))
    fi
}

check "Python نصب است"   "command -v python3"
check "pip نصب است"      "command -v pip"
check "git نصب است"      "command -v git"
check "mitmproxy نصب است" "command -v mitmdump"
check "پوشه logs موجود است" "[ -d '$HOME/shad-extractor/logs' ]"
check "فایل run.sh موجود است" "[ -f 'run.sh' ]"
check "فایل shad_capture.py موجود است" "[ -f 'shad_capture.py' ]"
check "فایل builtin_proxy.py موجود است" "[ -f 'builtin_proxy.py' ]"

echo ""
echo -e "${CYAN}────────────────────────────────────${NC}"
echo -e "نتیجه: ${GREEN}$PASS موفق${NC} | ${RED}$FAIL ناموفق${NC}"

if [ "$FAIL" -eq 0 ]; then
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ نصب کامل شد!                        ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "قدم بعدی:"
    echo -e "  ${YELLOW}bash install_cert.sh${NC}"
else
    echo ""
    warn "برخی موارد نصب نشدند — دوباره bash install.sh را اجرا کنید"
fi
