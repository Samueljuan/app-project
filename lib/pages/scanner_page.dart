import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'package:app_scan_qr/services/auth_service.dart';
import 'package:app_scan_qr/services/spreadsheet_service.dart';
import 'package:app_scan_qr/widgets/login_form.dart';
import 'package:app_scan_qr/widgets/scanner_widgets.dart';

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key});

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> with WidgetsBindingObserver {
  static const String _defaultStatusMessage =
      'Arahkan kamera ke QR / barcode';

  late final AuthService _authService;
  late final SpreadsheetService _spreadsheetService;

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
  String _statusMessage = _defaultStatusMessage;
  String? _pendingValue;
  String? _lastValue;
  String? _pendingFormat;
  bool _showSuccess = false;
  final List<String> _logs = <String>[];
  bool _authenticated = false;
  bool _sessionChecked = false;
  bool _isAuthenticating = false;
  String? _authError;
  bool _showPassword = false;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  Timer? _statusResetTimer;
  Timer? _authErrorTimer;
  String? _lastAuthAttempt;
  bool _cameraActive = false;
  String? _cameraError;
  bool _cameraPromptDismissed = false;

  bool get _canSubmit => !_isSending && _pendingValue != null;

  @override
  void initState() {
    super.initState();
    _authService = AuthService();
    _spreadsheetService = SpreadsheetService(onLog: _appendLog);
    WidgetsBinding.instance.addObserver(this);
    _restoreSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _spreadsheetService.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _statusResetTimer?.cancel();
    _authErrorTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _pauseCamera();
    } else if (state == AppLifecycleState.resumed) {
      _resumeCamera();
    }
    super.didChangeAppLifecycleState(state);
  }

  Future<void> _restoreSession() async {
    final authenticated = await _authService.restoreSession();
    if (!mounted) return;
    setState(() {
      _authenticated = authenticated;
      _sessionChecked = true;
      if (_authenticated) {
        _cameraPromptDismissed = false;
        _cameraActive = false;
      }
    });
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
      _scheduleStatusReset(duration: const Duration(seconds: 2));
    } catch (error) {
      final message = 'Gagal mengirim: $error';
      if (!mounted) return;
      setState(() {
        _statusMessage = message;
        _showSuccess = false;
        _pendingValue = null;
        _pendingFormat = null;
      });
      _appendLog(message);
      _scheduleStatusReset();
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
      _logs
        ..clear()
        ..add('[$timestamp] $message');
    });
  }

  Future<void> _handleLogin() async {
    if (!_authService.credentialsConfigured) {
      setState(() {
        _authError =
            'LOGIN_USERNAME dan LOGIN_PASSWORD belum dikonfigurasi. '
            'Isi keduanya via --dart-define atau environment variable.';
      });
      _scheduleAuthErrorClear();
      return;
    }
    setState(() {
      _isAuthenticating = true;
      _authError = null;
    });
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    _lastAuthAttempt =
        'Login attempt: user="$username", password="${_authService.maskPassword(password)}"';

    final credentialsMatch = _authService.verifyCredentials(
      username: username,
      password: password,
    );
    if (!credentialsMatch) {
      setState(() {
        _authError = 'Username atau password salah.';
        _isAuthenticating = false;
      });
      _scheduleAuthErrorClear();
      return;
    }

    await _authService.persistSession();
    if (!mounted) return;
    setState(() {
      _authenticated = true;
      _isAuthenticating = false;
      _authError = null;
      _cameraPromptDismissed = false;
      _cameraActive = false;
    });
    _usernameController.clear();
    _passwordController.clear();
  }

  void _scheduleAuthErrorClear() {
    _authErrorTimer?.cancel();
    _authErrorTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _authError = null;
      });
    });
  }

  Future<void> _pauseCamera() async {
    try {
      await _controller.stop();
    } catch (_) {
      // ignore stop errors
    } finally {
      if (mounted) {
        setState(() {
          _cameraActive = false;
        });
      }
    }
  }

  Future<bool> _resumeCamera() async {
    if (!_authenticated) return false;
    try {
      await _controller.start();
      if (!mounted) return false;
      setState(() {
        _cameraActive = true;
        _cameraError = null;
        _cameraPromptDismissed = true;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      setState(() {
        _cameraActive = false;
        _cameraError =
            'Kamera tidak dapat dibuka. Pastikan izin kamera diberikan atau tekan ulang.';
      });
      return false;
    }
  }

  void _scheduleStatusReset({Duration duration = const Duration(seconds: 4)}) {
    _statusResetTimer?.cancel();
    _statusResetTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() {
        _statusMessage = _defaultStatusMessage;
        _pendingValue = null;
        _pendingFormat = null;
        _showSuccess = false;
        _isSending = false;
      });
      if (_cameraPromptDismissed) {
        _resumeCamera();
      }
    });
  }

  Future<void> _sendToSpreadsheet(String code, DateTime scannedAt) async {
    final result = await _spreadsheetService.sendCode(
      code: code,
      scannedAt: scannedAt,
    );

    if (result.likelySentDespiteCors) {
      return;
    }

    final responseBody = result.serverResponse;
    if (responseBody != null && responseBody.isNotEmpty) {
      _appendLog('Respons server: $responseBody');
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
    Widget content;
    if (!_sessionChecked) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!_authenticated) {
      content = LoginForm(
        usernameController: _usernameController,
        passwordController: _passwordController,
        isLoading: _isAuthenticating,
        errorMessage: _authError,
        attemptMessage: _lastAuthAttempt,
        showPassword: _showPassword,
        onTogglePasswordVisibility: () {
          setState(() {
            _showPassword = !_showPassword;
          });
        },
        onSubmit: _handleLogin,
      );
    } else {
      content = ScannerContent(
        controller: _controller,
        onCapture: _handleCapture,
        isSending: _isSending,
        statusMessage: _statusMessage,
        lastValue: _lastValue,
        pendingValue: _pendingValue,
        pendingFormat: _pendingFormat,
        showSuccess: _showSuccess,
        submitButton: _buildSubmitButton(),
        logs: _logs,
        cameraActive: _cameraActive,
        cameraError: _cameraError,
        onRequestCamera: () {
          _resumeCamera();
        },
        cameraPromptDismissed: _cameraPromptDismissed,
      );
    }
    return Scaffold(body: _buildBackground(content));
  }

  Widget _buildBackground(Widget child) {
    return DecoratedBox(
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
          child: child,
        ),
      ),
    );
  }
}
