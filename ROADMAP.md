# Roadmap & Technical Notes

Dokumen ini berisi rencana pengembangan lanjutan agar mudah dieksekusi kapan pun dibutuhkan.

## 1. Apps Script Health Check
- **Tujuan:** Memberi tahu operator sejak awal bila endpoint Apps Script bermasalah.
- **Teknis singkat:**
  - Tambahkan GET ringan (`http.get(kAppsScriptUrl)`) saat app start dan bisa diulang via `Timer.periodic`.
  - Jika gagal (timeout atau status kode >=400), tampilkan banner/peringatan di status card, nonaktifkan tombol Submit sementara, dan arahkan operator untuk cek koneksi atau Apps Script.
  - Pastikan `doGet` di `code.gs` mengembalikan respons JSON sederhana agar health check murah.

## 2. Offline Queue & Retry
- **Tujuan:** Data scan tidak hilang ketika jaringan putus.
- **Teknis singkat:**
  - Buat model `PendingScan` (value, timestamp).
  - Saat `_sendToSpreadsheet` gagal karena `ClientException`/timeout, simpan payload ke `SharedPreferences` (mis. `pending_scans` berformat JSON list).
  - Tambah loop retry (timer atau saat app kembali online) yang memanggil `_sendToSpreadsheet` ulang untuk setiap item antrian; hapus dari storage setelah sukses.
  - Bisa tampilkan jumlah antrian di UI agar operator tahu ada data yang menunggu.

## 3. Operator Feedback Improvements
- **Tujuan:** Memberikan kepastian hasil kirim dan alat diagnostik manual.
- **Teknis singkat:**
  - Simpan “last successful submission” (value + waktu) di `SharedPreferences` dan tampilkan pada kartu khusus.
  - Tambah tombol “Tes Koneksi” yang memanggil health check + coba POST dummy (tanpa menulis ke sheet) agar operator bisa memverifikasi endpoint dan kredensial.
  - Pertimbangkan field catatan opsional sebelum submit untuk membantu penelusuran.

## 4. Telemetry / Server-side Logs
- **Tujuan:** Memiliki audit trail di luar log UI.
- **Teknis singkat:**
  - Perluas `code.gs` agar menambah kolom status/error, atau buat endpoint baru yang menyimpan JSON log (mis. sheet lain).
  - Dari Flutter, kirim metadata tambahan (device, session ID, latency) bersamaan dengan setiap submit. Jika gagal, kirim log terpisah setelah menampilkan error.
  - Nantinya mudah diintegrasi dengan layanan monitoring (Supabase, BigQuery, dsb.) tanpa mengubah client secara besar.

Gunakan file ini sebagai daftar kerja ketika mulai mengimplementasikan masing-masing fitur. Update catatan ini setelah ada keputusan teknis atau perubahan arsitektur.
