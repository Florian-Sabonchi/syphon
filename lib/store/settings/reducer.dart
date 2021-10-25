import 'package:syphon/store/settings/chat-settings/model.dart';
import 'package:syphon/store/settings/notification-settings/actions.dart';
import './actions.dart';
import './state.dart';

SettingsStore settingsReducer(
    [SettingsStore state = const SettingsStore(), dynamic action]) {
  switch (action.runtimeType) {
    case SetLoading:
      return state.copyWith(
        loading: action.loading,
      );
    case SetPrimaryColor:
      return state.copyWith(
        themeSettings: state.themeSettings.copyWith(primaryColor: action.color),
      );
    case SetAccentColor:
      return state.copyWith(
        themeSettings: state.themeSettings.copyWith(accentColor: action.color),
      );
    case SetAppBarColor:
      return state.copyWith(
        themeSettings: state.themeSettings.copyWith(appBarColor: action.color),
      );
    case SetFontName:
      return state.copyWith(
        themeSettings: state.themeSettings.copyWith(fontName: action.fontName),
      );
    case SetFontSize:
      return state.copyWith(
        themeSettings: state.themeSettings.copyWith(fontSize: action.fontSize),
      );
    case SetMessageSize:
      return state.copyWith(
        themeSettings:
            state.themeSettings.copyWith(messageSize: action.messageSize),
      );
    case SetAvatarShape:
      return state.copyWith(
        themeSettings:
            state.themeSettings.copyWith(avatarShape: action.avatarShape),
      );
    case SetMainFabType:
      final _action = action as SetMainFabType;
      return state.copyWith(
        themeSettings:
            state.themeSettings.copyWith(mainFabType: _action.fabType),
      );
    case SetMainFabLocation:
      final _action = action as SetMainFabLocation;
      return state.copyWith(
        themeSettings:
            state.themeSettings.copyWith(mainFabLocation: _action.fabLocation),
      );
    case SetDevices:
      return state.copyWith(
        devices: action.devices,
      );
    case SetPusherToken:
      return state.copyWith(
        pusherToken: action.token,
      );
    case LogAppAgreement:
      return state.copyWith(
        alphaAgreement: DateTime.now().millisecondsSinceEpoch.toString(),
      );
    case SetRoomPrimaryColor:
      final chatSettings = Map<String, ChatSetting>.from(state.chatSettings);

      // Initialize chat settings if null
      if (chatSettings[action.roomId] == null) {
        chatSettings[action.roomId] = ChatSetting(
          roomId: action.roomId,
          language: state.language,
        );
      }

      chatSettings[action.roomId] = chatSettings[action.roomId]!.copyWith(
        primaryColor: action.color,
      );
      return state.copyWith(
        chatSettings: chatSettings,
      );
    case SetLanguage:
      return state.copyWith(
        language: action.language,
      );
    case SetThemeType:
      return state.copyWith(
        themeSettings:
            state.themeSettings.copyWith(themeType: action.themeType),
      );
    case ToggleEnterSend:
      return state.copyWith(
        enterSendEnabled: !state.enterSendEnabled,
      );
    case SetSyncInterval:
      return state.copyWith(
        syncInterval: action.syncInterval,
      );
    case SetPollTimeout:
      return state.copyWith(
        syncPollTimeout: action.syncPollTimeout,
      );
    case ToggleTypingIndicators:
      return state.copyWith(
        typingIndicatorsEnabled: !state.typingIndicatorsEnabled,
      );
    case ToggleTimeFormat:
      return state.copyWith(
        timeFormat24Enabled: !state.timeFormat24Enabled,
      );
    case ToggleDismissKeyboard:
      return state.copyWith(
        dismissKeyboardEnabled: !state.dismissKeyboardEnabled,
      );
    case ToggleReadReceipts:
      return state.copyWith(
        readReceiptsEnabled: !state.readReceiptsEnabled,
      );
    case ToggleMembershipEvents:
      return state.copyWith(
        membershipEventsEnabled: !state.membershipEventsEnabled,
      );
    case ToggleRoomTypeBadges:
      return state.copyWith(
        roomTypeBadgesEnabled: !state.roomTypeBadgesEnabled,
      );
    case ToggleNotifications:
      return state.copyWith(
        notificationSettings: state.notificationSettings
            .copyWith(enabled: !state.notificationSettings.enabled),
      );
    case SetNotificationSettings:
      return state.copyWith(notificationSettings: action.settings);
    default:
      return state;
  }
}
