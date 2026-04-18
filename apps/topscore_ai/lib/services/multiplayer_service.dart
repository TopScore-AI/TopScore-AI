import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/web_socket_channel.dart';
import '../config/app_config.dart';
import '../models/quiz_model.dart';
import 'auth_headers.dart';

enum MultiplayerStatus { lobby, playing, finished, error }

class MultiplayerService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  
  final _roomStateController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get roomStateStream => _roomStateController.stream;

  MultiplayerStatus status = MultiplayerStatus.lobby;
  List<Map<String, dynamic>> players = [];
  QuizQuestion? currentQuestion;
  int currentQuestionIndex = -1;
  List<Map<String, dynamic>> leaderboard = [];

  String? _roomCode;
  String? get roomCode => _roomCode;

  Future<String> createRoom({
    required String hostId,
    required Quiz quiz,
  }) async {
    final url = Uri.parse('${AppConfig.backendBaseUrl}/multiplayer/create');
    final headers = await AuthHeaders.getHeaders({'Content-Type': 'application/json'});
    
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode({
        'host_id': hostId,
        'quiz_data': quiz.toJson(),
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _roomCode = data['room_code'];
      return _roomCode!;
    } else {
      throw Exception('Failed to create room: ${response.body}');
    }
  }

  Future<void> joinRoom({
    required String roomCode,
    required String userId,
    required String name,
  }) async {
    _roomCode = roomCode;
    final wsUrl = '${AppConfig.wsUrl}/ws/multiplayer/$roomCode?user_id=$userId&name=$name';
    
    try {
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      
      _subscription = _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message);
          _handleMessage(data);
          _roomStateController.add(data);
        },
        onError: (e) {
          status = MultiplayerStatus.error;
          _roomStateController.add({'type': 'error', 'message': e.toString()});
        },
        onDone: () {
          status = MultiplayerStatus.finished;
          _roomStateController.add({'type': 'disconnected'});
        },
      );
    } catch (e) {
      status = MultiplayerStatus.error;
      rethrow;
    }
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'];
    
    switch (type) {
      case 'player_joined':
      case 'player_left':
        // Update local player list logic could go here if server sends full list
        break;
      case 'game_started':
        status = MultiplayerStatus.playing;
        break;
      case 'new_question':
        currentQuestionIndex = data['index'];
        currentQuestion = QuizQuestion.fromJson(data['question']);
        break;
      case 'game_finished':
        status = MultiplayerStatus.finished;
        leaderboard = List<Map<String, dynamic>>.from(data['leaderboard']);
        break;
    }
  }

  void startGame() {
    _channel?.sink.add(jsonEncode({'type': 'start_game'}));
  }

  void submitAnswer(int questionIndex, int answerIndex) {
    _channel?.sink.add(jsonEncode({
      'type': 'submit_answer',
      'question_index': questionIndex,
      'answer_index': answerIndex,
    }));
  }

  void nextQuestion() {
    _channel?.sink.add(jsonEncode({'type': 'next_question'}));
  }

  void dispose() {
    _subscription?.cancel();
    _channel?.sink.close();
    _roomStateController.close();
  }
}
