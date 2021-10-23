import 'package:syphon/store/events/ephemeral/m.read/model.dart';
import 'package:syphon/store/events/messages/model.dart';
import 'package:syphon/store/events/model.dart';
import 'package:syphon/store/events/reactions/model.dart';
import 'package:syphon/store/events/redaction/model.dart';

import './actions.dart';
import './state.dart';

EventStore eventReducer([EventStore state = const EventStore(), dynamic action]) {
  switch (action.runtimeType) {
    case SetEvents:
      final roomId = action.roomId;
      final events = Map<String, List<Event>>.from(state.events);
      events[roomId] = action.state;
      return state.copyWith(events: events);

    case SetReactions:
      final reactionsUpdated = Map<String, List<Reaction>>.from(
        state.reactions,
      );

      for (final Reaction reaction in action.reactions ?? []) {
        final reactionEventId = reaction.relEventId;
        final exists = reactionsUpdated.containsKey(reactionEventId);

        if (exists) {
          final existing = reactionsUpdated[reactionEventId]!;
          if (existing.indexWhere((value) => value.id == reaction.id) == -1) {
            reactionsUpdated[reactionEventId!] = [...existing, reaction];
          }
        } else if (reactionEventId != null) {
          reactionsUpdated[reactionEventId] = [reaction];
        }
      }

      return state.copyWith(reactions: reactionsUpdated);

    case AddMessages:
      final _action = action as AddMessages;
      if (action.messages.isEmpty) {
        return state;
      }

      final roomId = _action.roomId;

      final messages = Map<String, List<Message>>.from(
        state.messages,
      );

      // convert to map to merge old and new messages based on ids
      final messagesOld = Map<String, Message>.fromIterable(
        messages[roomId] ?? [],
        key: (msg) => msg.id,
        value: (msg) => msg,
      );

      final messagesNew = Map<String, Message>.fromIterable(
        action.messages,
        key: (msg) => msg.id,
        value: (msg) => msg,
      );

      // prioritize new message data though over the old (invalidates using Map overwrite)
      final messagesAll = messagesOld..addAll(messagesNew);
      messages[roomId] = messagesAll.values.toList();

      // remove locally saved outbox messages if they've now been received from a server
      if (state.outbox.containsKey(roomId) && state.outbox[roomId]!.isNotEmpty) {
        final outbox = Map<String, Message>.from(state.outbox[roomId] ?? {});

        // removed based on eventId, not tempId
        outbox.removeWhere(
          (tempId, outmessage) => messagesAll.containsKey(outmessage.id),
        );

        final outboxNew = Map<String, Map<String, Message>>.from(state.outbox);

        outboxNew[roomId] = outbox;

        return state.copyWith(messages: messages, outbox: outboxNew);
      }

      // otherwise, save messages
      return state.copyWith(messages: messages);

    case AddMessagesDecrypted:
      final _action = action as AddMessagesDecrypted;
      final roomId = _action.roomId;

      if (_action.messages.isEmpty) {
        return state;
      }

      final messages = Map<String, List<Message>>.from(
        state.messagesDecrypted,
      );

      // convert to map to merge old and new messages based on ids
      final messagesOld = Map<String, Message>.fromIterable(
        messages[roomId] ?? [],
        key: (msg) => msg.id,
        value: (msg) => msg,
      );

      final messagesNew = Map<String, Message>.fromIterable(
        action.messages,
        key: (msg) => msg.id,
        value: (msg) => msg,
      );

      // prioritize new message data though over the old (invalidates using Set)
      final messagesAll = messagesOld..addAll(messagesNew);
      messages[roomId] = messagesAll.values.toList();

      // otherwise, save messages
      return state.copyWith(messagesDecrypted: messages);
    case SaveOutboxMessage:
      final tempId = (action as SaveOutboxMessage).tempId;
      final message = action.pendingMessage;
      final roomId = message.roomId!;

      final outbox = Map<String, Message>.from(state.outbox[roomId] ?? {});

      outbox.addAll({tempId: message});

      final outboxNew = Map<String, Map<String, Message>>.from(state.outbox);

      outboxNew[roomId] = outbox;

      return state.copyWith(outbox: outboxNew);

    case DeleteOutboxMessage:
      final message = (action as DeleteOutboxMessage).message;
      final roomId = message.roomId!;

      final outbox = Map<String, Message>.from(state.outbox[roomId] ?? {});

      outbox.removeWhere((tempId, outmessage) => message.id == outmessage.id);

      final outboxNew = Map<String, Map<String, Message>>.from(state.outbox);

      outboxNew[roomId] = outbox;

      return state.copyWith(outbox: outboxNew);

    case DeleteLocalMessage:
      final message = (action as DeleteLocalMessage).message;

      final messages = Map<String, List<Message>>.from(
        state.messages,
      );

      messages.forEach((key, value) {
        for(var index = 0; index < value.length; index++){
          if (value[index].id == message.id){
            value.remove(value[index]);
          }
        }
       });

      return state.copyWith(messages: messages);

    case SetRedactions:
      if (action.redactions.isEmpty) {
        return state;
      }

      final redactions = Map<String, Redaction>.from(state.redactions);

      final redactionsNew = Map<String, Redaction>.fromIterable(
        action.redactions ?? [],
        key: (redaction) => redaction.redactId,
        value: (redaction) => redaction,
      );

      return state.copyWith(
        redactions: redactions..addAll(redactionsNew),
      );

    case SetReceipts:
      if (action.receipts.isEmpty) {
        return state;
      }

      final roomId = action.roomId;
      final receiptsUpdated = Map<String, Map<String, ReadReceipt>>.from(
        state.receipts,
      );
      final receiptsNew = Map<String, ReadReceipt>.from(
        action.receipts,
      );

      if (receiptsUpdated.containsKey(roomId)) {
        receiptsUpdated[roomId]!.addAll(receiptsNew);
      }

      return state.copyWith(receipts: receiptsUpdated);

    case ResetEvents:
      return EventStore();
    default:
      return state;
  }
}
