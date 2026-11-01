/// Represents a part of content in an AI message.
/// Supports text and multimodal extensions (image, audio, files).
class AiPart {
  final String? text;
  final String? mimeType;
  final String? inlineBase64Data;
  final String? fileUri;

  const AiPart._({
    this.text,
    this.mimeType,
    this.inlineBase64Data,
    this.fileUri,
  });

  /// Factory for standard text content.
  factory AiPart.text(String text) {
    return AiPart._(text: text);
  }

  /// Factory for inline base64 data (e.g. image/jpeg, audio/pcm, audio/wav).
  factory AiPart.inlineData({required String mimeType, required String base64Data}) {
    return AiPart._(mimeType: mimeType, inlineBase64Data: base64Data);
  }

  /// Factory for uploaded file URI reference.
  factory AiPart.fileData({required String mimeType, required String fileUri}) {
    return AiPart._(mimeType: mimeType, fileUri: fileUri);
  }

  bool get isText => text != null;
  bool get isInlineData => inlineBase64Data != null;
  bool get isFileData => fileUri != null;

  Map<String, dynamic> toJson() {
    if (text != null) {
      return {'text': text};
    } else if (inlineBase64Data != null && mimeType != null) {
      return {
        'inlineData': {
          'mimeType': mimeType,
          'data': inlineBase64Data,
        }
      };
    } else if (fileUri != null && mimeType != null) {
      return {
        'fileData': {
          'mimeType': mimeType,
          'fileUri': fileUri,
        }
      };
    }
    return {'text': ''};
  }

  factory AiPart.fromJson(Map<String, dynamic> json) {
    if (json.containsKey('text')) {
      return AiPart.text(json['text'] as String? ?? '');
    } else if (json.containsKey('inlineData')) {
      final inline = json['inlineData'] as Map<String, dynamic>;
      return AiPart.inlineData(
        mimeType: inline['mimeType'] as String? ?? '',
        base64Data: inline['data'] as String? ?? '',
      );
    } else if (json.containsKey('fileData')) {
      final fileData = json['fileData'] as Map<String, dynamic>;
      return AiPart.fileData(
        mimeType: fileData['mimeType'] as String? ?? '',
        fileUri: fileData['fileUri'] as String? ?? '',
      );
    }
    return AiPart.text('');
  }
}

/// A structured turn in an AI dialogue.
class AiContent {
  final String role; // 'user', 'model', or 'system'
  final List<AiPart> parts;

  const AiContent({required this.role, required this.parts});

  factory AiContent.userText(String text) {
    return AiContent(role: 'user', parts: [AiPart.text(text)]);
  }

  factory AiContent.modelText(String text) {
    return AiContent(role: 'model', parts: [AiPart.text(text)]);
  }

  factory AiContent.systemText(String text) {
    return AiContent(role: 'system', parts: [AiPart.text(text)]);
  }

  factory AiContent.userMultimodal({required String text, String? mimeType, String? base64Data}) {
    final parts = <AiPart>[AiPart.text(text)];
    if (mimeType != null && base64Data != null) {
      parts.add(AiPart.inlineData(mimeType: mimeType, base64Data: base64Data));
    }
    return AiContent(role: 'user', parts: parts);
  }

  Map<String, dynamic> toJson() => {
        'role': role,
        'parts': parts.map((p) => p.toJson()).toList(),
      };

  factory AiContent.fromJson(Map<String, dynamic> json) {
    final rawParts = json['parts'] as List<dynamic>? ?? [];
    return AiContent(
      role: json['role'] as String? ?? 'user',
      parts: rawParts.map((p) => AiPart.fromJson(p as Map<String, dynamic>)).toList(),
    );
  }
}

/// Complete request specification for generating or streaming content.
class AiPromptRequest {
  final List<AiContent> contents;
  final String? systemInstruction;
  final double? temperature;
  final double? topP;
  final int? maxOutputTokens;
  final String? modelId;
  final String? taskId;

  const AiPromptRequest({
    required this.contents,
    this.systemInstruction,
    this.temperature,
    this.topP,
    this.maxOutputTokens,
    this.modelId,
    this.taskId,
  });

  factory AiPromptRequest.singlePrompt(
    String prompt, {
    String? systemInstruction,
    double? temperature,
    double? topP,
    int? maxOutputTokens,
    String? modelId,
    String? taskId,
  }) {
    return AiPromptRequest(
      contents: [AiContent.userText(prompt)],
      systemInstruction: systemInstruction,
      temperature: temperature,
      topP: topP,
      maxOutputTokens: maxOutputTokens,
      modelId: modelId,
      taskId: taskId,
    );
  }

  Map<String, dynamic> toGeminiRequestBody() {
    final body = <String, dynamic>{
      'contents': contents.map((c) => c.toJson()).toList(),
    };

    if (systemInstruction != null && systemInstruction!.trim().isNotEmpty) {
      body['systemInstruction'] = {
        'parts': [{'text': systemInstruction!}]
      };
    }

    final generationConfig = <String, dynamic>{};
    if (temperature != null) generationConfig['temperature'] = temperature;
    if (topP != null) generationConfig['topP'] = topP;
    if (maxOutputTokens != null) generationConfig['maxOutputTokens'] = maxOutputTokens;

    if (generationConfig.isNotEmpty) {
      body['generationConfig'] = generationConfig;
    }

    return body;
  }
}
