import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../models/app_models.dart';
import '../theme/app_typography.dart';
import '../themes/app_themes.dart';

const _formatDefaults = {
  ApiFormat.grsai: (
    baseUrl: 'https://grsai.dakka.com.cn',
    defaultModel: null,
  ),
  ApiFormat.openai: (
    baseUrl: 'https://api.openai.com/v1',
    defaultModel: 'dall-e-3',
  ),
  ApiFormat.gemini: (
    baseUrl: 'https://generativelanguage.googleapis.com',
    defaultModel: 'imagen-3.0-generate-002',
  ),
};

class SettingsModal extends StatefulWidget {
  const SettingsModal({
    super.key,
    required this.theme,
    required this.profiles,
    required this.onSave,
    required this.onClose,
    this.fullPage = false,
  });

  final AppTheme theme;
  final List<Profile> profiles;
  final ValueChanged<List<Profile>> onSave;
  final VoidCallback onClose;
  final bool fullPage;

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  static const _uuid = Uuid();
  late List<Profile> _list;
  late String _selected;

  @override
  void initState() {
    super.initState();
    _list = widget.profiles
        .map((p) => Profile(
              id: p.id,
              name: p.name,
              apiFormat: p.apiFormat,
              baseUrl: p.baseUrl,
              apiKey: p.apiKey,
              defaultModel: p.defaultModel,
            ))
        .toList();
    _selected = _list.isNotEmpty ? _list.first.id : '';
  }

  Profile? get _current {
    for (final p in _list) {
      if (p.id == _selected) return p;
    }
    return null;
  }

  Profile _newProfile() {
    final defaults = _formatDefaults[ApiFormat.grsai]!;
    return Profile(
      id: _uuid.v4(),
      name: '',
      apiFormat: ApiFormat.grsai,
      baseUrl: defaults.baseUrl,
      apiKey: '',
    );
  }

