import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/app_models.dart';

enum ModelType { gptImage, nanoBanana, openai, gemini }

const _gptImageModels = {'gpt-image-2', 'gpt-image-2-vip'};
const _nanoBananaPrefix = 'nano-banana';

ModelType detectModelType(String model) {
  if (_gptImageModels.contains(model)) return ModelType.gptImage;
  if (model.startsWith(_nanoBananaPrefix)) return ModelType.nanoBanana;
  return ModelType.openai;
}

bool isNanoBanana2Family(String model) {
  return model == 'nano-banana-2' || model.startsWith('nano-banana-2-');
}

/// gpt-image-2-vip 需传像素值（默认 1K 档）
const _gptVipPixels1K = {
  'auto': '1024x1024',
  '1:1': '1024x1024',
  '16:9': '1280x720',
  '9:16': '720x1280',
  '4:3': '1152x864',
  '3:4': '864x1152',
  '3:2': '1536x1024',
  '2:3': '1024x1536',
  '5:4': '1120x896',
  '4:5': '896x1120',
  '21:9': '1456x624',
};

class ApiService {
  ApiService._();
  static final ApiService instance = ApiService._();

  Future<List<GenerateResult>> generateImages(
    Profile profile,
    GenerateParams params, {
    void Function(int progress)? onProgress,
  }) async {
    if (profile.apiKey.trim().isEmpty) {
      throw Exception('请先在设置中填写 API Key');
    }
    switch (profile.apiFormat) {
      case ApiFormat.grsai:
        return _generateGrsai(profile, params, onProgress);
      case ApiFormat.gemini:
        return _generateGemini(profile, params);
      case ApiFormat.openai:
        return _generateOpenAI(profile, params);
    }
  }

