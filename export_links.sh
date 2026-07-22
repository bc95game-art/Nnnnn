#!/data/data/com.termux/files/usr/bin/bash
# ==============================
# خروجی گرفتن لینک‌ها
# ==============================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

LOG_DIR="$HOME/shad-extractor/logs"
LINKS_FILE="$LOG_DIR/links_only.txt"
DATE=$(date +"%Y%m%d_%H%M%S")
DOWNLOAD_DIR="$HOME/storage/downloads"
EXPORT_FILE="$DOWNLOAD_DIR/shad_links_$DATE.txt"

echo -e "${GREEN}=====================================${NC}"
echo -e "${GREEN}  خروجی لینک‌های شاد${NC}"
echo -e "${GREEN}=====================================${NC}"
echo ""

if [ ! -f "$LINKS_FILE" ]; then
    echo -e "${RED}❌ هنوز هیچ لینکی ضبط نشده.${NC}"
    echo -e "ابتدا ${YELLOW}bash run.sh${NC} را اجرا کنید و از شاد استفاده کنید."
    exit 1
fi

COUNT=$(wc -l < "$LINKS_FILE")
echo -e "${CYAN}📊 تعداد لینک‌های ضبط‌شده: ${YELLOW}$COUNT${NC}"
echo ""

echo -e "${CYAN}🔗 لینک‌های منحصربه‌فرد:${NC}"
echo -e "${CYAN}─────────────────────────────────────${NC}"

# نمایش لینک‌های منحصربه‌فرد
sort -u "$LINKS_FILE" | grep -oP 'https?://\S+|[a-zA-Z][a-zA-Z0-9+\-.]*://\S+' | while read -r link; do
    echo -e "  ${GREEN}▸${NC} $link"
done

echo ""
echo -e "${CYAN}─────────────────────────────────────${NC}"

# ذخیره خروجی تمیز در دانلودها
{
    echo "====================================="
    echo "  Shad Link Extractor — خروجی لینک"
    echo "  تاریخ: $(date)"
    echo "====================================="
    echo ""
    echo "--- لینک‌های منحصربه‌فرد ---"
    sort -u "$LINKS_FILE" | grep -oP 'https?://\S+|[a-zA-Z][a-zA-Z0-9+\-.]*://\S+'
    echo ""
    echo "--- لاگ کامل ---"
    cat "$LINKS_FILE"
} > "$EXPORT_FILE"

echo -e "${GREEN}✅ فایل خروجی ذخیره شد:${NC}"
echo -e "   ${YELLOW}$EXPORT_FILE${NC}"
echo ""
echo -e "${CYAN}گزینه‌ها:${NC}"
echo -e "  ${YELLOW}[1]${NC} پاک کردن لاگ‌ها برای شروع دوباره"
echo -e "  ${YELLOW}[2]${NC} خروج"
echo ""
read -rp "انتخاب کنید [1/2]: " choice

case "$choice" in
    1)
        rm -f "$LINKS_FILE" "$LOG_DIR/captured.log"
        echo -e "${GREEN}✅ لاگ‌ها پاک شدند.${NC}"
        ;;
    *)
        echo -e "خروج..."
        ;;
esac
