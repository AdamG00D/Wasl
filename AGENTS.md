# Wasl (وَصْل) — guide for AI coding agents

Wasl is an offline chat app for Android (Flutter, Arabic UI, RTL): people nearby talk over **Bluetooth** (Google
Nearby Connections) or **Wi-Fi / hotspot** (UDP discovery + TCP) with no internet and no server. Devices form a
**mesh** (messages hop through other phones), private chats are end-to-end encrypted automatically (no passwords),
and there are groups (open / password / join-request). Package `com.adam.wasl`. It started from the chat part of the
owner's older app ILN (`~/Downloads/ILN_App/iln_flutter`) — chat session, file transfer, voice, calls and the Kotlin
helpers come from there.

## Working with the owner

- The owner writes in **Egyptian Arabic**. Reply in Egyptian Arabic.
- **Explain the plan first and wait for approval** before implementing anything non-trivial.
- **Don't build the APK after each step.** Finish every change, run `flutter analyze` + `flutter test`, then build once
  at the end (or give the build command).
- **Never add AI attribution** (`Co-Authored-By`, "Generated with…") to commits or anything else.
- When a request is ambiguous, ask instead of guessing.

## Commands

```bash
flutter analyze          # must say "No issues found!"
flutter test             # test/mesh_test.dart — mesh routing, private chat over mesh, groups, storage
python3 tool/generate_icon.py   # regenerate launcher icon (needs Pillow)
./scripts/build_release.sh      # signed + obfuscated → Releases/<ver>v/ (uses JDK 21 from ~/Downloads/Files/toolchains)
```

New version: bump `version` in `pubspec.yaml` **and** `appVersion` in `lib/core/config.dart`, and write
`release_notes/<X.Y>v.txt`. The build script refuses to run without the notes.

Folder layout on disk: `Wasl/Wasl_App/` (this repo) and `Wasl/Signing_Key/` (keystore + passwords — outside the repo
on purpose, never commit or print them).

## Layout

```
lib/
  main.dart                 start: lock gate → profile editor (first run) → TransportScreen
  core/
    config.dart             ports, service id, version
    nav.dart                rootNavigatorKey
    crypto/                 kdf.dart (Argon2id/HKDF/SHA-256), box.dart (AES-GCM box, native for big payloads, pairKey)
    profile/profile.dart    Profile (name, color, avatar hash, static X25519 identity; id = sha256(pub)[0..8]),
                            ProfileStore, Avatars (small JPEGs stored by hash)
    settings/app_settings.dart   theme, accent, saveChats (default false), PIN lock
    storage/vault.dart      master key wrapped by Android Keystore; encrypted JSON files
    storage/chat_store.dart saved chats index + messages + joined groups + blocked ids
    platform/               system_bridge.dart (channel wasl/system), secure_clipboard.dart
    theme/app_theme.dart    Palette tokens (context.palette), AccentTheme presets, avatarColors
  mesh/
    mesh_link.dart          MeshLink: neighbour links carrying string frames
    lan_link.dart           Wi-Fi: UDP beacons + one TCP connection per neighbour (smaller id dials)
    nearby_link.dart        Bluetooth: Nearby P2P_CLUSTER, auto-accept, ≤ 5 links
    mesh_router.dart        presence, flooding with dedupe + neighbour suppression, learned unicast routes;
                            GroupMode / GroupAd / MeshNode
    peer_link.dart          binds a ChatSession to a peer over the mesh (session ids, simultaneous-dial tie-break)
  features/
    hub/chat_hub.dart       ChatHub singleton: link + router + DirectChat/GroupChat objects, persistence,
                            notifications, calls, join requests, avatars
    chat/
      chat_page.dart        the conversation screen (direct + group)
      core/                 secure_channel.dart, chat_session.dart (messages + file transfer), frame_transport.dart,
                            chat_link.dart (session + supportsVideo for the input widgets), chat_errors, nearby_requirements
      call/, voice/, widgets/   WebRTC calls, voice notes, bubbles / input bar / media (from ILN)
    groups/                 group.dart (GroupInfo + keys), group_session.dart (GroupSession extends ChatSession),
                            group_ui.dart (create sheet, join flow, info screen)
    home/                   transport_screen.dart (Bluetooth / Wi-Fi), home_screen.dart (chats • groups • nearby)
    onboarding/profile_editor.dart, settings/settings_screen.dart, lock/app_lock.dart
  widgets/                  ui.dart (Avatar, AppCard, buttons, EmptyState…), feedback.dart (showToast, dialogs), focus_guard.dart
android/app/src/main/kotlin/com/adam/wasl/
  MainActivity.kt    channels: wasl/system (bluetooth/wifi/notify/service/files) + wasl/vault (keystore wrap, biometric)
  KeyVault.kt        Keystore AES key + BiometricGate
  ChatService.kt     foreground service + Notifications (no names/content); onTaskRemoved kills the process
  ChatFiles.kt, NativeCrypto.kt (wasl/crypto), VoiceRecorder.kt (wasl/voice), VideoCompressor.kt (wasl/video), ImageCompressor.kt
```

