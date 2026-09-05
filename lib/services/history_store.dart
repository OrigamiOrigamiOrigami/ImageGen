import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/app_models.dart';
import 'config_service.dart';

/// 按 ISO 周拆分的历史存储：`history/2026-W36.json`
class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  /// 启动时最多扫描最近多少周（更早的仍保留在磁盘）。
  static const int maxLoadWeeks = 52;

  /// 可选上限：50 / 100 / 200 / 500 / 1000
  static const List<int> maxItemsChoices = [50, 100, 200, 500, 1000];
  static const int defaultMaxItems = 200;

  String? _dir;
  /// 本次 load 读进内存的条目 id（用于区分「删除」与「未加载」）。
  final Set<String> _loadedItemIds = {};
  final Map<String, String> _loadedIdToWeek = {};

  void init(String supportDir) {
    _dir = p.join(supportDir, 'history');
  }

  String get directory {
    final d = _dir;
    if (d == null) throw StateError('HistoryStore not initialized');
    return d;
  }

  Future<void> _ensureDir() async {
    final dir = Directory(directory);
    if (!dir.existsSync()) await dir.create(recursive: true);
  }

  /// ISO 周键，例如 `2026-W36`（周四定年）。
  static String weekKeyFor(DateTime dt) {
    final day = DateTime.utc(dt.year, dt.month, dt.day);
    final thursday = day.add(Duration(days: DateTime.thursday - day.weekday));
    final year = thursday.year;
    final jan4 = DateTime.utc(year, 1, 4);
    final week1Monday = jan4.subtract(Duration(days: jan4.weekday - 1));
    final monday = day.subtract(Duration(days: day.weekday - 1));
    final week = monday.difference(week1Monday).inDays ~/ 7 + 1;
    return '$year-W${week.toString().padLeft(2, '0')}';
  }

  static String weekKeyForItem(HistoryItem item) {
    final parsed = DateTime.tryParse(item.createdAt);
    return weekKeyFor(parsed ?? DateTime.now());
  }

  String _pathForWeek(String weekKey) => p.join(directory, '$weekKey.json');

  /// [maxItems] 控制应用内列表最多展示多少条；超出部分仍留在周文件里。
  Future<List<HistoryItem>> load({int maxItems = defaultMaxItems}) async {
    await _ensureDir();
    _loadedItemIds.clear();
    _loadedIdToWeek.clear();

    final limit = maxItems < 1 ? defaultMaxItems : maxItems;

    final files = <File>[];
    await for (final entity in Directory(directory).list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.endsWith('.json')) continue;
      if (!RegExp(r'^\d{4}-W\d{2}\.json$').hasMatch(name)) continue;
      files.add(entity);
    }

    files.sort((a, b) => p.basename(b.path).compareTo(p.basename(a.path)));

    final items = <HistoryItem>[];
    var weeksRead = 0;
    for (final file in files) {
      if (weeksRead >= maxLoadWeeks) break;
      if (items.length >= limit) break;
      try {
        final json =
            jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        final week = json['week'] as String? ??
            p.basenameWithoutExtension(file.path);
        final list = (json['items'] as List<dynamic>?)
                ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        weeksRead++;
        for (final item in list) {
          if (items.length >= limit) break;
          items.add(item);
          _loadedItemIds.add(item.id);
          _loadedIdToWeek[item.id] = week;
        }
      } catch (e) {
        ConfigService.instance.log('WARN', 'History week load failed: $e');
      }
    }

    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  /// 合并写回：只更新/删除本次加载过的条目，未加载的磁盘记录保留。
  Future<void> save(List<HistoryItem> history) async {
    await _ensureDir();

    final memById = <String, HistoryItem>{
      for (final h in history) h.id: h,
    };
    final deletedIds = _loadedItemIds.difference(memById.keys.toSet());

    final weeksToTouch = <String>{};
    for (final h in history) {
      weeksToTouch.add(weekKeyForItem(h));
    }
    for (final id in deletedIds) {
      final w = _loadedIdToWeek[id];
      if (w != null) weeksToTouch.add(w);
    }

    for (final week in weeksToTouch) {
      final disk = await _readWeekFile(week);
      final next = <HistoryItem>[];
      final seen = <String>{};

      for (final d in disk) {
        if (deletedIds.contains(d.id)) continue;
        final updated = memById[d.id];
        if (updated != null) {
          next.add(updated);
          seen.add(d.id);
        } else if (!_loadedItemIds.contains(d.id)) {
          // 因上限未加载进内存的条目，原样保留
          next.add(d);
          seen.add(d.id);
        } else {
          // 已加载但不在当前 history、也不在 deletedIds —— 不应发生
          next.add(d);
          seen.add(d.id);
        }
      }

      for (final h in history) {
        if (weekKeyForItem(h) != week) continue;
        if (seen.contains(h.id)) continue;
        next.add(h);
      }

      next.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (next.isEmpty) {
        final f = File(_pathForWeek(week));
        if (f.existsSync()) {
          try {
            await f.delete();
          } catch (_) {}
        }
      } else {
        await _writeWeek(week, next);
      }
    }

    _loadedItemIds
      ..clear()
      ..addAll(memById.keys);
    _loadedIdToWeek
      ..clear()
      ..addEntries(
        history.map((h) => MapEntry(h.id, weekKeyForItem(h))),
      );
  }

  /// 因展示上限从内存丢掉的条目，不视为用户删除（磁盘保留）。
  void dropFromMemory(Iterable<String> ids) {
    for (final id in ids) {
      _loadedItemIds.remove(id);
      _loadedIdToWeek.remove(id);
    }
  }

  Future<void> _writeWeek(String weekKey, List<HistoryItem> items) async {
    final file = File(_pathForWeek(weekKey));
    final payload = {
      'week': weekKey,
      'items': items.map((e) => e.toJson()).toList(),
    };
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(payload),
    );
  }

  /// 把旧版嵌在 config.json 里的 history 拆进周文件（一次性迁移）。
  Future<void> migrateFromEmbedded(List<HistoryItem> embedded) async {
    if (embedded.isEmpty) return;
    await _ensureDir();
    final byWeek = <String, List<HistoryItem>>{};
    for (final item in embedded) {
      final key = weekKeyForItem(item);
      (byWeek[key] ??= []).add(item);
    }
    for (final entry in byWeek.entries) {
      entry.value.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final existing = await _readWeekFile(entry.key);
      final merged = <String, HistoryItem>{
        for (final h in existing) h.id: h,
        for (final h in entry.value) h.id: h,
      };
      final list = merged.values.toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      await _writeWeek(entry.key, list);
    }
    ConfigService.instance.log(
      'INFO',
      'Migrated ${embedded.length} history items into ${byWeek.length} week files',
    );
  }

  Future<List<HistoryItem>> _readWeekFile(String weekKey) async {
    final file = File(_pathForWeek(weekKey));
    if (!file.existsSync()) return [];
    try {
      final json =
          jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      return (json['items'] as List<dynamic>?)
              ?.map((e) => HistoryItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [];
    } catch (_) {
      return [];
    }
  }
}
