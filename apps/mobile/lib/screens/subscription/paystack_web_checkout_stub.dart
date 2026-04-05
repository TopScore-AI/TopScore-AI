import 'package:flutter/material.dart';

class PaystackWebCheckout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Paystack interface not available on this platform.')),
    );
  }
}
