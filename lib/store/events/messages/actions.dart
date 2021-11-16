import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:redux/redux.dart';
import 'package:redux_thunk/redux_thunk.dart';
import 'package:syphon/global/libs/matrix/constants.dart';
import 'package:syphon/global/libs/matrix/index.dart';
import 'package:syphon/global/print.dart';
import 'package:syphon/store/alerts/actions.dart';
import 'package:syphon/store/crypto/actions.dart';
import 'package:syphon/store/crypto/events/actions.dart';
import 'package:syphon/store/events/actions.dart';
import 'package:syphon/store/events/messages/formatters.dart';
import 'package:syphon/store/events/messages/model.dart';
import 'package:syphon/store/events/selectors.dart';
import 'package:syphon/store/index.dart';
import 'package:syphon/store/media/encryption.dart';
import 'package:syphon/store/rooms/actions.dart';
import 'package:syphon/store/rooms/room/model.dart';
import 'package:syphon/store/user/model.dart';

///
/// Mutate Messages
///
/// Add/mutate to accomodate all the required, necessary
/// mutations by matrix after the message has been sent
/// such as reactions, redactions, and edits
///
ThunkAction<AppState> mutateMessages({List<Message>? messages, List<Message>? existing}) {
  return (Store<AppState> store) async {
    final reactions = store.state.eventStore.reactions;
    final redactions = store.state.eventStore.redactions;

    final revisedMessages = await compute(reviseMessagesThreaded, {
      'reactions': reactions,
      'redactions': redactions,
      'messages': (messages ?? []) + (existing ?? []),
    });

    return revisedMessages;
  };
}

///
/// Mutate Messages All
///
/// Add/mutate to accomodate all messages avaiable with
/// the required, necessary mutations by matrix after the
/// message has been sent (such as reactions, redactions, and edits)
///
ThunkAction<AppState> mutateMessagesAll() {
  return (Store<AppState> store) async {
    final rooms = store.state.roomStore.roomList;

    await Future.wait(rooms.map((room) async {
      try {
        await store.dispatch(mutateMessagesRoom(room: room));
      } catch (error) {
        printError('[mutateMessagesAll] error ${room.id} ${error.toString()}');
      }
    }));
  };
}

///
/// Mutate Messages All
///
/// Run through all room messages to accomodate the required,
/// necessary mutations by matrix after the message has been sent
/// such as reactions, redactions, and edits
///
ThunkAction<AppState> mutateMessagesRoom({required Room room}) {
  return (Store<AppState> store) async {
    final messages = store.state.eventStore.messages[room.id];
    final decrypted = store.state.eventStore.messagesDecrypted[room.id];
    final reactions = store.state.eventStore.reactions;
    final redactions = store.state.eventStore.redactions;

    final mutations = [
      compute(reviseMessagesThreaded, {
        'messages': messages,
        'reactions': reactions,
        'redactions': redactions,
      })
    ];

    if (room.encryptionEnabled) {
      mutations.add(compute(reviseMessagesThreaded, {
        'messages': decrypted,
        'reactions': reactions,
        'redactions': redactions,
      }));
    }

    final messagesLists = await Future.wait(mutations);

    await store.dispatch(addMessages(
      room: Room(id: room.id),
      messages: messagesLists[0],
    ));

    if (room.encryptionEnabled) {
      await store.dispatch(addMessagesDecrypted(
        room: Room(id: room.id),
        messages: messagesLists[1],
      ));
    }
  };
}

/// Send Message
ThunkAction<AppState> sendMessage({
  required String roomId,
  required Message message,
  Message? related,
  File? file,
  bool edit = false,
}) {
  return (Store<AppState> store) async {
    final room = store.state.roomStore.rooms[roomId]!;

    try {
      store.dispatch(UpdateRoom(id: room.id, sending: true));

      final reply = store.state.roomStore.rooms[room.id]!.reply;
      final userId = store.state.authStore.user.userId!;
      // if you're incredibly unlucky, and fast, you could have a problem here
      final tempId = Random.secure().nextInt(1 << 32).toString();

      // pending outbox message
      Message pending = await formatMessageContent(
        tempId: tempId,
        userId: userId,
        message: message,
        related: related,
        room: room,
        file: file,
        edit: edit,
      );

      if (reply != null && reply.body != null) {
        pending = formatMessageReply(room, pending, reply);
      }

      // Save unsent message to outbox
      if (!edit) {
        store.dispatch(SaveOutboxMessage(
          tempId: tempId,
          pendingMessage: pending,
        ));
      }

      final data = await MatrixApi.sendMessage(
        protocol: store.state.authStore.protocol,
        homeserver: store.state.authStore.user.homeserver,
        accessToken: store.state.authStore.user.accessToken,
        roomId: room.id,
        message: pending.content,
        trxId: DateTime.now().millisecond.toString(),
      );

      if (data['errcode'] != null) {
        if (!edit) {
          store.dispatch(SaveOutboxMessage(
            tempId: tempId,
            pendingMessage: pending.copyWith(
              timestamp: DateTime.now().millisecondsSinceEpoch,
              pending: false,
              syncing: false,
              failed: true,
            ),
          ));
        }

        throw data['error'];
      }

      if (edit) {
        return true;
      }

      // Update sent message with event id but needs
      // to be syncing to remove from outbox
      store.dispatch(SaveOutboxMessage(
        tempId: tempId,
        pendingMessage: pending.copyWith(
          id: data['event_id'],
          timestamp: DateTime.now().millisecondsSinceEpoch,
          syncing: true,
        ),
      ));

      return true;
    } catch (error) {
      store.dispatch(addAlert(
        error: error,
        message: error.toString(),
        origin: 'sendMessage',
      ));
      return false;
    } finally {
      store.dispatch(UpdateRoom(
        id: room.id,
        sending: false,
        reply: Message(),
      ));
    }
  };
}

