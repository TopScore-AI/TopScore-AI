import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  final signIn = GoogleSignIn.instance;
  await signIn.initialize();
  // ignore: avoid_print
  print('GoogleSignIn created and initialized');
  final googleUser = await signIn.authenticate();
  // ignore: avoid_print
  print('Auth Result: ${googleUser.authentication}');
}
