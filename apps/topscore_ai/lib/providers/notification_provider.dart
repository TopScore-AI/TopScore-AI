export 'notification_provider_stub.dart'
    if (dart.library.io) 'notification_provider_native.dart'
    if (dart.library.js_interop) 'notification_provider_web.dart';