  void _save() {
    for (final p in _list) {
      p.name = p.name.trim();
      p.baseUrl = p.baseUrl.trim();
      p.apiKey = p.apiKey.trim();
    }
    widget.onSave(_list);
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.fullPage) {
      return Scaffold(
        backgroundColor: c(widget.theme.bg),
        appBar: AppBar(
          backgroundColor: c(widget.theme.surface),
          foregroundColor: c(widget.theme.text),
          elevation: 0,
          title: const Text('API 配置'),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: c(widget.theme.textMuted)),
            onPressed: widget.onClose,
          ),
          actions: [
            TextButton(
              onPressed: _save,
              child: Text('保存', style: TextStyle(color: c(widget.theme.accentGlow))),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              _mobileProfileTabs(),
              Expanded(child: _editor()),
              _mobileBottomBar(),
            ],
          ),
        ),
      );
    }

    return Material(
      color: Colors.black.withValues(alpha: 0.7),
      child: GestureDetector(
        onTap: widget.onClose,
        child: Center(
          child: GestureDetector(
            onTap: () {},
            child: Container(
              width: 680,
              decoration: BoxDecoration(
                color: c(widget.theme.surface),
                border: Border.all(color: c(widget.theme.border)),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: c(widget.theme.accent).withValues(alpha: 0.2),
                    blurRadius: 30,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _header(),
                  SizedBox(
                    height: 420,
                    child: Row(
                      children: [
                        _sidebar(),
                        Expanded(child: _editor()),
                      ],
                    ),
                  ),
                  _footer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _mobileProfileTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c(widget.theme.border))),
      ),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ..._list.map((p) {
                    final selected = p.id == _selected;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InputChip(
                        label: Text(p.name.isEmpty ? '未命名' : p.name),
                        selected: selected,
                        onSelected: (_) => setState(() => _selected = p.id),
                        onDeleted: _list.length > 1
                            ? () {
                                setState(() {
                                  _list.removeWhere((x) => x.id == p.id);
                                  if (_selected == p.id) {
                                    _selected =
                                        _list.isNotEmpty ? _list.first.id : '';
                                  }
                                });
                              }
                            : null,
                        deleteIconColor: Colors.redAccent,
                        backgroundColor: c(widget.theme.bg),
                        selectedColor:
                            c(widget.theme.accent).withValues(alpha: 0.2),
                        side: BorderSide(
                          color: selected
                              ? c(widget.theme.accent)
                              : c(widget.theme.border),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              final p = _newProfile();
              setState(() {
                _list.add(p);
                _selected = p.id;
              });
            },
            icon: Icon(Icons.add, color: c(widget.theme.accentGlow)),
            tooltip: '新增',
          ),
        ],
      ),
    );
  }

  Widget _mobileBottomBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c(widget.theme.border))),
      ),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save, size: 18),
          label: const Text('保存配置'),
          style: FilledButton.styleFrom(
            backgroundColor: c(widget.theme.accent),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c(widget.theme.border))),
      ),
      child: Row(
        children: [
          Text(
            'API 配置管理',
            style: TextStyle(
              color: c(widget.theme.text),
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: c(widget.theme.textMuted)),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _sidebar() {
    return Container(
      width: 192,
      decoration: BoxDecoration(
        border: Border(right: BorderSide(color: c(widget.theme.border))),
      ),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              children: _list.map((p) {
                final selected = p.id == _selected;
                return InkWell(
                  onTap: () => setState(() => _selected = p.id),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    color: selected
                        ? c(widget.theme.accent).withValues(alpha: 0.15)
                        : null,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            p.name.isEmpty ? '未命名' : p.name,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: selected
                                  ? c(widget.theme.accentGlow)
                                  : c(widget.theme.text),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 14),
                          color: Colors.redAccent,
                          onPressed: () {
                            setState(() {
                              _list.removeWhere((x) => x.id == p.id);
                              if (_selected == p.id) {
                                _selected = _list.isNotEmpty ? _list.first.id : '';
                              }
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 24,
                            minHeight: 24,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: OutlinedButton.icon(
              onPressed: () {
                final p = _newProfile();
                setState(() {
                  _list.add(p);
                  _selected = p.id;
                });
              },
              icon: const Icon(Icons.add, size: 14),
              label: const Text('新增'),
              style: OutlinedButton.styleFrom(
                foregroundColor: c(widget.theme.textMuted),
                side: BorderSide(color: c(widget.theme.border)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _editor() {
    final current = _current;
    if (current == null) {
      return Center(
        child: Text(
          '点击左侧新增或选择配置',
          style: TextStyle(color: c(widget.theme.textMuted), fontSize: 13),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _field('名称', _input(
            fieldKey: 'name',
            value: current.name,
            onChanged: (v) => current.name = v,
            hint: '例：我的 OpenAI',
          )),
          const SizedBox(height: 16),
          _field('API 格式', _formatPicker(current)),
          const SizedBox(height: 16),
          _field('Base URL', _input(
            fieldKey: 'baseUrl',
            value: current.baseUrl,
            onChanged: (v) => current.baseUrl = v,
            hint: _formatDefaults[current.apiFormat]!.baseUrl,
            mono: true,
          )),
          const SizedBox(height: 16),
          _field('API Key', _input(
            fieldKey: 'apiKey',
            value: current.apiKey,
            onChanged: (v) => current.apiKey = v,
            hint: 'sk-...',
            obscure: true,
            mono: true,
          )),
          if (current.apiFormat != ApiFormat.grsai) ...[
            const SizedBox(height: 16),
            _field('默认模型（可选）', _input(
              fieldKey: 'defaultModel',
              value: current.defaultModel ?? '',
              onChanged: (v) => current.defaultModel = v,
              hint: _formatDefaults[current.apiFormat]!.defaultModel ?? '',
              mono: true,
            )),
          ],
        ],
      ),
    );
  }

  Widget _formatPicker(Profile current) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          children: ApiFormat.values.map((fmt) {
            final selected = current.apiFormat == fmt;
            final label = switch (fmt) {
              ApiFormat.grsai => 'grsai',
              ApiFormat.openai => 'OpenAI 兼容',
              ApiFormat.gemini => 'Gemini 兼容',
            };
            return InkWell(
              onTap: () {
                final d = _formatDefaults[fmt]!;
                setState(() {
                  current.apiFormat = fmt;
                  current.baseUrl = d.baseUrl;
                  current.defaultModel = d.defaultModel;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: selected
                        ? c(widget.theme.accent)
                        : c(widget.theme.border),
                  ),
                  borderRadius: BorderRadius.circular(6),
                  color: selected
                      ? c(widget.theme.accent).withValues(alpha: 0.15)
                      : null,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected
                        ? c(widget.theme.accentGlow)
                        : c(widget.theme.textMuted),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 6),
        Text(
          current.apiFormat == ApiFormat.grsai
              ? 'grsai 格式支持 GPT Images 和 Nano Banana，模型在生成时选择'
              : '第三方 OpenAI/Gemini 兼容供应商，需填写默认模型名',
          style: TextStyle(fontSize: 11, color: c(widget.theme.textMuted)),
        ),
      ],
    );
  }

  Widget _field(String label, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1,
            color: c(widget.theme.textMuted),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  Widget _input({
    required String fieldKey,
    required String value,
    required ValueChanged<String> onChanged,
    required String hint,
    bool obscure = false,
    bool mono = false,
  }) {
    return TextFormField(
      key: ValueKey('${fieldKey}_$_selected'),
      initialValue: value,
      onChanged: onChanged,
      obscureText: obscure,
      keyboardType: fieldKey == 'baseUrl'
          ? TextInputType.url
          : (obscure ? TextInputType.visiblePassword : TextInputType.text),
      autocorrect: false,
      enableSuggestions: false,
      style: mono
          ? AppTypography.mono(color: c(widget.theme.text), size: 12)
          : TextStyle(color: c(widget.theme.text), fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c(widget.theme.textMuted)),
        filled: true,
        fillColor: c(widget.theme.bg),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c(widget.theme.border)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c(widget.theme.border)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c(widget.theme.accent)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c(widget.theme.border))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: widget.onClose,
            child: Text('取消', style: TextStyle(color: c(widget.theme.textMuted))),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save, size: 14),
            label: const Text('保存'),
            style: FilledButton.styleFrom(
              backgroundColor: c(widget.theme.accent),
            ),
          ),
        ],
      ),
    );
  }
}