## Conventions

- **UI text and code comments are in Egyptian Arabic** (short, friendly). Layout is RTL — prefer
  `EdgeInsetsDirectional` / `AlignmentDirectional` / `PositionedDirectional`.
- Colors only through `context.palette`; no hard-coded theme colors in screens. Font: IBM Plex Sans Arabic (`Plex`),
  weights 400–700 only.
- Messages to the user: `showToast(context, ...)` (never `SnackBar`). Dialogs: `confirmDialog` / `infoDialog`.
- Closing the keyboard: **always `hideKeyboard()`**, never `FocusScope.of(context).unfocus()`.
- Never log message contents. Notifications never include names or text.

## Protocol invariants (covered by tests — keep them green)

- **Mesh frame**: `kind|src|dst|pid|ttl|body`. Kinds: `P` presence, `X` leaving, `G` group broadcast (dst = group id),
  `D` private-chat data, `U` control JSON, `H|id` neighbour hello (never routed). Max 6 hops. Dedupe by `src+pid`.
  A relay doesn't forward a broadcast to neighbours that are also neighbours of whoever handed it the packet.
  Unicast follows the neighbour the destination's last packet came through, else floods.
- **Identity**: node id = first 8 bytes of SHA-256(static X25519 public key), hex. Presence with a key that doesn't
  hash to the id is dropped.
- **Private chat** (`secure_channel.dart`, protocol v1): hello carries an ephemeral key + the static identity key;
  keys = HKDF(ee ‖ ss). Both sides confirm with HMAC. AES-256-GCM with sequence numbers, heartbeat 5 s / lost after
  15 s. **Changing the wire format requires bumping `protocolVersion`.**
- **PeerLink**: every frame is `sid|frame`; a hello with a new sid replaces the session; simultaneous dials → the
  smaller node id's sid wins. If the first frame can't leave the device the session reports `'lost'` at once.
- **File transfer** (direct): `file-start` → `file-chunk`s → `file-end` (SHA-256), receiver acks every `ackEvery`,
  sender keeps ≤ `window` chunks in flight, resumes after reconnect. Groups: `fs`/`fc`/`fe` broadcast in order, no acks,
  size-limited (`MeshLink.groupFileLimit`).
- **Groups**: body = base64(AES-GCM(groupKey, json), aad `wasl/group/v1|<id>`). open key = SHA-256 of the id (public by
  design); password key = Argon2id(password, salt from id); ask key = random, handed over sealed with
  `Box.pairKey(owner, member)`. `check` = HKDF of the key, used to validate passwords/grants.
- **Saving**: default off. A conversation is written to disk only if `saveOverride ?? AppSettings.saveChats`; media of
  saved chats moves to `vault/media/<id>/`. Unsaved chats live in memory until the hub stops.

## Don't touch / never commit

- `../Signing_Key/` (keystore + passwords).
- Generated: `res/drawable-*/ic_launcher_*`, `res/mipmap-*/ic_launcher.png` (from `tool/generate_icon.py`).
