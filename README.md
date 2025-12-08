# App Scan QR

A Flutter PWA that instantly opens the device camera, scans QR / barcode values, and pushes the result to a Google Spreadsheet via Google Apps Script.

## Fitur Utama

- Fokus pengalaman mobile dengan antarmuka kamera penuh.
- Menggunakan `mobile_scanner` yang mendukung Android, iOS, serta web (PWA) untuk akses kamera langsung di browser.
- Otomatis kirim hasil scan ke Google Sheets menggunakan endpoint Apps Script.
- Setelah kode terbaca, tombol **Submit** akan aktif sehingga operator bisa memastikan kode benar sebelum dikirim.
- Setelah tombol dikirim ditekan, antarmuka menampilkan status sukses dan riwayat log singkat sehingga operator tahu request terakhir berhasil/ gagal.
- Penjaga duplikasi sederhana supaya data tidak terkirim berkali-kali ketika kamera masih mengarah ke QR yang sama.

## Menyiapkan Google Apps Script

1. Buat Spreadsheet yang ingin Anda gunakan sebagai log.
2. Di menu **Extensions > Apps Script**, ganti kode default dengan contoh berikut:

   ```javascript
   const SHEET_ID = 'SPREADSHEET_ID_KAMU';
   const SHEET_NAME = 'Sheet1'; // ganti jika perlu

   function doPost(e) {
     const sheet = SpreadsheetApp.openById(SHEET_ID).getSheetByName(SHEET_NAME);
     const payload = e.parameter && Object.keys(e.parameter).length
       ? e.parameter
       : JSON.parse(e.postData.contents || '{}');
     sheet.appendRow([
       new Date(),
       payload.value || '',
       payload.scannedAt || '',
     ]);
     return ContentService
       .createTextOutput(JSON.stringify({ status: 'ok' }))
       .setMimeType(ContentService.MimeType.JSON)
       .setHeader('Access-Control-Allow-Origin', '*');
   }
   ```

3. Klik **Deploy > Test deployments > Web app**, pilih:
   - **Execute as**: *Me*
   - **Who has access**: *Anyone*
4. Salin URL Web App (`https://script.google.com/macros/s/.../exec`). Inilah nilai yang harus dimasukkan ke aplikasi.

## Menjalankan Aplikasi

Secara default, aplikasi sudah diarahkan ke Apps Script di tautan yang kamu berikan. Jika ingin memakai spreadsheet lain, isi nilai baru melalui `--dart-define` saat menjalankan Flutter.

```bash
flutter run -d chrome --web-renderer html \
  --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/.../exec
```

Untuk build PWA:

```bash
flutter build web --web-renderer html \
  --dart-define=APPS_SCRIPT_URL=https://script.google.com/macros/s/.../exec
```

> Catatan: Jika ingin mengganti URL permanen, ubah konstanta `kAppsScriptUrl` di `lib/main.dart`. Namun penggunaan `--dart-define` menjaga kode tetap aman di publik/repositori.

Saat aplikasi berjalan, arahkan kamera ke QR/barcode. Ketika kode berhasil terbaca, status akan berubah dan tombol Submit aktif. Tekan tombol tersebut agar data dikirim ke Google Sheet.

## Perizinan

- Android sudah ditambahkan `android.permission.CAMERA`.
- iOS memerlukan penjelasan kamera pada `Info.plist` (sudah di-set menjadi bahasa Indonesia).
- Browser akan memunculkan dialog permission saat pertama kali dijalankan; pastikan origin menggunakan HTTPS apabila di-deploy.

## Catatan Kompatibilitas

Versi terbaru aplikasi menggunakan `mobile_scanner` karena library sebelumnya (`qr_code_dart_scan`) mengandalkan mode live-stream `camera` yang tidak tersedia di Flutter Web sehingga menimbulkan error `defaultTargetPlatform == TargetPlatform.android || ... is not true`. Dengan `mobile_scanner`, mode live scanner kini berjalan di Chrome (PWA) maupun perangkat mobile. Pastikan menjalankan `flutter run -d chrome` agar origin tetap `http://localhost` sehingga kamera bisa dipakai.
