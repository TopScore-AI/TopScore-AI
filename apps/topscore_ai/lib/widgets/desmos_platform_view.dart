import 'package:flutter/widgets.dart';

abstract class DesmosPlatformView extends StatelessWidget {
  final String html;
  const DesmosPlatformView({super.key, required this.html});

  factory DesmosPlatformView.create({Key? key, required String html}) {
    throw UnimplementedError('DesmosPlatformView.create() has not been implemented.');
  }
}
