import 'dart:async';

import 'package:deutschhelfer/data/repositories/community_failure.dart';
import 'package:deutschhelfer/domain/models/community.dart';
import 'package:deutschhelfer/ui/features/community/view_models/chat_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

ChatMessage msg(String id, int minute, {String sender = 'bob'}) => ChatMessage(
  id: id,
  senderId: sender,
  senderName: sender,
  text: 'text $id',
  createdAt: DateTime(2026, 1, 1, 10, minute),
);

/// A full live page of 30 messages, newest first, ending at [newest].
List<ChatMessage> page(int newest) => [
  for (var m = newest; m > newest - CommunityLimits.pageSize; m--)
    msg('m$m', m),
];

void main() {
  late StreamController<List<ChatMessage>> recent;
  late StreamController<List<ChatMessage>> pending;
  late List<String> sent;
  late List<ChatMessage> olderRequests;
  List<ChatMessage> olderPage = const [];
  Object? sendError;

  ChatViewModel build({Duration minInterval = Duration.zero}) {
    recent = StreamController.broadcast();
    pending = StreamController.broadcast();
    sent = [];
    olderRequests = [];
    return ChatViewModel(
      watchRecent: () => recent.stream,
      watchPending: () => pending.stream,
      loadOlderPage: (before) async {
        olderRequests.add(before);
        return olderPage;
      },
      sendText: (text) async {
        sent.add(text);
        if (sendError != null) throw sendError!;
      },
      minInterval: minInterval,
    )..start();
  }

  setUp(() {
    olderPage = const [];
    sendError = null;
  });

  tearDown(() async {
    await recent.close();
    await pending.close();
  });

  test('shows the live page newest first', () async {
    final vm = build();
    expect(vm.isLoading, isTrue);
    recent.add([msg('b', 2), msg('a', 1)]);
    await pumpEventQueue();
    expect(vm.isLoading, isFalse);
    expect(vm.messages.map((m) => m.id), ['b', 'a']);
    // A short first page means there is no older history.
    expect(vm.reachedStart, isTrue);
  });

  test(
    'hides blocked senders, and shows them again after unblocking',
    () async {
      final vm = build();
      recent.add([msg('c', 3, sender: 'eve'), msg('b', 2), msg('a', 1)]);
      await pumpEventQueue();
      vm.setHiddenSenders({'eve'});
      expect(vm.messages.map((m) => m.id), ['b', 'a']);
      vm.setHiddenSenders({});
      expect(vm.messages.map((m) => m.id), ['c', 'b', 'a']);
    },
  );

  test('older pages page past hidden senders (review F-08)', () async {
    final vm = build();
    // A full live page, all from a blocked sender.
    recent.add([
      for (var m = 40; m > 40 - CommunityLimits.pageSize; m--)
        msg('m$m', m, sender: 'eve'),
    ]);
    await pumpEventQueue();
    vm.setHiddenSenders({'eve'});
    expect(vm.messages, isEmpty);
    olderPage = [msg('a', 1)];
    await vm.loadOlder();
    expect(olderRequests.single.id, 'm11');
    expect(vm.messages.map((m) => m.id), ['a']);
  });

  test('keeps messages pushed out of the live page by newer ones', () async {
    final vm = build();
    recent.add(page(40)); // m40..m11
    await pumpEventQueue();
    recent.add(page(41)); // m41..m12: m11 is pushed out
    await pumpEventQueue();
    expect(vm.messages.map((m) => m.id), contains('m11'));
    expect(vm.messages.first.id, 'm41');
  });

  test('drops messages that leave because they were removed', () async {
    final vm = build();
    recent.add([msg('c', 3), msg('b', 2), msg('a', 1)]);
    await pumpEventQueue();
    recent.add([msg('c', 3), msg('a', 1)]); // b withdrawn or removed
    await pumpEventQueue();
    expect(vm.messages.map((m) => m.id), ['c', 'a']);
  });

  test('shows own pending messages ahead of the conversation', () async {
    final vm = build();
    recent.add([msg('a', 1)]);
    pending.add([
      ChatMessage(
        id: 'p',
        senderId: 'me',
        text: 'www.daad.de',
        createdAt: DateTime(2026, 1, 1, 10, 5),
        status: MessageStatus.pending,
      ),
    ]);
    await pumpEventQueue();
    expect(vm.messages.map((m) => m.id), ['p', 'a']);
  });

  test('pages older history from the oldest loaded message', () async {
    final vm = build();
    recent.add(page(40));
    await pumpEventQueue();
    expect(vm.reachedStart, isFalse);
    olderPage = [msg('m10', 10), msg('m9', 9)];
    await vm.loadOlder();
    expect(olderRequests.single.id, 'm11');
    expect(vm.messages.last.id, 'm9');
    expect(vm.reachedStart, isTrue);
    await vm.loadOlder();
    expect(olderRequests, hasLength(1));
  });

  test('send trims, rejects empty and over-long text', () async {
    final vm = build();
    expect(await vm.send('   '), isFalse);
    expect(
      await vm.send('x' * (CommunityLimits.messageMaxLength + 1)),
      isFalse,
    );
    expect(await vm.send('  hi  '), isTrue);
    await pumpEventQueue();
    expect(sent, ['hi']);
  });

  test('a server refusal surfaces as a send failure', () async {
    sendError = const CommunityException(CommunityFailure.notAllowed);
    final vm = build();
    expect(await vm.send('hi'), isTrue);
    await pumpEventQueue();
    expect(vm.sendFailure, CommunityFailure.notAllowed);
    vm.clearSendFailure();
    expect(vm.sendFailure, isNull);
  });

  test('stream errors show the failed state and retry recovers', () async {
    final vm = build();
    recent.addError(StateError('permission-denied'));
    await pumpEventQueue();
    expect(vm.failed, isTrue);
    vm.retry();
    recent.add([msg('a', 1)]);
    await pumpEventQueue();
    expect(vm.failed, isFalse);
    expect(vm.messages, hasLength(1));
  });
}
