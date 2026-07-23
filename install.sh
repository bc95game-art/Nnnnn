#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — نصب
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Shad Link Extractor — نصب${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

echo -e "${YELLOW}[۱/۶] به‌روزرسانی پکیج‌ها...${NC}"
pkg update -y && pkg upgrade -y

echo -e "${YELLOW}[۲/۶] نصب ابزارهای پایه + Rust...${NC}"
pkg install -y python python-pip openssl curl git rust

echo -e "${YELLOW}[۳/۶] دسترسی به فضای ذخیره‌سازی...${NC}"
termux-setup-storage || true
sleep 2

echo -e "${YELLOW}[۴/۶] نصب mitmproxy...${NC}"
pip install mitmproxy --break-system-packages 2>/dev/null || pip install mitmproxy

echo -e "${YELLOW}[۵/۶] تست نصب...${NC}"
if ! command -v mitmdump &>/dev/null; then
    echo -e "${RED}❌ خطا در نصب mitmproxy${NC}"
    exit 1
fi

echo -e "${YELLOW}[۶/۶] ساخت پوشه‌های لازم...${NC}"
mkdir -p ~/shad-extractor/logs

echo ""
echo -e "${GREEN}✅ نصب با موفقیت انجام شد!${NC}"
echo ""
echo -e "قدم بعدی:"
echo -e "  ${YELLOW}bash install_cert.sh${NC}"
