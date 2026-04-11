import 'dart:convert';

enum MessageStatus { pending, sent, error }

class SourceMetadata {
  final String title;
  final String? url;
  final String? author;
  final String type; // 'url', 'book', 'paper'

  SourceMetadata({
    this.title = '',
    this.url,
    this.author,
    this.type = 'url',
  });

  factory SourceMetadata.fromJson(Map<String, dynamic> json) {
    return SourceMetadata(
      title: json['title'] ?? 'Unknown Source',
      url: json['url'],
      author: json['author'],
      type: json['type'] ?? 'url',
    );
  }
}

class ChatAttachmentMetadata {
  final String? id;
  final String? url;
  final String? name;
  final String? type;

  ChatAttachmentMetadata({
    this.id,
    this.url,
    this.name,
    this.type,
  });

  factory ChatAttachmentMetadata.fromJson(Map<String, dynamic> json) {
    return ChatAttachmentMetadata(
      id: json['id'],
      url: json['url'],
      name: json['name'],
      type: json['type'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'url': url,
      'name': name,
      'type': type,
    };
  }
}

class ChatMessage {
  // Web stub: No Isar Id on web.
  int get isarId => 0;

  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final String? audioUrl;
  final String? imageUrl;
  final List<ChatAttachmentMetadata>? attachments; // Multiple attachments support
  final int? feedback; 
  final List<SourceMetadata>? sources;
  final String? reasoning;
  final String? quizDataJson;
  final String? flashcardDataJson;
  final List<String>? mathSteps;
  final String? mathAnswer;
  final bool isBookmarked;
  final List<VideoResult>? videos;
  final String? desmosDataJson;
  final String? mnemonicDataJson;
  final String? graphDataJson;
  final String? punnettDataJson;

  final bool isTemporary;
  final bool isComplete;
  final String? replyToId;
  final String? replyToText;
  final bool isThought;
  final bool isThinking;
  final bool isKicdCertified;
  
  final MessageStatus status;
  final String? threadId;
  final String? fileId;   // Unique ID for the attachment
  final String? fileName; // Display name for the attachment
  final String? fileType; // Type of attachment ('image', 'pdf', 'docx', etc.)

  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.audioUrl,
    this.imageUrl,
    this.feedback,
    this.sources,
    this.reasoning,
    this.quizDataJson,
    this.flashcardDataJson,
    this.mathSteps,
    this.mathAnswer,
    this.isBookmarked = false,
    this.videos,
    this.desmosDataJson,
    this.mnemonicDataJson,
    this.isTemporary = false,
    this.isComplete = true,
    this.replyToId,
    this.replyToText,
    this.isThought = false,
    this.isThinking = false,
    this.isKicdCertified = false,
    this.status = MessageStatus.sent,
    this.threadId,
    this.graphDataJson,
    this.punnettDataJson,
    this.fileId,
    this.fileName,
    this.fileType,
    this.attachments,
  });

  ChatMessage copyWith({
    String? id,
    String? text,
    bool? isUser,
    DateTime? timestamp,
    String? audioUrl,
    String? imageUrl,
    int? feedback,
    List<SourceMetadata>? sources,
    String? reasoning,
    Map<String, dynamic>? quizData,
    String? quizDataJson,
    Map<String, dynamic>? flashcardData,
    String? flashcardDataJson,
    List<String>? mathSteps,
    String? mathAnswer,
    bool? isBookmarked,
    List<VideoResult>? videos,
    bool? isTemporary,
    bool? isComplete,
    String? replyToId,
    String? replyToText,
    bool? isThought,
    bool? isThinking,
    bool? isKicdCertified,
    MessageStatus? status,
    String? threadId,
    String? desmosDataJson,
    String? mnemonicDataJson,
    String? graphDataJson,
    String? punnettDataJson,
    String? fileId,
    String? fileName,
    String? fileType,
    List<ChatAttachmentMetadata>? attachments,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      text: text ?? this.text,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      feedback: feedback ?? this.feedback,
      sources: sources ?? this.sources,
      reasoning: reasoning ?? this.reasoning,
      quizDataJson: quizData != null ? jsonEncode(quizData) : (quizDataJson ?? this.quizDataJson),
      flashcardDataJson: flashcardData != null ? jsonEncode(flashcardData) : (flashcardDataJson ?? this.flashcardDataJson),
      mathSteps: mathSteps ?? this.mathSteps,
      mathAnswer: mathAnswer ?? this.mathAnswer,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      videos: videos ?? this.videos,
      isTemporary: isTemporary ?? this.isTemporary,
      isComplete: isComplete ?? this.isComplete,
      replyToId: replyToId ?? this.replyToId,
      replyToText: replyToText ?? this.replyToText,
      isThought: isThought ?? this.isThought,
      isThinking: isThinking ?? this.isThinking,
      isKicdCertified: isKicdCertified ?? this.isKicdCertified,
      status: status ?? this.status,
      threadId: threadId ?? this.threadId,
      desmosDataJson: desmosDataJson ?? this.desmosDataJson,
      mnemonicDataJson: mnemonicDataJson ?? this.mnemonicDataJson,
      graphDataJson: graphDataJson ?? this.graphDataJson,
      punnettDataJson: punnettDataJson ?? this.punnettDataJson,
      fileId: fileId ?? this.fileId,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      attachments: attachments ?? this.attachments,
    );
  }
}

class VideoResult {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String videoUrl;
  final String duration;
  final String source;

  VideoResult({
    this.id = '',
    this.title = '',
    this.thumbnailUrl = '',
    this.videoUrl = '',
    this.duration = '',
    this.source = '',
  });

  factory VideoResult.fromJson(Map<String, dynamic> json) {
    return VideoResult(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnailUrl: json['thumbnailUrl'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      duration: json['duration'] ?? '',
      source: json['source'] ?? 'Unknown',
    );
  }
}
