import 'package:share_plus/share_plus.dart';

class ShareParams {
  final String? text;
  final String? subject;
  final List<XFile>? files;

  const ShareParams({this.text, this.subject, this.files});
}
