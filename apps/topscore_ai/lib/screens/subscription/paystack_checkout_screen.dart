import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../services/paystack_service.dart';

/// Result returned from the in-app Paystack checkout flow.
class PaystackCheckoutResult {
  final bool success;
  final PaystackVerifyResult? verifyResult;
  final String? error;

  const PaystackCheckoutResult._({
    required this.success,
    this.verifyResult,
    this.error,
  });

  factory PaystackCheckoutResult.success(PaystackVerifyResult result) =>
      PaystackCheckoutResult._(success: true, verifyResult: result);

  factory PaystackCheckoutResult.failure(String error) =>
      PaystackCheckoutResult._(success: false, error: error);

  factory PaystackCheckoutResult.cancelled() =>
      const PaystackCheckoutResult._(success: false, error: 'cancelled');
}

/// In-app WebView checkout screen for Paystack.
///
/// Loads the Paystack `authorizationUrl` inside a WebView so users
/// never leave the app.  After payment the user taps **Done** (or the
/// WebView detects a redirect to `callbackUrl`) and verification runs
/// automatically.
///
/// Usage:
/// ```dart
/// final result = await Navigator.push<PaystackCheckoutResult>(
///   context,
///   MaterialPageRoute(
///     builder: (_) => PaystackCheckoutScreen(
///       authorizationUrl: initResult.authorizationUrl,
///       reference: initResult.reference,
///     ),
///   ),
/// );
/// ```
class PaystackCheckoutScreen extends StatefulWidget {
  /// Paystack hosted-checkout URL.
  final String authorizationUrl;

  /// Transaction reference used for verification.
  final String reference;

  /// Optional redirect URL.  If the backend sends a `callback_url` to
  /// Paystack, Paystack will redirect here after payment with
  /// `?trxref=xxx&reference=xxx`.  The WebView intercepts this redirect
  /// instead of loading it.
  final String? callbackUrl;

  const PaystackCheckoutScreen({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    this.callbackUrl,
  });

  @override
  State<PaystackCheckoutScreen> createState() => _PaystackCheckoutScreenState();
}

class _PaystackCheckoutScreenState extends State<PaystackCheckoutScreen> {
  late final WebViewController _controller;
  final PaystackService _paystackService = PaystackService();

  bool _isLoading = true;
  bool _isVerifying = false;
  int _loadProgress = 0;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onProgress: (progress) {
            if (mounted) setState(() => _loadProgress = progress);
          },
          onNavigationRequest: (request) {
            // Intercept callback_url redirect if configured
            if (widget.callbackUrl != null &&
                request.url.startsWith(widget.callbackUrl!)) {
              _onPaymentCompleted();
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.authorizationUrl));
  }

  /// Called when the WebView detects the callback redirect.
  Future<void> _onPaymentCompleted() async {
    await _verifyAndReturn();
  }

  /// Called when the user taps "I've Paid".
  Future<void> _onDoneTapped() async {
    await _verifyAndReturn();
  }

  Future<void> _verifyAndReturn() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);

    try {
      final result = await _paystackService.verifyTransaction(widget.reference);

      if (mounted) {
        Navigator.pop(
          context,
          result.isSuccess
              ? PaystackCheckoutResult.success(result)
              : PaystackCheckoutResult.failure(
                  'Payment status: ${result.status}'),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Verification failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _onCancelTapped() {
    Navigator.pop(context, PaystackCheckoutResult.cancelled());
  }

  @override
  Widget build(BuildContext context) {
    // On web, WebView is not supported — this screen should only be
    // pushed on mobile.  Guard defensively anyway.
    if (kIsWeb) {
      return Scaffold(
        appBar: AppBar(title: const Text('Checkout')),
        body: const Center(child: Text('WebView not supported on web.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Complete Payment',
          style: GoogleFonts.nunito(fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isVerifying ? null : _onCancelTapped,
        ),
        actions: [
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _onDoneTapped,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text(
                "I've Paid",
                style: GoogleFonts.nunito(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
        backgroundColor: const Color(0xFF09A5DB),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            LinearProgressIndicator(
              value: _loadProgress / 100,
              backgroundColor: Colors.grey[200],
              color: const Color(0xFF09A5DB),
              minHeight: 3,
            ),
          if (_isVerifying)
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Verifying payment…'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
