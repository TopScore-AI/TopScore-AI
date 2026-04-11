import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:provider/provider.dart';
import '../tutor_client/chat_controller.dart';
import 'dart:developer' as developer;

class SharingService {
  static late StreamSubscription _intentDataStreamSubscription;

  static void init(BuildContext context) {
    if (kIsWeb) return;

    // 1. Listen for shared files while the app is already open in the background
    _intentDataStreamSubscription = ReceiveSharingIntent.instance.getMediaStream()
        .listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty && context.mounted) {
        _handleIncomingFiles(context, value);
      }
    }, onError: (err) {
      developer.log("getIntentDataStream error: $err", name: 'SharingService');
    });

    // 2. Catch files that actually started/woke up the app from a closed state
    ReceiveSharingIntent.instance.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty && context.mounted) {
        _handleIncomingFiles(context, value);
      }
    }).catchError((err) {
      developer.log("getInitialMedia error: $err", name: 'SharingService');
    });
  }

  static void _handleIncomingFiles(BuildContext context, List<SharedMediaFile> files) {
    developer.log("Received ${files.length} shared files", name: 'SharingService');
    
    // We only take the first one for now as per simple implementation
    final file = files.first;
    final path = file.path;

    // Use the ChatController to attach this file
    // We assume ChatController is available in the MultiProvider
    try {
      final chatController = Provider.of<ChatController>(context, listen: false);
      chatController.attachFileFromPath(path);
      
      // Navigate to the AI Tutor screen if not already there
      // This is a bit tricky from a service, but we can use the router
      // For now, we manually navigate to the /ai-tutor route
      // Navigator.of(context).pushNamed('/ai-tutor'); // Standard navigator
      // But since we use GoRouter, we should probably use that
    } catch (e) {
       developer.log("Error handling shared file: $e", name: 'SharingService');
    }
  }

  static void dispose() {
    _intentDataStreamSubscription.cancel();
  }
}