  Future<String> _urlToBase64(String url) async {
    try {
      final res = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 90));
      if (res.statusCode != 200) {
        throw Exception('下载图片失败: ${res.statusCode}');
      }
      return base64Encode(res.bodyBytes);
    } on SocketException catch (e) {
      throw Exception('下载生成图片失败，请检查网络: ${e.message}');
    }
  }

  Map<String, dynamic>? _parseStreamLine(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;
    var json = trimmed;
    if (json.startsWith('data:')) {
      json = json.substring(5).trim();
    }
    if (json == '[DONE]' || json.isEmpty) return null;
    try {
      return jsonDecode(json) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  void _throwGrsaiStatus(Map<String, dynamic> data) {
    final status = data['status'] as String?;
    if (status == 'violation') {
      throw Exception('内容违规，请修改 Prompt 或参考图');
    }
    if (status == 'failed') {
      throw Exception(
        data['error'] as String? ?? '生成失败',
      );
    }
  }

  Future<List<GenerateResult>> _resultsFromPayload(
    Map<String, dynamic> data,
  ) async {
    final results = data['results'] as List<dynamic>?;
    if (results == null || results.isEmpty) {
      throw Exception('未返回图片结果');
    }
    return Future.wait(results.map((r) async {
      final m = r as Map<String, dynamic>;
      final url = m['url'] as String?;
      if (url == null || url.isEmpty) {
        throw Exception('结果缺少图片 URL');
      }
      return GenerateResult(
        base64: await _urlToBase64(url),
        width: (m['width'] as num?)?.toInt() ?? 1024,
        height: (m['height'] as num?)?.toInt() ?? 1024,
      );
    }));
  }

  String _resolveGptAspectRatio(GenerateParams params) {
    final ratio = params.size ?? '1:1';
    if (params.model == 'gpt-image-2-vip') {
      return _gptVipPixels1K[ratio] ?? _gptVipPixels1K['1:1']!;
    }
    if (ratio == 'auto') return '1:1';
    return ratio;
  }

  Map<String, dynamic> _buildGrsaiBody(
    GenerateParams params, {
    required String replyType,
  }) {
    final type = detectModelType(params.model);
    final images = params.urls ?? <String>[];
    final body = <String, dynamic>{
      'model': params.model,
      'prompt': params.prompt,
      'images': images,
      'replyType': replyType,
    };
    if (type == ModelType.nanoBanana) {
      body['aspectRatio'] = params.size ?? 'auto';
      if (params.imageSize != null && params.imageSize!.isNotEmpty) {
        body['imageSize'] = params.imageSize;
      }
    } else if (type == ModelType.gptImage) {
      body['aspectRatio'] = _resolveGptAspectRatio(params);
    }
    return body;
  }

  Map<String, String> _authHeaders(Profile profile) => {
        'Authorization': 'Bearer ${profile.apiKey.trim()}',
        'Content-Type': 'application/json',
      };

  String _base(Profile profile) {
    final url = profile.baseUrl.trim().replaceAll(RegExp(r'/$'), '');
    if (url.isEmpty) {
      throw Exception('请填写 Base URL');
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      throw Exception('Base URL 必须以 http:// 或 https:// 开头');
    }
    return url;
  }

  Future<List<GenerateResult>> _generateGrsai(
    Profile profile,
    GenerateParams params,
    void Function(int progress)? onProgress,
  ) async {
    try {
      return await _generateGrsaiStream(profile, params, onProgress);
    } on Exception catch (e) {
      final msg = e.toString();
      if (msg.contains('流结束但未收到结果') ||
          msg.contains('请求失败') && msg.contains('stream')) {
        return _generateGrsaiAsync(profile, params, onProgress);
      }
      rethrow;
    }
  }

  Future<List<GenerateResult>> _generateGrsaiStream(
    Profile profile,
    GenerateParams params,
    void Function(int progress)? onProgress,
  ) async {
    final client = http.Client();
    try {
      final request = http.Request(
        'POST',
        Uri.parse('${_base(profile)}/v1/api/generate'),
      )
        ..headers.addAll({
          ..._authHeaders(profile),
          'Accept': 'text/event-stream, application/json',
        })
        ..body = jsonEncode(_buildGrsaiBody(params, replyType: 'stream'));

      final response = await client
          .send(request)
          .timeout(const Duration(minutes: 5));
      if (response.statusCode != 200) {
        final text = await response.stream.bytesToString();
        throw Exception('请求失败 ${response.statusCode}: $text');
      }

      final ct = response.headers['content-type'] ?? '';
      if (ct.contains('application/json') &&
          !ct.contains('event-stream') &&
          !ct.contains('stream')) {
        final text = await response.stream.bytesToString();
        final data = jsonDecode(text) as Map<String, dynamic>;
        _throwGrsaiStatus(data);
        if (data['progress'] is num && onProgress != null) {
          onProgress((data['progress'] as num).toInt());
        }
        if (data['status'] == 'succeeded') {
          return _resultsFromPayload(data);
        }
        throw Exception(data['error'] as String? ?? '生成未完成');
      }

      var buffer = '';
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        buffer += chunk;
        final lines = buffer.split('\n');
        buffer = lines.removeLast();

        for (final line in lines) {
          final data = _parseStreamLine(line);
          if (data == null) continue;

          if (data['progress'] is num && onProgress != null) {
            onProgress((data['progress'] as num).toInt());
          }

          _throwGrsaiStatus(data);

          if (data['status'] == 'succeeded') {
            return _resultsFromPayload(data);
          }
        }
      }
      throw Exception('流结束但未收到结果');
    } on SocketException catch (e) {
      throw Exception('无法连接服务器，请检查网络与 Base URL: ${e.message}');
    } on HttpException catch (e) {
      throw Exception('网络请求异常: ${e.message}');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('网络请求失败: $e（请检查 Base URL 与 API Key）');
    } finally {
      client.close();
    }
  }

  Future<List<GenerateResult>> _generateGrsaiAsync(
    Profile profile,
    GenerateParams params,
    void Function(int progress)? onProgress,
  ) async {
    final base = _base(profile);
    final headers = _authHeaders(profile);
    final res = await http
        .post(
          Uri.parse('$base/v1/api/generate'),
          headers: headers,
          body: jsonEncode(_buildGrsaiBody(params, replyType: 'async')),
        )
        .timeout(const Duration(seconds: 60));

    if (res.statusCode != 200) {
      throw Exception('请求失败 ${res.statusCode}: ${res.body}');
    }

    final start = jsonDecode(res.body) as Map<String, dynamic>;
    _throwGrsaiStatus(start);
    if (start['status'] == 'succeeded') {
      return _resultsFromPayload(start);
    }

    final id = start['id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('异步任务未返回 id');
    }

    const maxAttempts = 120;
    for (var i = 0; i < maxAttempts; i++) {
      if (i > 0) {
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      final poll = await http
          .get(
            Uri.parse('$base/v1/api/result').replace(
              queryParameters: {'id': id},
            ),
            headers: {'Authorization': headers['Authorization']!},
          )
          .timeout(const Duration(seconds: 30));

      if (poll.statusCode != 200) {
        throw Exception('查询失败 ${poll.statusCode}: ${poll.body}');
      }

      final data = jsonDecode(poll.body) as Map<String, dynamic>;
      if (data['progress'] is num && onProgress != null) {
        onProgress((data['progress'] as num).toInt());
      }

      _throwGrsaiStatus(data);

      if (data['status'] == 'succeeded') {
        return _resultsFromPayload(data);
      }
    }
    throw Exception('生成超时，请稍后在服务端查看任务状态');
  }

  Future<List<GenerateResult>> _generateOpenAI(
    Profile profile,
    GenerateParams params,
  ) async {
    const sizeMap = {
      '1:1': '1024x1024',
      '3:2': '1536x1024',
      '2:3': '1024x1536',
      'auto': '1024x1024',
    };
    final res = await http
        .post(
          Uri.parse('${_base(profile)}/v1/images/generations'),
          headers: {
            'Authorization': 'Bearer ${profile.apiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': params.model.isNotEmpty
                ? params.model
                : (profile.defaultModel ?? 'dall-e-3'),
            'prompt': params.prompt,
            'n': params.n ?? 1,
            'size': sizeMap[params.size ?? '1:1'] ?? '1024x1024',
            'response_format': 'b64_json',
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode != 200) {
      throw Exception('请求失败 ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final items = data['data'] as List<dynamic>;
    return items
        .map((item) => GenerateResult(
              base64: (item as Map)['b64_json'] as String,
              width: 1024,
              height: 1024,
            ))
        .toList();
  }

  Future<List<GenerateResult>> _generateGemini(
    Profile profile,
    GenerateParams params,
  ) async {
    final model = params.model.isNotEmpty
        ? params.model
        : (profile.defaultModel ?? 'imagen-3.0-generate-002');
    final res = await http
        .post(
          Uri.parse('${_base(profile)}/v1beta/models/$model:predict'),
          headers: {
            'x-goog-api-key': profile.apiKey.trim(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'instances': [
              {'prompt': params.prompt}
            ],
            'parameters': {
              'sampleCount': params.n ?? 1,
              'aspectRatio': params.size ?? '1:1',
            },
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (res.statusCode != 200) {
      throw Exception('请求失败 ${res.statusCode}: ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final preds = data['predictions'] as List<dynamic>;
    return preds
        .map((item) => GenerateResult(
              base64: (item as Map)['bytesBase64Encoded'] as String,
              width: 1024,
              height: 1024,
            ))
        .toList();
  }
}
