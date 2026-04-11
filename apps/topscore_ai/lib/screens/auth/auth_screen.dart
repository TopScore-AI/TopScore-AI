import 'package:flutter/material.dart';
import 'login_screen.dart';

class AuthScreen extends StatelessWidget {
  final bool isRegister;
  const AuthScreen({super.key, this.isRegister = false});

  @override
  Widget build(BuildContext context) {
    return LoginScreen(isRegister: isRegister);
  }
}
