import 'package:isar_community/isar.dart';

part 'pdf_annotation_native.g.dart';

@collection
class PdfAnnotationRecord {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String docId; 

  late String annotationsJson; 

  late DateTime lastModified;
}
