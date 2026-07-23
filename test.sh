#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — تست کامل
# ==============================

GREEN='\033[0;32m'
RED='\033[0;31m'
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check() {
    local name=$1
    local cmd=$2
    if eval "$cmd" &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $name"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}❌${NC} $name"
        FAIL=$((FAIL+1))
    fi
}

check_py() {
    local name=$1
    local code=$2
    if python3 -c "$code" &>/dev/null; then
        echo -e "  ${GREEN}✅${NC} $name"
        PASS=$((PASS+1))
    else
        echo -e "  ${RED}❌${NC} $name"
        FAIL=$((FAIL+1))
    fi
}

clear
echo -e "${CYAN}╔══════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║   🧪 تست کامل سیستم                      ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── تست ۱: ابزارها ──
echo -e "${CYAN}─ ابزارهای سیستم ─${NC}"
check "Python3 نصب است"     "command -v python3"
check "pip نصب است"          "command -v pip"
check "git نصب است"          "command -v git"
check "mitmdump نصب است"     "command -v mitmdump"
check "curl نصب است"         "command -v curl"
echo ""

# ── تست ۲: فایل‌های پروژه ──
echo -e "${CYAN}─ فایل‌های پروژه ─${NC}"
check "run.sh موجود است"              "[ -f '$SCRIPT_DIR/run.sh' ]"
check "install.sh موجود است"          "[ -f '$SCRIPT_DIR/install.sh' ]"
check "shad_capture.py موجود است"     "[ -f '$SCRIPT_DIR/shad_capture.py' ]"
check "builtin_proxy.py موجود است"    "[ -f '$SCRIPT_DIR/builtin_proxy.py' ]"
check "install_cert.sh موجود است"     "[ -f '$SCRIPT_DIR/install_cert.sh' ]"
check "setup_permission.sh موجود است" "[ -f '$SCRIPT_DIR/setup_permission.sh' ]"
check "export_links.sh موجود است"     "[ -f '$SCRIPT_DIR/export_links.sh' ]"
echo ""

# ── تست ۳: syntax پایتون ──
echo -e "${CYAN}─ صحت کدهای Python ─${NC}"
check "syntax: shad_capture.py"  "python3 -m py_compile '$SCRIPT_DIR/shad_capture.py'"
check "syntax: builtin_proxy.py" "python3 -m py_compile '$SCRIPT_DIR/builtin_proxy.py'"
echo ""

# ── تست ۴: syntax bash ──
echo -e "${CYAN}─ صحت اسکریپت‌های Bash ─${NC}"
check "syntax: run.sh"                "bash -n '$SCRIPT_DIR/run.sh'"
check "syntax: install.sh"            "bash -n '$SCRIPT_DIR/install.sh'"
check "syntax: install_cert.sh"       "bash -n '$SCRIPT_DIR/install_cert.sh'"
check "syntax: setup_permission.sh"   "bash -n '$SCRIPT_DIR/setup_permission.sh'"
check "syntax: export_links.sh"       "bash -n '$SCRIPT_DIR/export_links.sh'"
echo ""

# ── تست ۵: ماژول‌های پایتون ──
echo -e "${CYAN}─ ماژول‌های Python ─${NC}"
check_py "import socket"      "import socket"
check_py "import threading"   "import threading"
check_py "import select"      "import select"
check_py "import struct"      "import struct"
check_py "import re"          "import re"
check_py "import json"        "import json"
check_py "مitmproxy قابل import" "from mitmproxy import http"
echo ""

# ── تست ۶: SOCKS5 محلی ──
echo -e "${CYAN}─ تست پروکسی SOCKS5 ─${NC}"
python3 "$SCRIPT_DIR/builtin_proxy.py" 19999 &
SOCKS_PID=$!
sleep 1
if kill -0 "$SOCKS_PID" 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} SOCKS5 راه‌اندازی شد"
    PASS=$((PASS+1))
    kill "$SOCKS_PID" 2>/dev/null
else
    echo -e "  ${RED}❌${NC} SOCKS5 راه‌اندازی نشد"
    FAIL=$((FAIL+1))
fi
echo ""

# ── تست ۷: اینترنت ──
echo -e "${CYAN}─ اتصال اینترنت ─${NC}"
check "دسترسی به 8.8.8.8"     "ping -c 1 -W 3 8.8.8.8"
check "دسترسی به github.com"  "curl -s --max-time 5 https://github.com"
echo ""

# ── نتیجه ──
echo -e "${CYAN}════════════════════════════════════════════${NC}"
TOTAL=$((PASS+FAIL))
echo -e "نتیجه: ${GREEN}$PASS/$TOTAL موفق${NC}  |  ${RED}$FAIL ناموفق${NC}"
echo ""

if [ "$FAIL" -eq 0 ]; then
    echo -e "${GREEN}✅ همه تست‌ها پاس شدند — سیستم آماده است!${NC}"
    echo -e "   ${YELLOW}bash run.sh${NC}"
elif [ "$FAIL" -le 2 ]; then
    echo -e "${YELLOW}⚠️  چند مورد ناموفق — اما سیستم احتمالاً کار می‌کند${NC}"
    echo -e "   ${YELLOW}bash run.sh${NC}"
else
    echo -e "${RED}❌ مشکلات زیاد — ابتدا: ${YELLOW}bash install.sh${NC}"
fi
echo ""
