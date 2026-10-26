import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../data/repositories/community_failure.dart';
import '../../../../domain/models/community.dart';

/// Chat state shared by group chats and direct conversations.
///
/// One live listener covers the newest page. Older pages are one-off reads.
/// Messages pushed out of the live page by newer ones are kept, while
/// messages that leave it because they were removed or withdrawn are
/// dropped.
class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required this.watchRecent,
    required this.loadOlderPage,
    required this.sendText,
    this.watchPending,
    this.minInterval = CommunityLimits.minPostInterval,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final Stream<List<ChatMessage>> Function() watchRecent;
  final Stream<List<ChatMessage>> Function()? watchPending;
  final Future<List<ChatMessage>> Function(ChatMessage before) loadOlderPage;
  final Future<void> Function(String text) sendText;
  final Duration minInterval;
  final DateTime Function() _clock;

  StreamSubscription<List<ChatMessage>>? _recentSub;
  StreamSubscription<List<ChatMessage>>? _pendingSub;

  final Map<String, ChatMessage> _byId = {};
  Set<String> _liveIds = {};
  List<ChatMessage> _pending = const [];
  Set<String> _hiddenSenders = const {};

  bool _loading = true;
  bool _failed = false;
  bool _loadingOlder = false;
  bool _reachedStart = false;
  bool _sending = false;
  CommunityFailure? _sendFailure;
  DateTime? _lastSend;
  bool _disposed = false;

  bool get isLoading => _loading;
  bool get failed => _failed;
  bool get isLoadingOlder => _loadingOlder;
  bool get reachedStart => _reachedStart;
  bool get isSending => _sending;
  CommunityFailure? get sendFailure => _sendFailure;

  /// Newest first: own pending messages, then the conversation.
  List<ChatMessage> get messages {
    final visible =
        _byId.values.where((m) => !_hiddenSenders.contains(m.senderId)).toList()
          ..sort((a, b) {
            final at = a.createdAt, bt = b.createdAt;
            if (at == null && bt == null) return 0;
            if (at == null) return -1;
            if (bt == null) return 1;
            return bt.compareTo(at);
          });
    final pending = _pending.where((m) => !_byId.containsKey(m.id)).toList();
    return [...pending, ...visible];
  }

  /// Hides messages from people this user blocked. Filtering is local: the
  /// blocked list is private, so the server cannot filter shared history.
  void setHiddenSenders(Set<String> senders) {
    _hiddenSenders = senders;
    _notify();
  }

  void start() {
    _recentSub ??= watchRecent().listen(_onRecent, onError: _onError);
    _pendingSub ??= watchPending?.call().listen((items) {
      _pending = items;
      _notify();
    }, onError: (Object _) {});
  }

  void retry() {
    unawaited(_recentSub?.cancel());
    _recentSub = null;
    _failed = false;
    _loading = true;
    _notify();
    start();
  }

  void _onRecent(List<ChatMessage> page) {
    final newIds = {for (final m in page) m.id};
    final oldestLive = page.isEmpty ? null : page.last.createdAt;
    for (final id in _liveIds.difference(newIds)) {
      final gone = _byId[id];
      final pushedOut =
          page.length >= CommunityLimits.pageSize &&
          gone?.createdAt != null &&
          oldestLive != null &&
          gone!.createdAt!.isBefore(oldestLive);
      if (!pushedOut) _byId.remove(id);
    }
    for (final message in page) {
      _byId[message.id] = message;
    }
    _liveIds = newIds;
    if (_loading && page.length < CommunityLimits.pageSize) {
      _reachedStart = true;
    }
    _loading = false;
    _failed = false;
    _notify();
  }

  void _onError(Object _) {
    _loading = false;
    _failed = true;
    _notify();
  }

  Future<void> loadOlder() async {
    if (_loadingOlder || _reachedStart || _byId.isEmpty) return;
    // The cursor comes from every loaded message, including hidden ones, so
    // a blocked sender's messages cannot stall paging.
    final dated = _byId.values.where((m) => m.createdAt != null);
    final oldest = dated.isEmpty
        ? _byId.values.first
        : dated.reduce((a, b) => a.createdAt!.isBefore(b.createdAt!) ? a : b);
    _loadingOlder = true;
    _notify();
    try {
      final page = await loadOlderPage(oldest);
      for (final message in page) {
        _byId[message.id] = message;
      }
      if (page.length < CommunityLimits.pageSize) _reachedStart = true;
    } catch (_) {
      // Leave older history unloaded; the user can scroll again to retry.
    } finally {
      _loadingOlder = false;
      _notify();
    }
  }

  /// Time left before another send is allowed.
  Duration get cooldownLeft {
    final last = _lastSend;
    if (last == null) return Duration.zero;
    final left = minInterval - _clock().difference(last);
    return left.isNegative ? Duration.zero : left;
  }

  /// Validates, throttles and hands the message to the backend. Returns true
  /// when it was accepted locally.
  ///
  /// Firestore applies the write to the local cache at once and completes the
  /// returned future only when the server confirms, which can be much later
  /// when offline. The composer therefore does not wait for confirmation;
  /// the message shows as sending, and a server refusal surfaces as
  /// [sendFailure].
  Future<bool> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || text.length > CommunityLimits.messageMaxLength) {
      return false;
    }
    final wait = cooldownLeft;
    if (wait > Duration.zero) await Future<void>.delayed(wait);

    _sendFailure = null;
    _lastSend = _clock();
    _sending = true;
    _notify();
    unawaited(
      sendText(text)
          .then(
            (_) {},
            onError: (Object error) {
              _sendFailure = error is CommunityException
                  ? error.failure
                  : CommunityFailure.unknown;
            },
          )
          .whenComplete(() {
            _sending = false;
            _notify();
          }),
    );
    return true;
  }

  void clearSendFailure() {
    if (_sendFailure == null) return;
    _sendFailure = null;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_recentSub?.cancel());
    unawaited(_pendingSub?.cancel());
    super.dispose();
  }
}
