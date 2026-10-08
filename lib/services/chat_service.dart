import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';
import 'config_service.dart';

class ChatMessage {
  ChatMessage({
    required this.role,
    required this.text,
    this.imageDataUrls = const [],
  });

  final String role; // user | assistant | system
  final String text;
  final List<String> imageDataUrls;
}

/// OpenAI Chat Completions 兼容：固定 discovery 站点，Key/模型来自设置。
class ChatService {
  ChatService._();
  static final ChatService instance = ChatService._();

  static const systemPrompt = '''
你是 ImageGen 的提示词助手。用户在做 AI 生图，请帮他们写出清晰、可直接粘贴使用的中文或中英混合提示词。
要求：
1. 优先输出可直接用于生图的最终提示词；必要时先简短说明再给出提示词。
2. 若用户附带图片，请结合画面内容（主体、构图、光影、风格、材质）来改写或续写提示词。
3. 不要编造不存在的 API 或参数；不要输出无关寒暄。
4. 若用户只要提示词，尽量只给一段完整提示词，方便一键填入输入框。
''';

  /// OpenAI 兼容：`GET /v1/models`
  Future<List<String>> listModels({required String apiKey}) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception('请先填写 API Key');
    }
    final uri = Uri.parse('$kChatBaseUrl/models');
    ConfigService.instance.log('INFO', 'Chat GET $uri');
    final res = await http
        .get(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
        )
        .timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) {
      ConfigService.instance.log('ERROR', 'Chat models ${res.statusCode}: ${res.body}');
      throw Exception(_friendlyError(res.statusCode, res.body));
    }
    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final list = data['data'] as List<dynamic>? ?? const [];
    final ids = <String>[];
    for (final item in list) {
      if (item is! Map) continue;
      final id = item['id'] as String?;
      if (id != null && id.isNotEmpty) ids.add(id);
    }
    ids.sort();
    return ids;
  }

  Future<String> complete({
    required String apiKey,
    required String model,
    required List<ChatMessage> history,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception('请先在系统设置中填写提示词助手 API Key');
    }

    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ...history.map(_toApiMessage),
    ];

    final uri = Uri.parse('$kChatBaseUrl/chat/completions');
    ConfigService.instance.log(
      'INFO',
      'Chat POST $uri model=$model msgs=${messages.length}',
    );

    final res = await http
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $key',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'messages': messages,
            'stream': false,
          }),
        )
        .timeout(const Duration(minutes: 2));

    if (res.statusCode != 200) {
      final body = res.body;
      ConfigService.instance.log('ERROR', 'Chat HTTP ${res.statusCode}: $body');
      throw Exception(_friendlyError(res.statusCode, body));
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>?;
    if (choices == null || choices.isEmpty) {
      throw Exception('未返回对话结果');
    }
    final message = choices.first as Map<String, dynamic>;
    final content = (message['message'] as Map<String, dynamic>?)?['content'];
    if (content is String && content.trim().isNotEmpty) {
      return content.trim();
    }
    throw Exception('助手回复为空');
  }

  Map<String, dynamic> _toApiMessage(ChatMessage m) {
    if (m.imageDataUrls.isEmpty) {
      return {'role': m.role, 'content': m.text};
    }
    final parts = <Map<String, dynamic>>[
      if (m.text.trim().isNotEmpty) {'type': 'text', 'text': m.text},
      for (final url in m.imageDataUrls)
        {
          'type': 'image_url',
          'image_url': {'url': url},
        },
    ];
    if (parts.isEmpty) {
      parts.add({'type': 'text', 'text': '请根据图片写出生图提示词'});
    }
    return {'role': m.role, 'content': parts};
  }

  String _friendlyError(int code, String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map) {
        final err = decoded['error'];
        if (err is Map && err['message'] is String) {
          return err['message'] as String;
        }
        if (err is String && err.isNotEmpty) return err;
        if (decoded['message'] is String) return decoded['message'] as String;
      }
    } catch (_) {}
    if (code == 401 || code == 403) return '认证失败，请检查 API Key';
    if (code == 429) return '请求过于频繁，请稍后再试';
    if (code >= 500) return '服务端异常 ($code)';
    final short = body.length > 120 ? '${body.substring(0, 120)}…' : body;
    return '请求失败 ($code)：$short';
  }

  Future<String> fileToDataUrl(File file) async {
    final bytes = await file.readAsBytes();
    final ext = file.path.split('.').last.toLowerCase();
    final mime = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/png',
    };
    return 'data:$mime;base64,${base64Encode(bytes)}';
  }
}
