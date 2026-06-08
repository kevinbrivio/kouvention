import 'dart:async';
import 'dart:collection';

/// Bounded-concurrency job queue for chat sync operations.
///
/// The remote sync budget is dominated by Firestore + FCM, both of which
/// we already cap at 4-field-state level (one stream per screen, batched
/// writes per transaction). This queue is a *process-local* cap on how
/// many jobs are awaited at once inside the app, so a flurry of
/// `onChatOpened` / `onNotificationReceived` events cannot pile up
/// unbounded Futures on the event loop.
///
/// The queue is intentionally simple: a FIFO of pending jobs, a slot
/// counter, and a `Completer` chain for visibility. No locks, no
/// isolates, no external packages.
class ChatSyncQueue {
  ChatSyncQueue({this.maxConcurrent = 4});

  final int maxConcurrent;

  final Queue<_PendingJob> _pending = Queue<_PendingJob>();
  int _inFlight = 0;
  final _inFlightController = StreamController<List<String>>.broadcast();
  final _allJobsController = StreamController<List<String>>.broadcast();
  final Set<String> _inFlightLabels = <String>{};
  final List<String> _allLabels = <String>[];

  /// Stream of currently in-flight job labels. Replays an empty list on
  /// subscribe. Useful for a "syncing N items..." UI surface.
  Stream<List<String>> get inFlightLabels async* {
    yield List.unmodifiable(_inFlightLabels);
    yield* _inFlightController.stream;
  }

  /// Stream of all jobs enqueued (pending + in-flight) since boot.
  /// Useful for debugging only.
  Stream<List<String>> get allLabels => _allJobsController.stream;

  /// True when no pending and no in-flight jobs remain.
  bool get isIdle => _pending.isEmpty && _inFlight == 0;

  /// Number of jobs currently executing.
  int get inFlightCount => _inFlight;

  /// Enqueue a job. The [label] shows up in [inFlightLabels] and is
  /// useful for logging. Duplicates are allowed; FIFO order is honored.
  ///
  /// The returned [Future] completes when the job itself completes. If
  /// you don't care about the result, fire-and-forget with
  /// `unawaited(queue.enqueue(...))`.
  Future<T> enqueue<T>(String label, Future<T> Function() job) {
    final completer = Completer<T>();
    _pending.add(
      _PendingJob(label: label, job: () async {
        try {
          completer.complete(await job());
        } catch (e, st) {
          completer.completeError(e, st);
        }
      }),
    );
    _allLabels.add(label);
    _allJobsController.add(List.unmodifiable(_allLabels));
    _drain();
    return completer.future;
  }

  void _drain() {
    while (_inFlight < maxConcurrent && _pending.isNotEmpty) {
      final next = _pending.removeFirst();
      _inFlight++;
      _inFlightLabels.add(next.label);
      _inFlightController.add(List.unmodifiable(_inFlightLabels));

      // Detach from the event loop so callers can return immediately.
      Future.microtask(() async {
        try {
          await next.job();
        } finally {
          _inFlight--;
          _inFlightLabels.remove(next.label);
          _inFlightController.add(List.unmodifiable(_inFlightLabels));
          _drain();
        }
      });
    }
  }

  /// Wait until the queue is idle. Used by tests and graceful shutdown.
  Future<void> drain() async {
    while (!isIdle) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  }

  Future<void> close() async {
    await _inFlightController.close();
    await _allJobsController.close();
  }
}

class _PendingJob {
  _PendingJob({required this.label, required this.job});
  final String label;
  final Future<void> Function() job;
}
