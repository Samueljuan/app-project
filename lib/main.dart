import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mobile_scanner/mobile_scanner.dart';

const String kAppsScriptUrl = String.fromEnvironment(
  'APPS_SCRIPT_URL',
  defaultValue:
      'https://script.google.com/macros/s/AKfycbyTotultHxmHdfqN5pa6PVrwI7FKM-4wrUsjDo37L0QEMRjWZUXxYDbcZhOESKxOmTpbQ/exec',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ScanApp());
}

class ScanApp extends StatelessWidget {
  const ScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF00D084),
      brightness: Brightness.dark,
    );
    return MaterialApp(
      title: 'Scan QR',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: const Color(0xFF050A11),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const ScannerPage(),
    );
  }
}

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    formats: const [
      BarcodeFormat.qrCode,
      BarcodeFormat.aztec,
      BarcodeFormat.dataMatrix,
      BarcodeFormat.pdf417,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.code128,
      BarcodeFormat.ean8,
      BarcodeFormat.ean13,
    ],
  );
  bool _isSending = false;
  String _statusMessage = 'Arahkan kamera ke QR / barcode';
  String? _pendingValue;
  String? _lastValue;
  String? _pendingFormat;
  bool _showSuccess = false;
  final List<String> _logs = <String>[];

  bool get _canSubmit => !_isSending && _pendingValue != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleCapture(BarcodeCapture capture) {
    final Barcode validBarcode = capture.barcodes.firstWhere(
      (barcode) => (barcode.rawValue?.trim().isNotEmpty ?? false),
      orElse: () => capture.barcodes.isNotEmpty
          ? capture.barcodes.first
          : Barcode(rawValue: ''),
    );
    final code = validBarcode.rawValue?.trim() ?? '';
    if (code.isEmpty) {
      return;
    }

    setState(() {
      _pendingValue = code;
      _pendingFormat = validBarcode.format.name;
      _showSuccess = false;
      _statusMessage = 'Kode terbaca. Tekan Submit untuk mengirim.';
    });
  }

  Future<void> _submitScan() async {
    final code = _pendingValue;
    if (code == null) return;

    final now = DateTime.now();

    setState(() {
      _isSending = true;
      _showSuccess = false;
      _statusMessage = 'Mengirim ke spreadsheet...';
    });

    try {
      await _sendToSpreadsheet(code, now);
      if (!mounted) return;
      setState(() {
        _lastValue = code;
        _pendingValue = null;
        _pendingFormat = null;
        _showSuccess = true;
        _statusMessage = 'Terkirim: $code';
      });
      _appendLog('Berhasil kirim: $code');
    } catch (error) {
      final message = 'Gagal mengirim: $error';
      if (!mounted) return;
      setState(() {
        _statusMessage = message;
        _showSuccess = false;
      });
      _appendLog(message);
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _appendLog(String message) {
    final timestamp = DateTime.now()
        .toLocal()
        .toIso8601String()
        .split('.')
        .first;
    setState(() {
      _logs.insert(0, '[$timestamp] $message');
      if (_logs.length > 20) {
        _logs.removeRange(20, _logs.length);
      }
    });
  }

  Future<void> _sendToSpreadsheet(String code, DateTime scannedAt) async {
    final url = kAppsScriptUrl.trim();
    if (url.isEmpty) {
      throw 'Isi kAppsScriptUrl dengan URL Apps Script milikmu';
    }

    final response = await http.post(
      Uri.parse(url),
      body: {'value': code, 'scannedAt': scannedAt.toUtc().toIso8601String()},
    );

    if (response.statusCode >= 400) {
      throw 'Server mengembalikan kode ${response.statusCode} (${response.body})';
    }

    if (response.body.isNotEmpty) {
      _appendLog('Respons server: ${response.body}');
    }
  }

  Widget _buildSubmitButton() {
    final pendingText = _pendingValue;
    final label = _isSending
        ? 'Mengirim data...'
        : pendingText == null
        ? 'Scan kode terlebih dahulu'
        : 'Submit ke Google Sheet';

    final leading = _isSending
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            pendingText == null ? Icons.qr_code_scanner : Icons.upload_rounded,
          );

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _canSubmit ? _submitScan : null,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            leading,
            const SizedBox(width: 12),
            Flexible(child: Text(label, textAlign: TextAlign.center)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF02050B), Color(0xFF051322), Color(0xFF010C16)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              children: [
                const _Header(),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(28),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            MobileScanner(
                              controller: _controller,
                              fit: BoxFit.cover,
                              onDetect: _handleCapture,
                              errorBuilder: (context, error) => _CameraError(
                                errorMessage: error.errorCode.name,
                              ),
                              placeholderBuilder: (context) => const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                            const _ScannerOverlay(),
                            if (_isSending)
                              Container(
                                color: Colors.black45,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _StatusCard(
                  message: _statusMessage,
                  latestValue: _lastValue,
                  pendingValue: _pendingValue,
                  pendingFormat: _pendingFormat,
                  showSuccess: _showSuccess,
                ),
                const SizedBox(height: 12),
                _buildSubmitButton(),
                const SizedBox(height: 12),
                _LogPanel(entries: _logs),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      children: [
        Text(
          'PWA QR Scanner',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Setelah kode terbaca, tekan Submit untuk mengirimnya ke Google Sheet.',
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String message;
  final String? latestValue;
  final String? pendingValue;
  final String? pendingFormat;
  final bool showSuccess;
  const _StatusCard({
    required this.message,
    required this.latestValue,
    required this.pendingValue,
    required this.pendingFormat,
    required this.showSuccess,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (pendingValue != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.qr_code, size: 16, color: Colors.white70),
                const SizedBox(width: 6),
                Text(
                  pendingFormat ?? 'Format tidak diketahui',
                  style: textTheme.labelSmall?.copyWith(color: Colors.white70),
                ),
                const Spacer(),
                if (showSuccess)
                  const Icon(Icons.check_circle, color: Colors.greenAccent),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Siap dikirim:',
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
            Text(
              pendingValue!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
          if (latestValue != null) ...[
            const SizedBox(height: 8),
            Text(
              'Terakhir:',
              style: textTheme.labelSmall?.copyWith(color: Colors.white54),
            ),
            Text(
              latestValue!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium,
            ),
          ],
        ],
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  final String errorMessage;
  const _CameraError({required this.errorMessage});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                'Kamera tidak bisa dibuka ($errorMessage)',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 4),
              const Text(
                'Pastikan izin kamera diberikan dan jalankan ulang aplikasinya.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogPanel extends StatelessWidget {
  final List<String> entries;
  const _LogPanel({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Log Pengiriman', style: textTheme.labelLarge),
          const SizedBox(height: 8),
          for (final entry in entries.take(4))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                entry,
                style: textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  const _ScannerOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.transparent, Colors.transparent, Colors.black38],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.8),
                width: 2,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black38,
                  blurRadius: 20,
                  spreadRadius: 4,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
