import '../../constants/colors.dart';
import 'dart:ui_web' as ui_web;
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/material.dart';
import '../../widgets/app_spinner.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/paystack_service.dart';

/// Web-only full-screen checkout that embeds Paystack in an iframe.
class PaystackWebCheckout extends StatefulWidget {
  final String authorizationUrl;
  final String reference;
  final String callbackUrl;

  const PaystackWebCheckout({
    super.key,
    required this.authorizationUrl,
    required this.reference,
    required this.callbackUrl,
  });

  @override
  State<PaystackWebCheckout> createState() => _PaystackWebCheckoutState();
}

class _PaystackWebCheckoutState extends State<PaystackWebCheckout> {
  final PaystackService _paystackService = PaystackService();
  bool _isVerifying = false;
  late final String _viewId;

  @override
  void initState() {
    super.initState();
    _viewId = 'paystack-iframe-${widget.reference}';

    final iframe = web.document.createElement('iframe') as web.HTMLIFrameElement
      ..src = widget.authorizationUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..allow = 'payment';

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => iframe,
    );

    // Listen for postMessage events from Paystack iframe
    web.window.addEventListener(
      'message',
      (web.Event event) {
        final msg =
            (event as web.MessageEvent).data.dartify()?.toString() ?? '';
        if (msg.contains('success') || msg.contains('paystack')) {
          _verifyAndReturn();
        }
      }.toJS,
    );
  }

  Future<void> _verifyAndReturn() async {
    if (_isVerifying) return;
    setState(() => _isVerifying = true);
    try {
      final result = await _paystackService.verifyTransaction(widget.reference);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (mounted) {
        setState(() => _isVerifying = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Verification failed: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.paystackBlue,
        foregroundColor: Colors.white,
        title: Text('Complete Payment',
            style: GoogleFonts.nunito(fontWeight: FontWeight.bold)),
        leadingWidth: 80,
        leading: TextButton(
          onPressed: _isVerifying ? null : () => Navigator.pop(context, null),
          child: Text(
            'Cancel',
            style: GoogleFonts.nunito(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        actions: [
          if (_isVerifying)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: AppSpinner(strokeWidth: 2, color: Colors.white),
                ),
              ),
            )
          else
            TextButton.icon(
              onPressed: _verifyAndReturn,
              icon: const Icon(Icons.check_circle, color: Colors.white),
              label: Text("I've Paid",
                  style: GoogleFonts.nunito(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          HtmlElementView(viewType: _viewId),
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
                        AppSpinner(),
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