/// Send Encrypted Messages
///
/// Specifically for sending encrypted messages using megolm
ThunkAction<AppState> sendMessageEncrypted({
  required String roomId,
  required Message message, // temp - contains all unencrypted info being sent
  File? file,
  EncryptInfo? info,
}) {
  return (Store<AppState> store) async {
    try {
      final room = store.state.roomStore.rooms[roomId]!;
      final userId = store.state.authStore.user.userId!;

      store.dispatch(UpdateRoom(id: room.id, sending: true));

      // send the key session - if one hasn't been sent
      // or created - to every user within the room
      await store.dispatch(updateKeySessions(room: room));

      // Save unsent message to outbox
      final tempId = Random.secure().nextInt(1 << 32).toString();
      final reply = room.reply;

      // pending outbox message
      Message pending = await formatMessageContent(
        tempId: tempId,
        userId: userId,
        message: message,
        room: room,
        file: file,
        info: info,
      );

      final unencryptedData = {};

      if (reply != null && reply.body != null) {
        unencryptedData['m.relates_to'] = {
          'm.in_reply_to': {'event_id': reply.id}
        };

        pending = formatMessageReply(room, pending, reply);
      }

      store.dispatch(SaveOutboxMessage(
        tempId: tempId,
        pendingMessage: pending,
      ));

      // Encrypt the message event
      final encryptedEvent = await store.dispatch(
        encryptMessageContent(
          roomId: room.id,
          content: pending.content,
          eventType: EventTypes.message,
        ),
      );

      final data = await MatrixApi.sendMessageEncrypted(
        protocol: store.state.authStore.protocol,
        homeserver: store.state.authStore.user.homeserver,
        unencryptedData: unencryptedData,
        accessToken: store.state.authStore.user.accessToken,
        trxId: DateTime.now().millisecond.toString(),
        roomId: room.id,
        senderKey: encryptedEvent['sender_key'],
        ciphertext: encryptedEvent['ciphertext'],
        sessionId: encryptedEvent['session_id'],
        deviceId: store.state.authStore.user.deviceId,
      );

      if (data['errcode'] != null) {
        store.dispatch(SaveOutboxMessage(
          tempId: tempId,
          pendingMessage: pending.copyWith(
            timestamp: DateTime.now().millisecondsSinceEpoch,
            pending: false,
            syncing: false,
            failed: true,
          ),
        ));

        throw data['error'];
      }

      store.dispatch(SaveOutboxMessage(
        tempId: tempId,
        pendingMessage: pending.copyWith(
          id: data['event_id'],
          timestamp: DateTime.now().millisecondsSinceEpoch,
          syncing: true,
        ),
      ));

      return true;
    } catch (error) {
      store.dispatch(
        addAlert(
          error: error,
          message: error.toString(),
          origin: 'sendMessageEncrypted',
        ),
      );
      return false;
    } finally {
      store.dispatch(UpdateRoom(id: roomId, sending: false, reply: Message()));
    }
  };
}

Future<bool> isMessageDeletable({required Message message, User? user, Room? room}) async {
  try {
    final powerLevels = await MatrixApi.fetchPowerLevels(
      room: room,
      homeserver: user!.homeserver,
      accessToken: user.accessToken,
    );

    final powerLevelUser = powerLevels['users'];
    final userLevel = powerLevelUser[user.userId];

    if (userLevel == null && message.sender != user.userId) {
      return false;
    }

    if (message.sender == user.userId || userLevel > 0) {
      return true;
    }

    return false;
  } catch (error) {
    debugPrint('[deleteMessage] $error');
    return false;
  }
}
