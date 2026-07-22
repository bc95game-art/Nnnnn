#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# Shad Link Extractor — نصب
# ==============================

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  Shad Link Extractor — نصب${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

echo -e "${YELLOW}[۱/۵] به‌روزرسانی پکیج‌ها...${NC}"
pkg update -y && pkg upgrade -y

echo -e "${YELLOW}[۲/۵] نصب Python و ابزارهای پایه...${NC}"
pkg install -y python python-pip openssl curl git

echo -e "${YELLOW}[۳/۵] دسترسی به فضای ذخیره‌سازی...${NC}"
termux-setup-storage || true
sleep 2

echo -e "${YELLOW}[۴/۵] نصب mitmproxy...${NC}"
pip install mitmproxy==10.3.1 --break-system-packages 2>/dev/null || pip install mitmproxy==10.3.1

echo -e "${YELLOW}[۵/۵] ساخت پوشه‌های لازم...${NC}"
mkdir -p ~/shad-extractor/logs

echo ""
echo -e "${GREEN}✅ نصب با موفقیت انجام شد!${NC}"
echo ""
echo -e "برای شروع بنویسید:"
echo -e "  ${YELLOW}bash run.sh${NC}"
