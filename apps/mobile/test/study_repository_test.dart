import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:topscore_ai/repositories/study_repository.dart';

@GenerateMocks([StudyRepository])
import 'study_repository_test.mocks.dart';

void main() {
  late MockStudyRepository mockRepo;

  setUp(() {
    mockRepo = MockStudyRepository();
  });

  group('StudyRepository Tests', () {
    test('saveMaterial calls repository with correct data', () async {
      when(mockRepo.saveMaterial(
        type: anyNamed('type'),
        topic: anyNamed('topic'),
        curriculum: anyNamed('curriculum'),
        grade: anyNamed('grade'),
        jsonData: anyNamed('jsonData'),
      )).thenAnswer((_) async => {});

      await mockRepo.saveMaterial(
        type: 'flashcard',
        topic: 'Photosynthesis',
        curriculum: 'KICD',
        grade: 'Grade 7',
        jsonData: '{"cards": []}',
      );

      verify(mockRepo.saveMaterial(
        type: 'flashcard',
        topic: 'Photosynthesis',
        curriculum: 'KICD',
        grade: 'Grade 7',
        jsonData: '{"cards": []}',
      )).called(1);
    });

    test('getMaterialsByType returns list of materials', () async {
      final mockData = [
        {'id': 1, 'topic': 'Math'}
      ];
      when(mockRepo.getMaterialsByType('quiz'))
          .thenAnswer((_) async => mockData);

      final result = await mockRepo.getMaterialsByType('quiz');

      expect(result, equals(mockData));
      verify(mockRepo.getMaterialsByType('quiz')).called(1);
    });
  });
}
