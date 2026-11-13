// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get stopSavingTitle => 'Stop saving chats?';

  @override
  String get stopSavingBody =>
      'Saved chats will be erased from this phone (except the ones you chose to save from inside the chat).';

  @override
  String get stopSavingConfirm => 'Stop saving';

  @override
  String get savingOnToast => 'Chats will be saved on this phone (encrypted)';

  @override
  String get savingOffToast => 'Chats won\'t be saved';

  @override
  String get lockOnToast => 'App lock is on';

  @override
  String get lockOffToast => 'App lock removed';

  @override
  String get bioConfirmTitle => 'Confirm fingerprint';

  @override
  String get bioConfirmSubtitle => 'To unlock Wasl with it';

  @override
  String get wipeTitle => 'Erase all chats?';

  @override
  String get wipeBody =>
      'All saved messages and files will be permanently erased from your phone. Your profile and your groups stay.';

  @override
  String get wipeConfirm => 'Erase all';

  @override
  String get wipeDone => 'Everything was erased';

  @override
  String get blockedTitle => 'Blocked';

  @override
  String get blockedEmpty => 'Nobody is blocked.';

  @override
  String get blockedNone => 'Nobody';

  @override
  String personShort(Object id) {
    return 'Person ($id)';
  }

  @override
  String get unblock => 'Unblock';

  @override
  String get editProfileHint => 'Edit name, picture and color';

  @override
  String get privacy => 'Privacy';

  @override
  String get saveChats => 'Save chats on this phone';

  @override
  String get saveChatsOn =>
      'Messages are saved encrypted and are still there next time you open the app.';

  @override
  String get saveChatsOff =>
      'Off: chats are erased when you close the app. You can still save a single chat from inside it.';

  @override
  String get appLock => 'Lock the app with a PIN';

  @override
  String get appLockOn => 'On — tap to remove it';

  @override
  String get appLockOff => 'Optional. Without it the app opens right away.';

  @override
  String get unlockWithFingerprint => 'Unlock with fingerprint';

  @override
  String get autoLock => 'Auto-lock';

  @override
  String get autoLockSub => 'After you leave the app';

  @override
  String get lockNow => 'Immediately';

  @override
  String get lockMinute => '1 minute';

  @override
  String get lock5 => '5 minutes';

  @override
  String get lock15 => '15 minutes';

  @override
  String get wipeAll => 'Erase all chats';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeAuto => 'Auto';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get appColor => 'App color';

  @override
  String get language => 'Language';

  @override
  String get languageAuto => 'Auto';

  @override
  String get languageAutoHint =>
      'Auto: follows your phone (Arabic if the phone is in Arabic, otherwise English).';

  @override
  String get about => 'About';

  @override
  String aboutTagline(Object license) {
    return 'Offline chat • open source ($license)';
  }

  @override
  String get sourceCode => 'Source code on GitHub';

  @override
  String get linkCopied => 'Link copied';

  @override
  String get noBrowser => 'No browser to open the link — copied it instead';

  @override
  String get howItWorks => 'How does Wasl work?';

  @override
  String get howItWorksSub => 'No internet and no server';

  @override
  String get howNoInternetTitle => 'No internet, no server';

  @override
  String get howNoInternetBody =>
      'Phones talk to each other directly over Bluetooth or on the same Wi-Fi / hotspot. No account and no phone number.';

  @override
  String get howMeshTitle => 'Mesh network';

  @override
  String get howMeshBody =>
      'Every phone running Wasl relays for the ones around it, so your message can hop across several phones to reach someone far away.';

  @override
  String get howEncryptionTitle => 'Automatic encryption';

  @override
  String get howEncryptionBody =>
      'Private chats are end-to-end encrypted with keys made automatically — no password. Phones in the middle only pass messages on and can\'t read them.';

  @override
  String get howBothTitle => 'Both at once';

  @override
  String get howBothBody =>
      'Turn on Wi-Fi and Bluetooth together and your phone becomes a bridge: people on one hotspot can reach people on another one through Bluetooth. Calls and video stay inside the same network.';

  @override
  String get howGroupsTitle => 'Groups';

  @override
  String get howGroupsBody =>
      'Open: anyone nearby can join and read. Password or join request: only members can read. A group stays visible as long as one member is nearby.';

  @override
  String get howAdminTitle => 'Group admins';

  @override
  String get howAdminBody =>
      'The owner picks admins, and admins can remove members and delete their messages. In a \"join request\" group the key changes when someone is removed, so they can\'t read new messages; in open and password groups removal is a ban enforced by the apps.';

  @override
  String get howNotifTitle => 'Notifications';

  @override
  String get howNotifBody =>
      'A notification shows the sender and the message. With the app lock on it only says \"New message\", and the phone\'s lock screen never shows the text. You can mute any chat.';

  @override
  String get howSaveTitle => 'Saving is optional';

  @override
  String get howSaveBody =>
      'By default chats aren\'t saved and are erased when the app closes. If you turn saving on they\'re stored encrypted, only on your phone.';

  @override
  String get howSafetyTitle => 'Safety code';

  @override
  String get howSafetyBody =>
      'To be 100% sure you\'re talking to the right person, compare the safety code (6 digits) from the chat menu. Optional.';

  @override
  String get pinWrong => 'Wrong PIN';

  @override
  String get pinMismatch => 'The PINs don\'t match — start again';

  @override
  String get pinEnterCurrent => 'Enter your current PIN';

  @override
  String get pinChoose => 'Choose a PIN (4 to 8 digits)';

  @override
  String get pinRepeat => 'Enter it again to confirm';

  @override
  String get colorIndigo => 'Indigo';

  @override
  String get colorTeal => 'Teal';

  @override
  String get colorEmerald => 'Green';

  @override
  String get colorCoral => 'Coral';

  @override
  String get colorAmber => 'Amber';

  @override
  String get colorSky => 'Sky';

  @override
  String get colorPink => 'Pink';

  @override
  String get colorGraphite => 'Graphite';

  @override
  String get errRejectedTitle => 'The other side declined the connection';

  @override
  String get errRejectedHint =>
      'Ask them to accept the request when it shows up, then try again.';

  @override
  String get errPeerGoneTitle => 'The other phone isn\'t visible right now';

  @override
  String get errPeerGoneHint =>
      'Make sure the chat screen is still open on it and it\'s close to you (about 10 m or less).';

  @override
  String get errReconnectTitle => 'Couldn\'t reconnect';

  @override
  String get errReconnectHint =>
      'The other phone probably moved away or turned off its screen. Open the chat on both phones and start again.';

  @override
  String get errNoNetworkTitle => 'Not connected to any network';

  @override
  String get errNoNetworkHint =>
      'Turn on Wi-Fi and join a network, or start a hotspot from settings and let the other phone join it.';

  @override
  String get errHandshakeTitle => 'Couldn\'t secure the connection';

  @override
  String get errHandshakeHint =>
      'Something went wrong while exchanging encryption keys. Make sure both phones have the latest Wasl and try again.';

  @override
  String get errNoPlayTitle => 'Nearby chat needs Google Play services';

  @override
  String get errNoPlayHint =>
      'This phone has no Google services or they need an update. Update \"Google Play services\" from the store, or chat over Wi-Fi instead.';

  @override
  String get errPermissionTitle => 'Missing permission';

  @override
  String get errPermissionHint =>
      'The app needs the \"Nearby devices\" permission to find the other phone. Allow it and try again.';

  @override
  String get errRadioTitle => 'Bluetooth or Wi-Fi isn\'t responding';

  @override
  String get errRadioHint =>
      'Turn Bluetooth off and on again (and Wi-Fi too if you can), then try. If it keeps happening, restart the phone.';

  @override
  String get errAlreadyConnectedTitle => 'An old connection is still open';

  @override
  String get errAlreadyConnectedHint =>
      'Close the chat screen on both phones and open it again.';

  @override
  String get errTimeoutTitle => 'The connection took too long';

  @override
  String get errTimeoutHint => 'Bring the two phones closer and try again.';

  @override
  String get errGenericTitle => 'Something went wrong with the connection';

  @override
  String get errGenericHint =>
      'Try closing and reopening the chat on both phones. If it keeps happening, turn Bluetooth off and on.';

  @override
  String get errRefusedTitle =>
      'The other phone isn\'t waiting for a connection';

  @override
  String get errRefusedHint =>
      'Make sure it tapped \"Host\" and the address is right.';

  @override
  String get errNoReplyTitle => 'No reply from that address';

  @override
  String get errNoReplyHint =>
      'Both phones must be on the same Wi-Fi (or one runs a hotspot and the other joins it). Some public routers block devices from talking to each other.';

  @override
  String get errUnreachableTitle => 'Not connected to a network';

  @override
  String get errUnreachableHint =>
      'Turn on Wi-Fi and join the same network as the other phone.';

  @override
  String get errFailedTitle => 'Couldn\'t connect';

  @override
  String get errFailedHint =>
      'Check the address and that both phones are on the same network.';

  @override
  String get errLanStartTitle => 'Couldn\'t start on the network';

  @override
  String get errLanStartHint =>
      'Close the app and open it again. If it keeps happening, restart Wi-Fi.';

  @override
  String get copiedSecure =>
      'Copied — it will be cleared from the clipboard in 30 seconds';

  @override
  String get notDelivered => 'Not delivered';

  @override
  String get lockBioTitle => 'Unlock Wasl';

  @override
  String get lockBioSubtitle => 'Your fingerprint instead of the PIN';

  @override
  String get lockIncomingCall => 'Incoming call — unlock';

  @override
  String get lockEnterPin => 'Enter your PIN';

  @override
  String get lockWrongPin => 'Wrong PIN — try again';

  @override
  String get unknownName => 'Unknown';

  @override
  String get otherSide => 'The other side';

  @override
  String get hello => 'Hi';

  @override
  String get transportHeadline => 'How will you\ntalk today?';

  @override
  String get transportSub =>
      'No internet either way, and everything is encrypted.';

  @override
  String get bluetooth => 'Bluetooth';

  @override
  String get bluetoothDesc =>
      'For people near you, with no network at all. Messages hop from phone to phone, so they reach further.';

  @override
  String get tagNoNetwork => 'No network';

  @override
  String get wifi => 'Wi-Fi';

  @override
  String get wifiDesc =>
      'The same Wi-Fi or a phone hotspot. Much faster, with video and voice / video calls.';

  @override
  String get tagFaster => 'Faster';

  @override
  String get tagCalls => 'Calls';

  @override
  String get tagVideo => 'Video';

  @override
  String get both => 'Both at once';

  @override
  String get bothDesc =>
      'Your phone becomes a bridge: it links people on Wi-Fi or a hotspot with people on Bluetooth, so several networks become one.';

  @override
  String get tagBridge => 'Bridge';

  @override
  String get tagRange => 'Wider range';

  @override
  String get tagBattery => 'More battery';

  @override
  String get photoUnusable => 'Couldn\'t use this picture — try another one';

  @override
  String get galleryFailed => 'Couldn\'t open the gallery';

  @override
  String get nameTooShort => 'Enter a name of at least 2 letters';

  @override
  String get profileSaveFailed => 'Couldn\'t save the profile';

  @override
  String get profile => 'Profile';

  @override
  String get appTitle => 'Wasl';

  @override
  String get createProfile => 'Create your profile';

  @override
  String get createProfileSub =>
      'A name and picture people around you will see. No phone number, no email, no internet — everything stays on your phone.';

  @override
  String get removePhoto => 'Remove picture';

  @override
  String get yourName => 'Your name';

  @override
  String get profileColor => 'Profile color';

  @override
  String get orCartoon => 'Or pick a cartoon avatar';

  @override
  String get letsStart => 'Let\'s start';

  @override
  String get save => 'Save';

  @override
  String get reqNearbyTitle => 'Nearby devices permission';

  @override
  String get reqNearbyWhy =>
      'So Wasl can find phones nearby and connect to them over Bluetooth. It doesn\'t use your location.';

  @override
  String get reqWifiTitle => 'Nearby Wi-Fi devices permission';

  @override
  String get reqWifiWhy =>
      'Lets messages move faster over Wi-Fi Direct when the two phones are close.';

  @override
  String get reqLocationTitle => 'Location permission';

  @override
  String reqLocationWhy(Object version) {
    return 'Android $version requires the location permission for any nearby device search. Wasl doesn\'t read or store your location.';
  }

  @override
  String get android11OrOlder => '11 and older';

  @override
  String get reqBluetoothTitle => 'Turn on Bluetooth';

  @override
  String get reqBluetoothWhy =>
      'The two phones find each other over Bluetooth.';

  @override
  String get reqGpsTitle => 'Turn on location (GPS)';

  @override
  String get reqGpsWhy =>
      'On this Android version, searching for devices only works with location turned on.';

  @override
  String get openSettings => 'Open settings';

  @override
  String get allow => 'Allow';

  @override
  String get turnOn => 'Turn on';

  @override
  String get callIncomingVideo => 'Incoming video call';

  @override
  String get callIncomingVoice => 'Incoming voice call';

  @override
  String get callRinging => 'Ringing...';

  @override
  String get callConnecting => 'Connecting...';

  @override
  String get callEnded => 'Call ended';

  @override
  String get cameraOff => 'Camera is off';

  @override
  String get me => 'Me';

  @override
  String get e2eEncrypted => 'End-to-end encrypted';

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get flipCamera => 'Flip camera';

  @override
  String get camera => 'Camera';

  @override
  String get mute => 'Mute';

  @override
  String get muted => 'Muted';

  @override
  String get speaker => 'Speaker';

  @override
  String get earpiece => 'Earpiece';

  @override
  String get callBusy => 'A call is already in progress';

  @override
  String get notConnectedNow => 'Not connected right now';

  @override
  String get callNoAnswer => 'No answer';

  @override
  String get callConnectFailed => 'Couldn\'t connect the call';

  @override
  String get callStartFailed => 'Couldn\'t start the call';

  @override
  String get callMediaFailed => 'Couldn\'t start the microphone / camera';

  @override
  String get callRejected => 'Declined';

  @override
  String get callMissed => 'Missed call';

  @override
  String get callPeerRejected => 'The other side declined the call';

  @override
  String get callPeerBusy => 'The other side is on another call';

  @override
  String get callPeerHungUp => 'The other side hung up';

  @override
  String get callProblem => 'Something went wrong with the call';

  @override
  String get callIceFailed =>
      'Connection failed — make sure you are on the same network';

  @override
  String get micDeniedForever =>
      'Microphone permission denied — enable it in the app settings';

  @override
  String get micNeededCall => 'We need the microphone permission for the call';

  @override
  String get camDeniedForever =>
      'Camera permission denied — enable it in the app settings';

  @override
  String get camNeededCall =>
      'We need the camera permission for the video call';

  @override
  String get callDropped => 'The connection dropped';

  @override
  String get chatEnded => 'The chat ended';

  @override
  String get micNeededRecord => 'We need the microphone permission to record';

  @override
  String get micStartFailed => 'Couldn\'t start the microphone';

  @override
  String get holdToRecord => 'Press and hold the microphone to record';

  @override
  String get recordFailed => 'The recording didn\'t finish — try again';

  @override
  String get emojiNoRecents => 'Emoji you use will show up here';

  @override
  String get emojiSearch => 'Search emoji';

  @override
  String get keyboard => 'Keyboard';

  @override
  String get emoji => 'Emoji';

  @override
  String get messageHint => 'Message';

  @override
  String get waitingConnection => 'Waiting for connection...';

  @override
  String get attachments => 'Attachments';

  @override
  String get photoHoldVideo => 'Photo (hold for video)';

  @override
  String get photo => 'Photo';

  @override
  String get delete => 'Delete';

  @override
  String get slideToCancel => 'Slide to cancel';

  @override
  String get theOtherSide => 'The other side';

  @override
  String get forwarded => 'Forwarded';

  @override
  String get edited => 'Edited';

  @override
  String get you => 'You';

  @override
  String compareSafety(Object name) {
    return 'Compare the safety code with $name';
  }

  @override
  String get compareSafetyHint =>
      'An extra check (optional): if the same number shows on the other phone, you can be 100% sure nobody is in the middle.';

  @override
  String get different => 'Different';

  @override
  String get matches => 'Match';

  @override
  String get attachDocument => 'Document';

  @override
  String get attachCamera => 'Camera';

  @override
  String get attachGallery => 'Gallery';

  @override
  String get attachAudio => 'Audio';

  @override
  String get videoWifiOnlyHint =>
      'Video is available in Wi-Fi / hotspot chats (Bluetooth is too slow for it).';

  @override
  String get video => 'Video';

  @override
  String get videoWifiOnly => 'Video is only available in Wi-Fi chats';

  @override
  String get cameraPermission =>
      'We need the camera permission — enable it in the app settings';

  @override
  String get cameraFailed => 'Couldn\'t open the camera';

  @override
  String get videoWifiOnlyPhotosSent =>
      'Video is only available in Wi-Fi chats — only the photos were sent';

  @override
  String get videoCompressFailed =>
      'Couldn\'t compress the video — sending it as is';

  @override
  String get preparingVideo => 'Preparing the video';

  @override
  String get preparingVideoBody =>
      'Making it smaller so it plays on any phone and sends faster.';

  @override
  String get filesFailed => 'Couldn\'t open your files';

  @override
  String fileTooBig(Object size) {
    return 'The file is bigger than $size';
  }

  @override
  String get readFileFailed => 'Couldn\'t read the file';

  @override
  String get sendFailedRetry => 'Not delivered — send it again';

  @override
  String get fileIncomplete => 'The file arrived incomplete';

  @override
  String get file => 'File';

  @override
  String waitingReconnectPct(Object pct) {
    return 'Waiting for the connection... $pct%';
  }

  @override
  String pctOfSize(Object pct, Object size) {
    return '$pct% of $size';
  }

  @override
  String waitingConnectionPct(Object pct) {
    return 'Waiting for connection... $pct%';
  }

  @override
  String get cancelSending => 'Cancel sending';

  @override
  String get cancelReceiving => 'Cancel receiving';

  @override
  String get saveToDownloads => 'Save to Downloads';

  @override
  String get noAppToOpen =>
      'No app on this phone opens this type — save or share it';

  @override
  String get storagePermission =>
      'We need the storage permission to save the file';

  @override
  String get savedToDownloads => 'Saved to Downloads → Wasl';

  @override
  String get saveFileFailed => 'Couldn\'t save the file';

  @override
  String get tapToOpen => 'Tap to open';

  @override
  String get photosPermission => 'We need access to your photos';

  @override
  String get savedToGallery => 'Saved to the gallery';

  @override
  String get openWithOtherApp => 'Open with another app';

  @override
  String get saveToGallery => 'Save to gallery';

  @override
  String get share => 'Share';

  @override
  String get videoCantPlay =>
      'The video arrived fine, but the built-in player can\'t play this format.';

  @override
  String get saveItToGallery => 'Save it to the gallery';

  @override
  String get groupNobodyReachable => 'No group member is reachable right now';

  @override
  String get videoWifiOnlyShort => 'Video is only available on Wi-Fi';

  @override
  String get fileEmpty => 'The file is empty';

  @override
  String get notAValidVideo =>
      'This file isn\'t a valid video — pick it again from the gallery';

  @override
  String groupMaxSize(Object size) {
    return 'The size limit in groups is $size';
  }

  @override
  String get sendFileFailed => 'Couldn\'t send the file';

  @override
  String get connectionStoppedEarly =>
      'The connection stopped before it finished';

  @override
  String memberJoined(Object name) {
    return '$name joined the group';
  }

  @override
  String memberLeft(Object name) {
    return '$name left the group';
  }

  @override
  String get arrivedIncomplete => 'Arrived incomplete';

  @override
  String get arrivedCorrupt => 'Doesn\'t match the original';

  @override
  String get sendingStoppedEarly => 'Sending stopped before it finished';

  @override
  String joinAccepted(Object group) {
    return 'You were accepted into \"$group\" 🎉';
  }

  @override
  String joinRejected(Object group) {
    return 'Your request to join \"$group\" was declined';
  }

  @override
  String get leaveTitle => 'Disconnect?';

  @override
  String get leaveBodyUnsaved =>
      'People won\'t see you anymore, and unsaved chats will be erased.';

  @override
  String get leaveBody => 'People won\'t see you until you come back.';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get newChat => 'New chat';

  @override
  String get newGroup => 'New group';

  @override
  String get tabChats => 'Chats';

  @override
  String get tabGroups => 'Groups';

  @override
  String get tabNearby => 'Nearby';

  @override
  String get back => 'Back';

  @override
  String get preparing => 'Getting ready...';

  @override
  String get searchingPeople => 'Looking for people around you';

  @override
  String peopleNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people nearby',
      one: '1 person nearby',
    );
    return '$_temp0';
  }

  @override
  String get tryAgain => 'Try again';

  @override
  String get openWifi => 'Open Wi-Fi';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get unpin => 'Unpin';

  @override
  String get pin => 'Pin to top';

  @override
  String get unmuteNotifications => 'Unmute notifications';

  @override
  String get muteNotifications => 'Mute notifications';

  @override
  String get unsaveChat => 'Stop saving this chat';

  @override
  String get saveChat => 'Save this chat on the phone';

  @override
  String get leaveGroup => 'Leave group';

  @override
  String get deleteChat => 'Delete chat';

  @override
  String get chatSavedToast => 'This chat is now saved on the phone';

  @override
  String get chatUnsavedToast => 'This chat isn\'t saved anymore';

  @override
  String leaveGroupTitle(Object name) {
    return 'Leave \"$name\"?';
  }

  @override
  String deleteChatTitle(Object name) {
    return 'Delete the chat with $name?';
  }

  @override
  String get messagesErasedBody =>
      'The messages will be erased from your phone.';

  @override
  String get leave => 'Leave';

  @override
  String get deleteAction => 'Delete';

  @override
  String get typing => 'typing...';

  @override
  String nameTyping(Object name) {
    return '$name is typing...';
  }

  @override
  String groupOfMode(Object mode) {
    return '$mode group';
  }

  @override
  String get tapToStart => 'Tap to start talking';

  @override
  String youPrefix(Object text) {
    return 'You: $text';
  }

  @override
  String get noChatsTitle => 'No chats yet';

  @override
  String get noChatsBody =>
      'Pick someone or a group from Nearby and start talking. Encryption happens automatically, no password needed.';

  @override
  String get startNewChat => 'Start a new chat';

  @override
  String get noGroupsTitle => 'No groups around you';

  @override
  String get noGroupsBody =>
      'Create an open group for anyone nearby, or a private one with a password or your approval. A group is visible as long as a member is nearby.';

  @override
  String get createGroup => 'Create a group';

  @override
  String get myGroups => 'My groups';

  @override
  String get groupsAround => 'Groups around you';

  @override
  String groupsAroundCount(Object count) {
    return 'Groups around you ($count)';
  }

  @override
  String membersNearby(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members nearby',
      one: '1 member nearby',
    );
    return '$_temp0';
  }

  @override
  String get waiting => 'Waiting';

  @override
  String get requestJoin => 'Request';

  @override
  String get join => 'Join';

  @override
  String get ipFormat => 'Enter the address like this: 192.168.1.5';

  @override
  String get ipConnected => 'Connected — they\'ll show up in the list now';

  @override
  String get searchWifiHint =>
      'Anyone with Wasl open on the same Wi-Fi (or connected to your hotspot) will show up here by itself.';

  @override
  String get searchBtHint =>
      'Anyone nearby with Wasl open on Bluetooth will show up here by itself. Searching takes from a few seconds to a minute.';

  @override
  String peopleTapToTalk(Object count) {
    return 'People — tap anyone to talk ($count)';
  }

  @override
  String get meshHint =>
      'Phones relay for each other: you can talk to someone far away through phones in between, and none of them can read your messages.';

  @override
  String get connectByAddress => 'Connect by address';

  @override
  String connectByAddressHint(Object addresses) {
    return 'If the network blocks automatic discovery (like some café networks). Your address: $addresses';
  }

  @override
  String get listSeparator => ', ';

  @override
  String get otherDeviceAddress => 'The other phone\'s address';

  @override
  String get connect => 'Connect';

  @override
  String get someoneMissing => 'Someone missing? Connect by address';

  @override
  String get connectedDirectly => 'Connected to you directly';

  @override
  String viaRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Through $count phones in between',
      one: 'Through 1 phone in between',
    );
    return '$_temp0';
  }

  @override
  String get oneStepTitle => 'One step before we start';

  @override
  String get oneStepBody =>
      'Bluetooth works without internet, and for phones to find each other we need these:';

  @override
  String get permissionBlockedHint =>
      'This permission was denied before — enable it in Settings → Permissions.';

  @override
  String get modeOpen => 'Open';

  @override
  String get modePassword => 'Password';

  @override
  String get modeAsk => 'Join request';

  @override
  String get groupNameNeeded => 'Enter a name for the group';

  @override
  String get passwordTooShort => 'The password must be at least 4 characters';

  @override
  String get createGroupFailed => 'Couldn\'t create the group';

  @override
  String get modeOpenExplain =>
      'Anyone nearby sees the group and joins right away.';

  @override
  String get modePasswordExplain =>
      'The group is visible, but only people with the password can join or read.';

  @override
  String get modeAskExplain =>
      'Anyone who wants in sends you a request, and you accept or decline.';

  @override
  String get groupName => 'Group name';

  @override
  String get groupPassword => 'Group password';

  @override
  String get createGroupButton => 'Create group';

  @override
  String get joinGroupFailed => 'Couldn\'t join the group';

  @override
  String get requestPendingTitle => 'Request still pending';

  @override
  String get requestPendingBody =>
      'The group owner hasn\'t answered your request yet.';

  @override
  String get cancelRequest => 'Cancel request';

  @override
  String get keepWaiting => 'I\'ll wait';

  @override
  String requestJoinTitle(Object name) {
    return 'Request to join \"$name\"';
  }

  @override
  String get requestJoinBody =>
      'We\'ll send a request to the group owner, and you\'ll join as soon as they accept.';

  @override
  String get sendRequest => 'Send request';

  @override
  String get requestSent => 'Request sent — waiting for approval';

  @override
  String get privateGroupPassword =>
      'This group is private — enter the password to join.';

  @override
  String get password => 'Password';

  @override
  String get enter => 'Join';

  @override
  String get roleOwner => 'Group owner';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get member => 'Member';

  @override
  String get onlineNow => 'Online now';

  @override
  String get privateMessage => 'Private message';

  @override
  String get privateMessageSub => 'Encrypted between the two of you only';

  @override
  String get voiceCall => 'Voice call';

  @override
  String get mention => 'Mention';

  @override
  String get removeAdmin => 'Remove as admin';

  @override
  String get makeAdmin => 'Make admin';

  @override
  String get removeFromGroup => 'Remove from group';

  @override
  String get unban => 'Let back into the group';

  @override
  String get block => 'Block';

  @override
  String get blockSub => 'You won\'t see their messages anywhere';

  @override
  String kickTitle(Object name) {
    return 'Remove $name from the group?';
  }

  @override
  String get kickAsk =>
      'The group key will change, so they can\'t read new messages or rejoin without approval.';

  @override
  String get kickPassword =>
      'Nobody will see their messages and they can\'t send. But they still know the password — to stop them reading at all, make a new group with a different password.';

  @override
  String get kickOpen =>
      'Nobody will see their messages and they can\'t send. Anyone nearby can read an open group.';

  @override
  String get kickConfirm => 'Remove';

  @override
  String kicked(Object name) {
    return '$name was removed from the group';
  }

  @override
  String unbanned(Object name) {
    return '$name can join the group again';
  }

  @override
  String blockTitle(Object name) {
    return 'Block $name?';
  }

  @override
  String get blockBody =>
      'They can\'t send you messages and you won\'t see their messages in groups. You can unblock them from Settings.';

  @override
  String get groupInfo => 'Group info';

  @override
  String get notInGroup => 'You\'re no longer in this group';

  @override
  String get rename => 'Rename';

  @override
  String get youOwnIt => 'you own it';

  @override
  String ownedBy(Object name) {
    return 'owner: $name';
  }

  @override
  String joinRequests(Object count) {
    return 'Join requests ($count)';
  }

  @override
  String get removedBefore => 'Was removed from the group before';

  @override
  String onlineCount(Object count) {
    return 'Online now ($count)';
  }

  @override
  String get youName => 'You';

  @override
  String get ownerHint =>
      'Tap any member: private message, make them admin, or remove them. You own the group and nobody can remove you.';

  @override
  String get adminHint =>
      'You\'re an admin: you can remove members, delete their messages and rename the group.';

  @override
  String get memberHint =>
      'Tap any member to chat privately — encrypted between the two of you, not even the rest of the group sees it.';

  @override
  String bannedCount(Object count) {
    return 'Removed from the group ($count)';
  }

  @override
  String get letBack => 'Let back';

  @override
  String get groupMessagesErased =>
      'The group\'s messages will be erased from your phone.';

  @override
  String get callStartNow => 'Couldn\'t start the call right now';

  @override
  String get messageGone => 'This message doesn\'t exist anymore';

  @override
  String get noForwardTarget => 'No connected chat to forward to right now';

  @override
  String get forwardTo => 'Forward to';

  @override
  String get group => 'Group';

  @override
  String get privateChat => 'Private chat';

  @override
  String forwardedTo(Object name) {
    return 'Forwarded to $name';
  }

  @override
  String get statusSending => 'Sending...';

  @override
  String get statusSentGroup => 'Sent';

  @override
  String get statusSent => 'Sent, not delivered yet';

  @override
  String get statusDeliveredGroup => 'Someone read it';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusReadGroup => 'Everyone online read it';

  @override
  String get statusRead => 'Read';

  @override
  String get statusFailed => 'Not sent';

  @override
  String get messageInfo => 'Message info';

  @override
  String readByCount(Object count) {
    return 'Read by ($count)';
  }

  @override
  String get nobodyYet => 'Nobody yet';

  @override
  String onlineNotReadCount(Object count) {
    return 'Online, haven\'t read it ($count)';
  }

  @override
  String get codeMismatchTitle => 'The code doesn\'t match?';

  @override
  String get codeMismatchBody =>
      'That could mean someone is pretending to be the other person. Don\'t send anything sensitive, and block them from the menu if you\'re not sure.';

  @override
  String get unsaveChatTitle => 'Stop saving this chat?';

  @override
  String get unsaveChatBody =>
      'The messages will be erased from the phone\'s storage and will only stay until you close the app.';

  @override
  String get unsaveConfirm => 'Stop saving';

  @override
  String get chatSavedEncryptedToast =>
      'This chat is now saved on the phone (encrypted)';

  @override
  String get clearTitle => 'Clear messages?';

  @override
  String get clearBody => 'Messages will be cleared on your side only.';

  @override
  String get clear => 'Clear';

  @override
  String get blockDirectBody =>
      'They can\'t send you messages and won\'t show up in Nearby. You can unblock them from Settings.';

  @override
  String get deleteChatQ => 'Delete the chat?';

  @override
  String get deleteChatBody =>
      'The chat and its messages will be erased from your phone.';

  @override
  String get otherEmoji => 'Another emoji';

  @override
  String get reply => 'Reply';

  @override
  String get forward => 'Forward';

  @override
  String get copy => 'Copy';

  @override
  String privateMessageTo(Object name) {
    return 'Private message to $name';
  }

  @override
  String mentionName(Object name) {
    return 'Mention $name';
  }

  @override
  String get edit => 'Edit';

  @override
  String get deleteForBoth => 'Delete for both of us';

  @override
  String get deleteForAll => 'Delete for everyone';

  @override
  String get deleteForAllAdmin => 'Delete for everyone (you\'re an admin)';

  @override
  String get deleteForMe => 'Delete for me';

  @override
  String get editMessage => 'Edit message';

  @override
  String typingOne(Object name) {
    return '$name is typing';
  }

  @override
  String typingTwo(Object a, Object b) {
    return '$a and $b are typing';
  }

  @override
  String typingMany(Object count) {
    return '$count are typing';
  }

  @override
  String get chatClosed => 'The chat is closed';

  @override
  String get noMembersNearby => 'No members nearby right now';

  @override
  String membersOnline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members online now',
      one: '1 member online now',
    );
    return '$_temp0';
  }

  @override
  String get blocked => 'Blocked';

  @override
  String get encryptedVerified => 'Encrypted • code verified';

  @override
  String get securing => 'Securing the connection...';

  @override
  String get connecting => 'Connecting...';

  @override
  String get videoCall => 'Video call';

  @override
  String get joinRequestsTooltip => 'Join requests';

  @override
  String get searchChat => 'Search chat';

  @override
  String get membersAndInfo => 'Members and group info';

  @override
  String get safetyCodeOptional => 'Safety code (optional)';

  @override
  String get clearMessages => 'Clear messages';

  @override
  String peerOfflineWifi(Object name) {
    return '$name isn\'t on the network right now. You can talk as soon as they open the app on the same Wi-Fi.';
  }

  @override
  String peerOfflineBt(Object name) {
    return '$name isn\'t nearby right now. You can talk as soon as they come close and open the app.';
  }

  @override
  String get noDeviceNearby =>
      'No phone nearby right now — messages go out once someone is reachable.';

  @override
  String get cancelSendingQ => 'Cancel sending?';

  @override
  String get cancelReceivingQ => 'Cancel receiving?';

  @override
  String get cancelSendingBody =>
      'The file will be removed from the chat for you and the other side.';

  @override
  String get cancelReceivingBody =>
      'The file will be removed on your side and won\'t finish.';

  @override
  String get cancelTransfer => 'Cancel transfer';

  @override
  String get notificationsBack => 'Notifications are back on for this chat';

  @override
  String get muteHour => '1 hour';

  @override
  String get mute8Hours => '8 hours';

  @override
  String get muteWeek => '1 week';

  @override
  String get muteAlways => 'Always';

  @override
  String get mutedGroupToast => 'Muted — only mentions will notify you';

  @override
  String get mutedToast => 'Notifications for this chat are muted';

  @override
  String get closeSearch => 'Close search';

  @override
  String get searchInChat => 'Search in chat';

  @override
  String get none => 'None';

  @override
  String get older => 'Older';

  @override
  String get newer => 'Newer';

  @override
  String get startGroupTalk => 'Start talking in the group';

  @override
  String get sayHello => 'Say hi 👋';

  @override
  String get emptyGroupEnc =>
      'Group messages are encrypted with its key and never pass through a server.';

  @override
  String get emptyDirectEnc =>
      'Messages are end-to-end encrypted automatically — no password and no internet.';

  @override
  String get emptySaved => 'This chat is saved on your phone.';

  @override
  String get emptyNotSaved =>
      'This chat isn\'t saved: it will be erased when you close the app.';

  @override
  String get notFinished => 'Didn\'t finish';

  @override
  String get chatEncryptedSystem => 'This chat is end-to-end encrypted 🔒';

  @override
  String get safetyVerifiedSystem => 'Safety code verified ✓';

  @override
  String get previewPhoto => '📷 Photo';

  @override
  String get previewVideo => '🎥 Video';

  @override
  String get previewVoice => '🎤 Voice message';

  @override
  String previewFile(Object name) {
    return '📄 $name';
  }

  @override
  String sizeGb(Object n) {
    return '$n GB';
  }

  @override
  String sizeMb(Object n) {
    return '$n MB';
  }

  @override
  String get readFileFromPhoneFailed =>
      'Couldn\'t read the file from the phone';

  @override
  String get peerGotCorrupt =>
      'It arrived corrupted on the other side — send it again';

  @override
  String get peerCanceledReceive => 'The other side canceled receiving';

  @override
  String get personNearby => 'Someone nearby';

  @override
  String get groupCreatedOpen => 'Group created — anyone nearby can join';

  @override
  String get groupCreatedPassword =>
      'Group created — joining needs the password';

  @override
  String get groupCreatedAsk => 'Group created — joining needs your approval';

  @override
  String get networkNotRunning => 'The network isn\'t running';

  @override
  String get wrongPassword => 'Wrong password';

  @override
  String get groupNeedsApproval => 'This group needs the owner\'s approval';

  @override
  String get ownerOffline =>
      'The group owner isn\'t connected right now — try when they\'re nearby';

  @override
  String get sendRequestFailed => 'Couldn\'t send the request';

  @override
  String get notAllowed => 'You\'re not allowed to do that';

  @override
  String get noConnectionNow => 'No connection right now';

  @override
  String youKicked(Object name) {
    return 'You removed $name from the group';
  }

  @override
  String get ownerOnly => 'Only the group owner can do that';

  @override
  String get maxAdmins => 'You\'ve reached the maximum number of admins';

  @override
  String youMadeAdmin(Object name) {
    return 'You made $name an admin';
  }

  @override
  String youRemovedAdmin(Object name) {
    return 'You removed $name as admin';
  }

  @override
  String get adminsOnlyRename => 'Only admins can rename the group';

  @override
  String youRenamed(Object name) {
    return 'You renamed the group to \"$name\"';
  }

  @override
  String removedFromGroupNotice(Object name) {
    return 'You were removed from the group \"$name\"';
  }

  @override
  String byKicked(Object by, Object who) {
    return '$by removed $who from the group';
  }

  @override
  String get youBecameAdmin => 'You\'re now an admin in the group';

  @override
  String becameAdmin(Object name) {
    return '$name is now an admin';
  }

  @override
  String get youNoLongerAdmin => 'You\'re no longer an admin in the group';

  @override
  String noLongerAdmin(Object name) {
    return '$name is no longer an admin';
  }

  @override
  String byRenamed(Object by, Object name) {
    return '$by renamed the group to \"$name\"';
  }

  @override
  String mentionedYou(Object text) {
    return 'Mentioned you: $text';
  }

  @override
  String reactedOn(Object emoji, Object text) {
    return 'Reacted $emoji to: \"$text\"';
  }
}
