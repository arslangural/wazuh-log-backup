# Wazuh Log Backup, Signature & Timestamp Script

Bu bash scripti, Wazuh loglarını imzalar, zaman damgası ekler ve QNAP NAS cihazına yedekler. Ayrıca yedekleme raporunu ve yeni logları e-posta ile bildirir.

---

## 🚀 Özellikler

- `alerts` ve `archives` loglarını işler
- Her logu `openssl` ile imzalar
- [FreeTSA.org](https://freetsa.org/) üzerinden zaman damgası uygular
- İmzalanmış ve orijinal logları yıl/ay bazında NAS'a yedekler
- Daha önce yedeklenenleri algılayarak sadece **yeni dosyaları** tespit eder
- E-posta ile yedekleme raporunu ve yeni log arşivini gönderir

---

## 🔧 Gereksinimler

- Linux (tested on Ubuntu)
- `openssl`, `rsync`, `mailutils`, `curl`
- Wazuh sunucusunda aktif loglar
- Mount edilmiş bir NAS dizini ("/mnt/qnap_logs")

---

## 💩 Kurulum

1. Scripti uygun bir yere kaydet:
   ```bash
   sudo nano /usr/local/bin/sign_and_backup_logs.sh
   ```
2. Çalıştırılabilir yap:
   ```bash
   sudo chmod +x /usr/local/bin/sign_and_backup_logs.sh
   ```
3. NAS mount ayarlarını yap (CIFS için `/etc/fstab` ya da manuel mount)

---

## 🕒 Otomatikleştirme

`crontab` ile günlük otomatik çalıştırmak için:
```bash
sudo crontab -e
```

Ve şunu ekleyin:
```cron
0 2 * * * /usr/local/bin/sign_and_backup_logs.sh
```

---

## 📩 E-Posta Ayarları

Script içinde şu satırı güncelleyin:
```bash
MAIL_TO="your.email@example.com"
```

Postfix, ssmtp ya da başka bir MTA ile `mail` komutunun çalışır olması gerekir.

Test etmek için:
```bash
echo "test" | mail -s "Test Mail" your.email@example.com
```

---

## 📁 Dizin Yapısı

```bash
/var/ossec/logs/alerts/
/var/ossec/logs/archives/
/var/log/signed_logs/YYYY/Mon/
/mnt/qnap_logs/original_logs/YYYY/Mon/
/mnt/qnap_logs/signed_logs/YYYY/Mon/
```

---

## 📄 Raporlama

Script sonunda `/tmp/backup_report_*.txt` şeklinde bir rapor oluşur. Örnek:

```
Wazuh Backup Report - Mon Feb 26 03:00:02 UTC 2025
=========================================
Toplam önceki dosya sayısı: 120
Yeni eklenen dosya sayısı: 5
Atlanan dosya sayısı: 115
Toplam mevcut dosya sayısı: 125

Yeni eklenen dosyalar:
-----------------------------------------
archives.log_20250226_030001.sig
archives.log_20250226_030001.tsr
...
```

---

## 📜 Lisans

MIT License

---

**Not:** E-posta içeriği ve NAS mount bilgileri güvenlik için ornek olarak bırakılmıştır. Gerçek sistemlerinizde uygun önlemleri almayı unutmayın.

