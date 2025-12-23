import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class Header extends StatelessWidget {
  const Header({super.key});

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

class StatusCard extends StatelessWidget {
  final String message;
  final String? latestValue;
  final String? pendingValue;
  final String? pendingFormat;
  final bool showSuccess;
  const StatusCard({
    super.key,
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

class CameraError extends StatelessWidget {
  final String errorMessage;
  const CameraError({super.key, required this.errorMessage});

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

class ScannerContent extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onCapture;
  final bool isSending;
  final String statusMessage;
  final String? lastValue;
  final String? pendingValue;
  final String? pendingFormat;
  final bool showSuccess;
  final Widget submitButton;
  final List<String> logs;
  final bool cameraActive;
  final String? cameraError;
  final VoidCallback onRequestCamera;
  final bool cameraPromptDismissed;
  const ScannerContent({
    super.key,
    required this.controller,
    required this.onCapture,
    required this.isSending,
    required this.statusMessage,
    required this.lastValue,
    required this.pendingValue,
    required this.pendingFormat,
    required this.showSuccess,
    required this.submitButton,
    required this.logs,
    required this.cameraActive,
    required this.cameraError,
    required this.onRequestCamera,
    required this.cameraPromptDismissed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Header(),
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
                      controller: controller,
                      fit: BoxFit.cover,
                      onDetect: onCapture,
                      errorBuilder: (context, error) =>
                          CameraError(errorMessage: error.errorCode.name),
                      placeholderBuilder: (context) =>
                          const Center(child: CircularProgressIndicator()),
                    ),
                    const ScannerOverlay(),
                    if (!cameraActive && !cameraPromptDismissed)
                      Container(
                        color: Colors.black54,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Kamera tidak aktif',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (cameraError != null) ...[
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                  ),
                                  child: Text(
                                    cameraError!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                const SizedBox(height: 8),
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 24),
                                  child: Text(
                                    'Tekan tombol di bawah untuk menyalakan kamera.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: onRequestCamera,
                                child: const Text('Aktifkan Kamera'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (isSending)
                      Container(
                        color: Colors.black45,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        StatusCard(
          message: statusMessage,
          latestValue: lastValue,
          pendingValue: pendingValue,
          pendingFormat: pendingFormat,
          showSuccess: showSuccess,
        ),
        const SizedBox(height: 12),
        submitButton,
        const SizedBox(height: 12),
        LogPanel(entries: logs),
        const SizedBox(height: 12),
      ],
    );
  }
}

class LogPanel extends StatelessWidget {
  final List<String> entries;
  const LogPanel({super.key, required this.entries});

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
          Text(
            entries.first,
            style: textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class ScannerOverlay extends StatelessWidget {
  const ScannerOverlay({super.key});

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
