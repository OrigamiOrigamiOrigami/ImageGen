import 'dart:async';

import '../models/app_models.dart';

typedef TaskRunner = Future<void> Function(void Function(int progress) onProgress);

class TaskQueue {
  TaskQueue({required this.maxConcurrent, required this.onUpdate});

  int maxConcurrent;
  final void Function(List<GenTask> tasks) onUpdate;

  final List<GenTask> _tasks = [];
  final List<_QueuedJob> _queue = [];
  int _running = 0;

  List<GenTask> get activeTasks =>
      _tasks.where((t) => t.status != TaskStatus.done).toList();

  bool get hasRunning => _tasks.any(
        (t) =>
            t.status == TaskStatus.running || t.status == TaskStatus.queued,
      );

  void addTask(String id, String prompt, TaskRunner run) {
    _tasks.insert(
      0,
      GenTask(id: id, prompt: prompt),
    );
    _notify();
    _queue.add(_QueuedJob(id: id, run: run));
    _processQueue();
  }

  void _updateTask(String id, {int? progress, TaskStatus? status, String? error}) {
    final idx = _tasks.indexWhere((t) => t.id == id);
    if (idx < 0) return;
    final t = _tasks[idx];
    if (progress != null) t.progress = progress;
    if (status != null) t.status = status;
    if (error != null) t.error = error;
    _notify();
  }

  void _removeTask(String id) {
    _tasks.removeWhere((t) => t.id == id);
    _notify();
  }

  void _notify() => onUpdate(List.unmodifiable(_tasks));

  void _processQueue() {
    while (_running < maxConcurrent && _queue.isNotEmpty) {
      final job = _queue.removeAt(0);
      _running++;
      _runJob(job).whenComplete(() {
        _running--;
        _processQueue();
      });
    }
  }

  Future<void> _runJob(_QueuedJob job) async {
    _updateTask(job.id, status: TaskStatus.running, progress: 0);
    try {
      await job.run((p) => _updateTask(job.id, progress: p));
      _updateTask(job.id, status: TaskStatus.done, progress: 100);
    } catch (e) {
      _updateTask(
        job.id,
        status: TaskStatus.error,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
    Future.delayed(const Duration(seconds: 2), () => _removeTask(job.id));
  }
}

class _QueuedJob {
  _QueuedJob({required this.id, required this.run});
  final String id;
  final TaskRunner run;
}
