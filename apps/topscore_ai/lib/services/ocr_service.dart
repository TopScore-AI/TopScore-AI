export 'ocr_service_stub.dart'
    if (dart.library.io) 'ocr_service_native.dart'
    if (dart.library.js_interop) 'ocr_service_web.dart';
