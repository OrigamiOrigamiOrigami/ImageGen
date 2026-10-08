import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/app_models.dart';
import '../services/chat_service.dart';
import '../theme/app_typography.dart';
import '../themes/app_themes.dart';

/// 侧栏提示词助手：多模态对话 → 一键填入生图输入框。
class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.theme,
    required this.apiKey,
    required this.model,
    required this.onClose,
    required this.onApplyPrompt,
    required this.onOpenSettings,
  });

  final AppTheme theme;
  final String apiKey;
  final String model;
  final VoidCallback onClose;
  final ValueChanged<String> onApplyPrompt;
  final VoidCallback onOpenSettings;

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];
  final _pendingImages = <String>[];
  var _sending = false;
  String? _error;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
    );
    if (result == null) return;
    for (final f in result.files) {
      if (f.path == null) continue;
      final dataUrl = await ChatService.instance.fileToDataUrl(File(f.path!));
      if (!mounted) return;
      setState(() => _pendingImages.add(dataUrl));
    }
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (_sending) return;
    if (text.isEmpty && _pendingImages.isEmpty) return;
    if (widget.apiKey.trim().isEmpty) {
      setState(() => _error = '请先在系统设置中填写提示词助手 API Key');
      return;
    }

    final userMsg = ChatMessage(
      role: 'user',
      text: text.isEmpty ? '请根据图片写出生图提示词' : text,
      imageDataUrls: List.of(_pendingImages),
    );

    setState(() {
      _messages.add(userMsg);
      _pendingImages.clear();
      _input.clear();
      _sending = true;
      _error = null;
    });
    _scrollToEnd();

    try {
      final reply = await ChatService.instance.complete(
        apiKey: widget.apiKey,
        model: widget.model.isEmpty ? kChatDefaultModel : widget.model,
        history: _messages,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(role: 'assistant', text: reply));
        _sending = false;
      });
      _scrollToEnd();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  void _applyLastAssistant() {
    for (var i = _messages.length - 1; i >= 0; i--) {
      if (_messages[i].role == 'assistant' && _messages[i].text.isNotEmpty) {
        widget.onApplyPrompt(_messages[i].text);
        return;
      }
    }
  }

  Uint8List? _decodeDataUrl(String url) {
    try {
      final b64 = url.contains(',') ? url.split(',').last : url;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final hasKey = widget.apiKey.trim().isNotEmpty;

    return Material(
      color: c(theme.surface),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: c(theme.border))),
            ),
            child: Row(
              children: [
                Icon(Icons.chat_bubble_outline,
                    size: 18, color: c(theme.accentGlow)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '提示词助手',
                    style: AppTypography.app(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: c(theme.text),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _messages.isEmpty
                      ? null
                      : () => setState(() {
                            _messages.clear();
                            _error = null;
                          }),
                  child: const Text('清空'),
                ),
                IconButton(
                  tooltip: '关闭',
                  onPressed: widget.onClose,
                  icon: const Icon(Icons.close, size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Text(
              '模型 ${widget.model.isEmpty ? kChatDefaultModel : widget.model}',
              style: AppTypography.app(
                fontSize: 11,
                color: c(theme.textMuted),
              ),
            ),
          ),
          if (!hasKey)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: InkWell(
                onTap: widget.onOpenSettings,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: c(theme.accent).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: c(theme.accent).withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '尚未填写 API Key，点此打开系统设置',
                    style: AppTypography.app(
                      fontSize: 12,
                      color: c(theme.accentGlow),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              itemCount: _messages.length + (_sending ? 1 : 0),
              itemBuilder: (context, i) {
                if (_sending && i == _messages.length) {
                  return _bubble(
                    theme,
                    role: 'assistant',
                    child: Text(
                      '思考中…',
                      style: AppTypography.app(
                        fontSize: 13,
                        color: c(theme.textMuted),
                      ),
                    ),
                  );
                }
                final m = _messages[i];
                return _bubble(
                  theme,
                  role: m.role,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (m.imageDataUrls.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: m.imageDataUrls.map((url) {
                            final bytes = _decodeDataUrl(url);
                            if (bytes == null) return const SizedBox.shrink();
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.memory(
                                bytes,
                                width: 64,
                                height: 64,
                                fit: BoxFit.cover,
                              ),
                            );
                          }).toList(),
                        ),
                      if (m.imageDataUrls.isNotEmpty && m.text.isNotEmpty)
                        const SizedBox(height: 6),
                      SelectableText(
                        m.text,
                        style: AppTypography.app(
                          fontSize: 13,
                          height: 1.45,
                          color: c(theme.text),
                        ),
                      ),
                      if (m.role == 'assistant') ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => widget.onApplyPrompt(m.text),
                          icon: const Icon(Icons.edit_note, size: 16),
                          label: const Text('填入提示词'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: c(theme.accentGlow),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                _error!,
                style: const TextStyle(color: Colors.redAccent, fontSize: 12),
              ),
            ),
          if (_pendingImages.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _pendingImages.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final bytes = _decodeDataUrl(_pendingImages[i]);
                  return Stack(
                    children: [
                      if (bytes != null)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            bytes,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _pendingImages.removeAt(i)),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: c(theme.border))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: '添加参考图',
                      onPressed: _sending ? null : _pickImages,
                      icon: Icon(Icons.add_photo_alternate_outlined,
                          color: c(theme.textMuted)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        enabled: !_sending,
                        style: AppTypography.app(
                          fontSize: 13,
                          color: c(theme.text),
                        ),
                        decoration: InputDecoration(
                          hintText: '描述你想要的画面，或让我根据图片写提示词…',
                          hintStyle: AppTypography.app(
                            fontSize: 13,
                            color: c(theme.textMuted),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c(theme.border)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(color: c(theme.border)),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: c(theme.accent),
                      ),
                      icon: _sending
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send, size: 18),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _messages.any((m) => m.role == 'assistant')
                        ? _applyLastAssistant
                        : null,
                    child: const Text('填入最新回复'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bubble(
    AppTheme theme, {
    required String role,
    required Widget child,
  }) {
    final mine = role == 'user';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        constraints: const BoxConstraints(maxWidth: 340),
        decoration: BoxDecoration(
          color: mine
              ? c(theme.accent).withValues(alpha: 0.14)
              : c(theme.bg),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c(theme.border)),
        ),
        child: child,
      ),
    );
  }
}
