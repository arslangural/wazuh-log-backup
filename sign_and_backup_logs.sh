#!/bin/bash

# Log dosyasını tanımla ve oluştur
LOGFILE="/var/log/sign_and_backup_logs.log"
touch "$LOGFILE"
exec > >(tee -a "$LOGFILE") 2>&1

# Wazuh log dizinleri
LOG_DIRS=(
    "/var/ossec/logs/alerts"
    "/var/ossec/logs/archives"
)

SIGNED_DIR="/var/log/signed_logs"
QNAP_DIR="/mnt/qnap_logs"
KEY_DIR="/etc/wazuh-keys"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
YEAR=$(date +%Y)
MONTH=$(date +%b)

MAIL_TO="your.email@example.com"
SUBJECT="Wazuh Backup Completed on $(hostname) - New Logs Attached"
MAIL_FROM="wazuh@example.com"

# NAS bağlı mı kontrol et
if ! mount | grep -q "$QNAP_DIR"; then
    echo "Error: NAS ($QNAP_DIR) is not mounted!"
    exit 1
fi

# Önceki NAS dosya listesini al
PREV_FILE_LIST="/var/log/prev_backup_files.txt"
NEW_FILE_LIST="/var/log/new_backup_files.txt"
DIFF_FILE_LIST="/var/log/diff_backup_files.txt"
mkdir -p "$QNAP_DIR/signed_logs/$YEAR/$MONTH"
ls -1 "$QNAP_DIR/signed_logs/$YEAR/$MONTH" > "$PREV_FILE_LIST"

# Her log dizinini işle
for LOG_DIR in "${LOG_DIRS[@]}"; do
    echo "Processing logs in $LOG_DIR..."
    find "$LOG_DIR" -type f | while read -r file; do
        if [[ -f "$file" ]]; then
            RELATIVE_PATH=$(realpath --relative-to="$LOG_DIR" "$file")
            BASENAME=$(basename "$file")

            SIGNATURE_FILE="$SIGNED_DIR/$YEAR/$MONTH/${RELATIVE_PATH}_$TIMESTAMP.sig"
            TIMESTAMP_FILE="$SIGNED_DIR/$YEAR/$MONTH/${RELATIVE_PATH}_$TIMESTAMP.tsr"

            if [[ -f "$SIGNATURE_FILE" ]]; then
                echo "Signature already exists for $file, skipping..."
                continue
            fi

            mkdir -p "$(dirname "$SIGNATURE_FILE")"
            openssl dgst -sha256 -sign "$KEY_DIR/privatekey.pem" -out "$SIGNATURE_FILE" "$file"
            echo "Signed: $file -> $SIGNATURE_FILE"

            curl -s -H "Content-Type: application/timestamp-query" \
                 --data-binary @"$SIGNATURE_FILE" \
                 https://freetsa.org/tsr > "$TIMESTAMP_FILE"

            if [[ ! -s "$TIMESTAMP_FILE" ]]; then
                echo "Timestamp request failed for $SIGNATURE_FILE!" | tee -a "$LOGFILE"
            fi
        fi
    done

    # QNAP Üzerinde Orijinal Logları Yedekleme
    mkdir -p "$QNAP_DIR/original_logs/$YEAR/$MONTH/"
    rsync -av --ignore-existing "$LOG_DIR/" "$QNAP_DIR/original_logs/$YEAR/$MONTH/"

done

# QNAP Üzerinde İmzalanmış Logları Yedekleme
mkdir -p "$QNAP_DIR/signed_logs/$YEAR/$MONTH/"
rsync -av --ignore-existing "$SIGNED_DIR/$YEAR/$MONTH/" "$QNAP_DIR/signed_logs/$YEAR/$MONTH/"

# Yeni eklenen dosyaları belirle
ls -1 "$QNAP_DIR/signed_logs/$YEAR/$MONTH/" > "$NEW_FILE_LIST"
comm -13 "$PREV_FILE_LIST" "$NEW_FILE_LIST" > "$DIFF_FILE_LIST"

if ! command -v mail &> /dev/null; then
    echo "Error: mail command not found! Please install mailutils." | tee -a "$LOGFILE"
    exit 1
fi

# Yeni eklenen dosya sayısını hesapla
NEW_FILES_COUNT=$(wc -l < "$DIFF_FILE_LIST")
TOTAL_FILES_BEFORE=$(wc -l < "$PREV_FILE_LIST")
TOTAL_FILES_AFTER=$(wc -l < "$NEW_FILE_LIST")
SKIPPED_FILES=$((TOTAL_FILES_BEFORE - NEW_FILES_COUNT))

# E-posta raporu oluştur
REPORT_FILE="/tmp/backup_report_$TIMESTAMP.txt"
echo "Wazuh Backup Report - $(date)" > "$REPORT_FILE"
echo "=========================================" >> "$REPORT_FILE"
echo "Toplam önceki dosya sayısı: $TOTAL_FILES_BEFORE" >> "$REPORT_FILE"
echo "Yeni eklenen dosya sayısı: $NEW_FILES_COUNT" >> "$REPORT_FILE"
echo "Atlanan dosya sayısı: $SKIPPED_FILES" >> "$REPORT_FILE"
echo "Toplam mevcut dosya sayısı: $TOTAL_FILES_AFTER" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"
echo "Yeni eklenen dosyalar:" >> "$REPORT_FILE"
echo "-----------------------------------------" >> "$REPORT_FILE"
cat "$DIFF_FILE_LIST" >> "$REPORT_FILE"
echo "" >> "$REPORT_FILE"

if [ -s "$DIFF_FILE_LIST" ]; then
    TAR_FILE="/tmp/new_logs_$TIMESTAMP.tar.gz"
    tar -czf "$TAR_FILE" -T "$DIFF_FILE_LIST"

    mail -s "$SUBJECT" -a "$TAR_FILE" -a "$REPORT_FILE" "$MAIL_TO" < "$REPORT_FILE"
    echo "Backup report and new logs emailed successfully."
else
    echo "No new files to email. Report sent only."
    mail -s "Wazuh Backup Report - No New Files" "$MAIL_TO" < "$REPORT_FILE"
fi
