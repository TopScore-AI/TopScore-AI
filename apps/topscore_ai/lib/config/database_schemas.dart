import '../tutor_client/message_model_native.dart';
import '../models/app_notification_native.dart';
import '../models/study_material_native.dart';
import '../models/pdf_annotation_native.dart';

/// Centralized list of all Isar schemas used across the application.
/// This ensures consistent initialization regardless of which service 
/// initializes the database first.
const List<dynamic> appSchemas = [
  ChatMessageSchema,
  AppNotificationSchema,
  SavedStudyMaterialSchema,
  PdfAnnotationRecordSchema,
];
