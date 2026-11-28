# Wasl — progress log

Read this first when you pick the project up. It says what is done, what is in progress and what comes next, plus
the decisions already taken with the owner (don't re-open them). Keep it current: update it at the end of every step
and commit it together with the step. `AGENTS.md` has the codebase guide; this file has the plan and the state.

Owner preferences that matter for every step: reply in Egyptian Arabic, explain the plan and wait for "تمام",
one commit per step (plain message, no AI attribution), **never build the APK without the owner's explicit OK**
(ask first, even at the very end), and **check the design visually**
(see "Screenshots" below) — the owner cares a lot that nothing looks broken.


## The app is now **Ganbak (جنبك)** — renamed from Wasl (2026-11-27, owner's decision)

- Name chosen with the owner after checking GitHub, the web and the stores (Shabakni / Hawalik / Washwasha / … were
  taken or had bad associations). Store title: «جنبك: شات بدون إنترنت» / «Ganbak: Offline Chat» («بلا نت» was
  dropped on 2026-11-28 — people didn't understand it).
- Website search (2026-11-28): Google found "ganbak offline chat" but not Arabic searches like «جنبك شات اوفلاين» /
  «بدون انترنت», because those words weren't on the page. `tool/site.py` now has a `KEYWORDS` list (Arabic with and
  without hamza, Egyptian and standard, English) that goes into `meta keywords` + JSON-LD, plus a visible
  "بتدوّر على شات من غير نت؟" paragraph and two FAQ entries with the same phrasing. Add new phrasings there.
- Package `com.adam.ganbak`, Dart package `ganbak`, Kotlin sources in `android/app/src/main/kotlin/com/adam/ganbak/`,
  repo `AdamG00D/Ganbak`, site `https://adamg00d.github.io/Ganbak/`, APKs `Ganbak-<ver>-*.apk` + `Ganbak-android*.apk`.
- **Kept on purpose** (so Ganbak still talks to Wasl 1.6): every protocol label (`wasl/...` HKDF / AAD strings), the
  Nearby service id `com.adam.wasl.mesh`, the LAN beacon fields, method-channel names. Code comments still say وصل.
- Local folders on disk are still `Wasl/Wasl_App` and `Wasl/Signing_Key` (not renamed, nothing depends on them).
- Older entries below talk about "Wasl" — that's history.

## Current release: 1.6 — published 2026-11-27 (privacy, secret groups, invites, fair spy dealing)

### Previous: 1.5 — published 2026-11-27 (everything since 1.2: games, identity, guide, Wasl network, offline messages, SOS, Share Wasl, signed identity)

### Earlier: 1.3 — games, visual identity, guide and Wasl network (built, never published on its own)

| # | Step | State |
|---|------|-------|
| 1 | Screenshot tool (`tool/shots/`) + this file | done |
| 2 | Visual identity "Khayamiya" (palette, stitch line, pattern, bunting, launcher icon) — see docs/DESIGN.md | done |
| 3 | Game framework: invites, wire protocol, room host, picker sheet, game screen shell, help pages | done |
| 4 | Two-player games: tic-tac-toe, connect four, battleship, rock-paper-scissors, dots & boxes, memory | done (dice/coin dropped for now) |
| 5 | Group games: memory & dots (group), spy (مين الجاسوس), quiz, mafia | done |
| 6 | "Wasl guide" (دليل وصل) in settings + "؟" on the transport screen | done (`lib/features/guide/`) |
| 7 | Docs (GAMES.md, DESIGN.md, PROTOCOL.md, SECURITY, READMEs, AGENTS.md), version 1.3, release notes | done |
| 8 | Full check: analyze, tests, screenshots of every screen reviewed, release build | checks done; **build waits for the owner's OK**; owner tests on real phones |

### Still open for 1.3

- **Build:** done 2026-11-27 with the owner's OK → `Releases/1.3v/` (4 APKs, same signing certificate as 1.2, so
  updates install over it). Not published to GitHub yet. The build warns that some plugins still use the old Kotlin
  Gradle plugin ("Built-in Kotlin") — harmless today, needs a dependency update before a future Flutter upgrade.
  `.claude/settings.local.json` (not committed) allows Claude to run `./scripts/build_release.sh`.
- **Real-phone test by the owner — postponed by the owner (2026-11-27), do it before releasing** (I can't run
  Bluetooth / Wi-Fi here): a direct game over Bluetooth and over Wi-Fi,
  a group game with 3+ phones (spy or mafia), leaving mid-game, the app in background during a game, and Arabic on one
  phone / English on the other.
- README images: **done** — `flutter test tool/shots/readme_test.dart && python3 tool/shots/readme.py` renders the
  README screenshots (Arabic in `docs/images/screenshots/`, English in `screenshots/en/`) and both banners from the
  real screens, on an in-memory network of real peers (`tool/shots/sample_world.dart`, via `ChatHub.start(testLink:)`).
  The GitHub social preview (`../wasl_social_preview*.png`, outside the repo, uploaded by hand) is still the old look.
- Dice / coin in chat was dropped from this release (not asked for again).

## "Wasl network" — part of 1.3 (owner: one release, 2026-11-27)

The app opens an Android Local-Only Hotspot (no internet) and puts `w {s, p, x}` in its presence; direct Bluetooth
neighbours on "Both" get an offer banner and join with one tap (`WifiNetworkSpecifier`, Android 10+, then
`bindProcessToNetwork`); Android 8–9 get the name/password to enter in Wi-Fi settings. Hosting needs Android 8+,
"Nearby devices" (13+) or location + location on (≤ 12). `LanLink` re-reads its addresses every 3 s and reopens the
beacon socket, so it follows the new network. UI: card in the Nearby tab (wifi / both), offer banner on the home
screen (join button only on "Both"; on Bluetooth it says to pick "Both"), "Start a Wasl network" on the no-network
card, a section with a drawing in the guide.

- Code: `android/.../WaslNet.kt` (channel `wasl/net`), `lib/features/net/`, presence parsing in `mesh_router.dart`
  (`WifiOffer`), hub wiring (`_describe`, `stop()` → `WaslNetwork.shutdown()`), tests in `test/net_test.dart`.
- **Not verified on devices and the Kotlin is not compiled yet** (the owner said not to build). First build: check it
  compiles; then test: host on Android 13+ and on 9, join from 10+, join from 9 (manual), two hotspots bridged by a
  phone on "Both", hotspot closing when Wasl closes, Samsung / Xiaomi quirks (STA drop while hosting).
- Not done (ideas): automatic hosting when many people are on Bluetooth only; QR code for phones without Wasl.

## Next release: 1.4 — owner said "do all your suggestions", phone tests postponed (2026-11-27)

| # | Step | State |
|---|------|-------|
| 1 | Dependencies: pub upgrade incl. gal 3 / permission_handler 13 (compileSdk 37; "permanently denied" now only from `request()`) | done — verified by the 1.4 build |
| 2 | SOS: emergency status in presence (`sos {t}`), banner + generic notification for everyone in the mesh, card in Nearby, guide entry | done (`lib/features/sos/`) |
| 3 | Offline messages ("the message waits for its owner") | done — see below |
| 4 | Wasl network: automatic suggestion when many people are on Bluetooth only + Wi-Fi QR code | done — see below |
| 5 | GitHub social preview, F-Droid metadata, external-audit brief, design doc for signed names/messages | done — social preview = `docs/images/banner.en.png` (already 1280×640, the owner uploads it in GitHub settings); `fastlane/metadata/android/{en-US,ar}` + `docs/FDROID.md` (**blocker: play-services-nearby is proprietary** — options there); `docs/AUDIT.md`; `docs/SIGNING.md` (proposal, waits for the owner) |
| 6 | Docs, version 1.4, release notes, checks; build only with the owner's OK | done — **1.4 built** (`Releases/1.4v`, versionCode 5, same certificate as 1.2/1.3) |

### Step 3 — offline messages (done)

- `lib/features/mailbox/mailbox.dart`: `MailCrypto` (one-way sealed box to the recipient's static key + sealed
  receipts), `Envelope`, `CarryBox` (limits), `MailService` (outbox, hand-over to direct neighbours, carrying,
  delivery, receipts). Wire format and limits: `docs/PROTOCOL.md` §9; what carriers see: SECURITY (en/ar).
- Hub: `ChatHub.mail` is created with the router; control `mb` / `mbd` go to `MailService.receive`; a 15 s tick and
  every router change call `flush()`. `canQueueFor(chat)` = known key, not reachable, not blocked.
- Chat: `ChatSession.queueing` → `send()` goes to `sendOffline`; new `MessageStatus.queued` (last in the enum,
  hourglass icon). ChatPage keeps the input on in text-only mode (`ChatInputBar.textOnly`: no attach / camera / mic /
  games), notice `mailNotice`, hint `mailHint`. The receipt turns the bubble to delivered.
- Saved chats: the waiting envelopes go to `outbox.bin` in the vault and come back on start (a queued bubble whose
  envelope is gone becomes failed). The carry box is memory only.
- Tests: `test/mailbox_test.dart` (crypto, limits) + `test/mailbox_net_test.dart` (A → C carries → B, receipt back to
  A). Screenshot `chat-away` (normal + big). Guide entry under connection.

### Step 4 — Wasl network suggestion + QR (done)

- QR: "Network QR" button on the hosting card opens a sheet with a standard Wi-Fi QR (`WifiOffer.qrText`,
  `WIFI:T:WPA|SAE|nopass;S:…;P:…;;`, special characters escaped), black on white in both themes. Drawn by
  `WifiQr` with the pure-Dart `qr` package (BSD-3, GPL-compatible). For phones that can't join from inside Wasl.
- Suggestion: `WaslNetSuggestBanner` (home, "Both" mode only) when ≥ 3 direct neighbours are on Bluetooth only, no
  Wasl network is offered nearby, and my id is the smallest among them (`WaslNetwork.suggestAmong`) — so one phone
  gets it, not everyone. "Not now" hides it until the hub stops; it doesn't come back after hosting once.
- Tests in `test/net_test.dart`; screenshots `net-qr`, `net-suggest` (normal + big). Guide "how to start" mentions
  the QR. No wire change.

### Extra (owner's request) — "Share Wasl" (done)

- Settings → "Share Wasl" (`lib/features/share/`). Step 1: "Start a Wasl network" button (owner: only on tap, not
  automatic) → Wi-Fi QR + name + password with copy. Step 2: QR of `http://<local ip>:8080/` served by
  `ShareServer` (dart:io, only while the screen is open, GET/HEAD on `/` and `/wasl.apk` only, ≤ 4 downloads).
  The page (`SharePage`) is self-contained HTML (no external fonts/images, CSP `default-src 'none'`), Khayamiya look,
  Arabic/English from the browser (`?l=` switch), install steps, SHA-256 fingerprint (also on the sender's screen).
- Android: `apkInfo` on `wasl/system` → installed APK path, size, SHA-256, split flag (a split install can't be
  shared — the screen says so). An arm64-only APK won't install on 32-bit phones; the page says to get the universal
  build.
- Address: `ShareServer.pickAddress` prefers the hotspot interface while hosting, else wlan; skips mobile data/VPN.
- Tests `test/share_test.dart` (page, file, refused paths, address choice); screenshots `share-idle`, `share-ready`
  (+ big); the page itself was checked in Firefox (ar/en). Guide entry; SECURITY (en/ar) section.
- **Needs the real-phone test**: interface names / addresses of the Local-Only Hotspot differ between phones.

Notes:
- `emoji_picker_flutter` and `flutter_webrtc` still apply the old Kotlin Gradle plugin (warning at build); they are at
  their latest versions — wait for upstream.
- **Android 17 adds a runtime `ACCESS_LOCAL_NETWORK` permission.** Today targetSdk is 36 so it isn't enforced; when
  targetSdk goes to 37, declare it and request it before starting Wi-Fi (LanLink / Wasl network).
- Signed names / group messages (SECURITY limitations 1–2) need an identity-binding design first — see
  `docs/SIGNING.md` (step 5); not implemented without the owner's OK.

## Decisions taken with the owner

**Privacy (2026-11-27, for 1.6)** — owner: "who talks to whom" must not be visible. Agreed: private routing tags for
direct chats / control messages (per-pair, rotating every 10 min, from a pair key), fixed-size padding, private
groups' membership hidden (members announce a secret tag; only owner/admins advertise the group), offline messages
with no sender/recipient in clear (carriers see a random envelope; recipient trial-opens), offline messages accepted
from known people only by default (+ a setting), **group invites** (a member can invite someone into a group).
Games: owner wants **everyone to play** (no narrator) — plan for cryptographic dealing sent to the owner, waiting.
Order: privacy (1.6) first, then the Bluetooth library.

**Releases (2026-11-27)** — publish **one GitHub release only: the latest version**, with notes covering everything
since the last published release (1.2). 1.3 and 1.4 are built locally but are not to be published on their own.

**Identity (2026-11-27)** — no usernames (nothing can reserve a name without a server). Display names are free and may
repeat; identity = key. Agreed: signed names / group messages with a **new id format** (v2 = hash of X25519 + Ed25519
keys; breaks compatibility with older versions — fine while users are few), a key "fingerprint" drawn as a small
khayamiya pattern (profile + verification only; a tiny mark next to a name only when two visible people share it), a
warning when a known person's name appears with another key, local nicknames, the existing "verified" badge.
Order: identity/signing first (1.5), then the Bluetooth library.

**Bluetooth library (2026-11-27)** — approved and postponed. The plan is kept **locally only** (`.claude/plans/`, not in the repo — owner: publish only what's meant to be public).

**Games (1.3)** — entry point is a 🎮 button in the chat input bar; it opens a sheet with the games that fit the chat
(direct = 2 players, group = group games). An invite card lands in the chat; in groups whoever wants to play taps
"join" and the creator taps "start". Result card + rematch at the end. Every game screen and every game tile has a
help button (`؟` in Arabic, `?` in English) that opens a detailed rules page.

- Direct: tic-tac-toe, connect four, battleship (board commitment so nobody can lie), rock-paper-scissors (commit →
  reveal), dots & boxes, memory, dice / coin (commit → reveal, fair).
- Group: memory (2–6), dots & boxes (2–4), spy "مين الجاسوس" (3–12; everyone gets the word except the spy, who gets
  the category; hints in turn, vote, a caught spy may guess the word among 8), quiz (2–15, 4 options, 15 s, points
  for correct + speed, time measured on each phone), mafia (5–15; mafia/doctor/detective/citizens; night → morning
  → 3-min discussion → vote; ties = nobody out; the role of whoever is voted out is revealed).
- Mafia discussion happens **inside the game screen** (dead players can't write; mafia get a private night chat).
- Anyone in a group can start a game.
- "Room host" = whoever started the game. In games with hidden information (mafia, spy, quiz) the host's phone is the
  referee: it deals roles sealed per player with `Box.pairKey` and counts votes. The host plays normally and the UI
  never shows them other players' roles. If the host leaves, the game ends for everyone. A modified app on the host
  could cheat — acceptable for party games; documented in SECURITY.md.
- Cards (كوتشينة) are out. Draw & guess is postponed.

**Identity (1.3)** — "Khayamiya" (the Cairo tent-makers' appliqué): saffron primary, night-ink text / dark background
(not black), tent red for games and alerts, faience teal for connection and safety. Signature elements: the dashed
"stitch" line for connections, a geometric khayamiya pattern used sparingly, Ramadan bunting when someone wins.
Font (IBM Plex Sans Arabic), layout and the 24 cartoon avatars stay. Other accent colours stay as options in settings;
the default becomes "wasl". Preview the owner approved: https://claude.ai/artifact/X2pPEhPXr5vdNNTt9qV4UJ

## Where the games live

- `lib/features/games/core/` — `GameKind` (ids on the wire), `GameEngine`/`TurnEngine` (rules base, commit helper),
  `GameRoom` (one room; host runs the engine, players send `act`s; message list in its doc comment),
  `GameCenter` (rooms of one conversation + their cards in the chat, 1 s pulse, `GameTransport`).
- `lib/features/games/engines/` — rules per game + `createEngine` + `autoMoves` (automatic reveal/answer moves).
- `lib/features/games/data/` — spy words and the quiz bank (bilingual `عربي|English`; quiz: right answer first).
- `lib/features/games/ui/` — picker sheet, chat card + running banner, game screen (lobby, result bar, reactions,
  game chat, countdown), boards (`boards_classic/secret/party.dart`), help page, per-game look (`game_look.dart`).
- Wiring: `ChatHub` gives every conversation a `GameCenter` (`_DirectGames` / `_GroupGames`); private group messages
  are control frames `{t: gm}` sealed with `Box.pairKey(..., 'wasl/game')`. Strings: `tool/l10n_games.py` writes them
  into both ARB files (`python3 tool/l10n_games.py && flutter gen-l10n`).
- Tests: `test/games_test.dart` (rules + rooms on a fake net), `test/mesh_test.dart` "الألعاب فوق الشبكة".
- Boards are always laid out LTR so both players see the same board whatever their language.

## Screenshots (design check)

`flutter test tool/shots/shots_test.dart` renders real screens with the real font into `build/shots/`
(`<name>.<ar|en>.<light|dark>.png`). Use `--name <part>` to render a subset, then `python3 tool/shots/sheet.py`
puts the four variants of each screen side by side in `build/shots/sheets/`. Sample people/chats: `tool/shots/sample.dart`. Look at the PNGs after every UI change:
RTL and LTR, light and dark, long names, small phones. It is not part of `flutter test` (it lives under `tool/`). The `big` group renders key screens with text at 1.3× (like
a phone's large-font setting): any text that spills out of its box fails the run — keep it green.

## Log

- 2026-11-27 — plan agreed with the owner; step 1 (screenshot tool) done.
- 2026-11-27 — step 2 (identity) done: `wasl` accent (default), `accentInk` for brand-coloured text, ink/saffron/
  tentRed/teal tokens, stitch/pattern/bunting/help widgets, khayamiya transport cards, "around you now" strip on the
  chats tab, stitched empty states, new launcher icon.
- 2026-11-27 — steps 3–5 (games) done: 9 games, picker, cards, help pages; screenshots reviewed (fixed: mirrored
  boards in Arabic, clipped grids, bidi of "{name}'s", narrow input field). Next: step 6 (Wasl guide in settings +
  `؟` on the transport screen), then step 7 (docs, version 1.3).
- 2026-11-27 — step 6 done: the old "how Wasl works" sheet became a full guide page (connection methods with
  drawings, mesh, groups, games linking to each help page, safety). Next: step 7 (docs + version 1.3).
- 2026-11-27 — large-text pass (1.3×) added to the screenshot tool; fixed every overflow it found.
- 2026-11-27 — step 7 done: docs/GAMES.md, PROTOCOL §8, SECURITY (en/ar) games section, READMEs, CONTRIBUTING,
  AGENTS.md, version 1.3.0+4, release notes. Waiting for the owner: real-phone test + OK to build.
- 2026-11-27 — owner: postpone the phone test, don't build, tidy the repo, then start 1.4. Repo: new README
  screenshots (ar + en) and banners in the new look, games/guide rows in the READMEs, CI runs the large-text check,
  PR/bug templates mention screenshots and games. Next: 1.4 (Wasl network).
- 2026-11-27 — Wasl network implemented (see its section): Kotlin + Dart + UI + guide + docs + tests; screenshots
  reviewed; the large-text check also caught an old overflow in the Nearby list (fixed). Release notes: added to 1.3
  because 1.3 was never published — ask the owner whether to ship one release or split 1.3 / 1.4.
- 2026-11-27 — security pass on games + Wasl network: group player→host messages must be sealed; malformed host
  states dropped (`ViewGuard`) and read safely (`ViewRead`); invite / reaction / chat flood limits; no evicting
  running rooms; refusing to reveal (battleships, RPS) = cheat after 20 s; direct rematch needs both players; kicked
  members can't send sealed game moves; Kotlin join can't hang; offer banner hidden when already on Wi-Fi with
  people. Tests: games_test (+5), games_ui_test (every game with real and junk state). Docs updated.
- 2026-11-27 — owner: ship everything as one release, 1.3 (games + identity + guide + Wasl network). Version stays
  1.3.0+4; release notes already cover all of it. Next: owner's OK to build, then the real-phone test.
- 2026-11-27 — 1.4 step 1 (dependencies) and step 2 (SOS) done and pushed.
- 2026-11-27 — 1.4 step 3 (offline messages) done: mailbox service, text-only input while the person is away,
  outbox kept for saved chats, mesh test, PROTOCOL §9, SECURITY, guide. Next: step 4 (Wasl network suggestion + QR).
- 2026-11-27 — 1.4 step 4 done: Wi-Fi QR on the hosting card, one-phone suggestion to open a Wasl network when
  many people are on Bluetooth only. Next: step 5 (social preview, F-Droid metadata, audit brief, signing design).
- 2026-11-27 — 1.4 step 5 done (docs only). Owner asked for a new feature: "share Wasl" in Settings (two QR codes:
  the hotspot + a download page served from the phone). Plan agreed (network opens only on tap).
- 2026-11-27 — "Share Wasl" done (see its section). Next: step 6 (docs, version 1.4, release notes), then ask to build.
- 2026-11-27 — 1.4 step 6 done: version 1.4.0+5, release notes (ar/en), fastlane changelogs/5, READMEs. All checks
  green. Waiting for: the owner's OK to build 1.4 (first build with compileSdk 37 — watch Gradle), the real-phone
  test (1.3 + 1.4 features, especially Wasl network / Share Wasl addresses on different phones), publishing v1.3.
- 2026-11-27 — owner: remove the release badge under the README banner (done), check security, then build 1.4.
  Security pass on 1.4: offline messages now reject envelopes with no time or older than 3 days (replay after the
  seen window), carriers check `sk` hashes to `f`, seen ids / pending receipts capped; SECURITY notes that the
  "drop your copy" note isn't authenticated (delay only). Fixed a flaky quiz test that was a real overflow: a long
  category name in the quiz header on a 360-px phone.
- 2026-11-27 — 1.4 built with the owner's OK from 280836a: 4 APKs + SHA256SUMS in `Releases/1.4v`, certificate
  SHA-256 fa4ecf16…c341 (same as 1.3), versionCode 5, compileSdk 37 / targetSdk 36. The first try failed in
  `android_file_picker` 2.2.1 ("Unresolved reference LostDataStore") — a stale Gradle cache after the dependency
  update; `flutter clean` fixed it. **After a dependency update, run `flutter clean` before building.**
  Not published yet (neither v1.3 nor v1.4). Left for the owner: publish, social preview, F-Droid choice, signing
  design, external audit, real-phone test.
- 2026-11-27 — owner: a security review is now required after every new feature (added to AGENTS.md). Owner set the
  GitHub social preview. Postponed: real-phone test, publishing, external audit. Owner to decide: F-Droid route
  (docs/FDROID.md) and signing design (docs/SIGNING.md).
- 2026-11-27 — 1.5 identity done (parts 1–2 + docs): Ed25519 signing key from the seed, id v2 =
  SHA-256("wasl/id/v2"‖X25519‖Ed25519)[0..8], signed presence `{d, sg}` with monotonic `t` (re-signed on change / 5 min,
  verified once per `d`, ≤ 1 check per node per 0.5 s, SOS ignored if `t` > 30 min old), signed group packets
  (`xk`/`ek`/`sg`, not `fc`/`typ`), mail envelopes carry `ek`. UI: fingerprint (`widgets/fingerprint.dart`), mark next
  to repeated names, "Not them?" + chat warning (`impostorOf`, `NameMatch`), nicknames (person sheet "About").
  Tests: identity_test, names_test (+ all old ones updated). Security review: presence-flood rate limit added; replay
  of a genuine old group message noted in SECURITY. **No migration**: 1.5 can't talk to older versions; old saved chats
  stay readable but won't reconnect; old groups must be created again (say so in the release notes).
  Repo description/topics updated (owner OK). Next: website (GitHub Pages), version 1.5 + one release note since 1.2.
- 2026-11-27 — website live: https://adamg00d.github.io/Wasl/ (ar) + /en/, built by `tool/site.py` into `site/`,
  published by `.github/workflows/pages.yml` (Pages enabled via API, build type "workflow"); SEO: title/description,
  hreflang, Open Graph, JSON-LD SoftwareApplication + FAQPage, sitemap, robots. Repo homepage → the site. Owner still
  has to add it to Google Search Console. Version 1.5.0+6, release notes 1.5v (ar/en) cover everything since 1.2
  (one release only, owner's rule), fastlane changelogs/6. All checks green. Not built yet — waiting for the owner.
- 2026-11-27 — groups: signed send time `at` in every packet; an older edit can't undo a newer one (test added).
  Google Search Console: verification file `site/google6da38e735cb6412d.html` (generated by tool/site.py) is live.
  **1.5 built and published** (owner's OK): https://github.com/AdamG00D/Wasl/releases/tag/v1.5 — tag v1.5 at d104409,
  4 APKs + SHA256SUMS, certificate fa4ecf16…c341, versionCode 6. 1.3 / 1.4 were never published (one release rule).
  Next: owner finishes Search Console; then the Bluetooth library (plan first).
- 2026-11-27 — 1.6 privacy, parts 1–3 done (not released yet): route tags for D/U frames (all mesh tests now run
  through them), padding, mailbox v2 (no ids in clear, carriers offer to every neighbour, ≤ 3 hand-overs, trial-open
  ≤ 60/min/neighbour, accept from known people by default + setting "waiting messages from anyone"), hidden membership
  in private groups (`gt`), group invites (`gi`; ask-mode = owner only, pre-approves). Security review: invite with a
  forged owner for a visible group is dropped. Website: download button = `releases/latest/download/Wasl-android.apk`
  (build script now also writes `Wasl-android.apk` / `Wasl-android-universal.apk`; both added to the v1.5 release);
  "protests" removed from the site (README / fastlane still mention it — ask the owner).
  Waiting for the owner: OK on the games plan (crypto dealing for spy, dealing + role commitment for mafia).
- 2026-11-27 — 1.6 finished (not built): privacy parts 1–3, join-request invites need the owner's approval unless the
  owner invited (`gj` carries `by`), **secret groups** (mode `s`: never advertised, everyone announces `gt` tags,
  invite-only from owner/admins; new admin op `add`, the owner keeps admin-added members on state sync),
  **fair dealing for Who's the spy** (`games/core/fair_deal.dart` + `spyMoves`: host never knows the spy or the word;
  caught player proves with `e`; everyone reveals and `DealCheck.verify` runs on every phone), **mafia role
  commitment** (`rc`/`rs`, `mafiaCheck`, banner at the end). "Protests" removed from READMEs and store texts.
  Version 1.6.0+7, release notes 1.6v (since 1.5), fastlane changelogs/7, READMEs, site, guide entry. Security review
  done for each part (see SECURITY en/ar). Waiting for the owner: OK to build + publish 1.6, real-phone test.
- 2026-11-27 — owner feedback fixed before the 1.6 build: buttons never cut their text (wrap to two lines, then
  shrink — `_ButtonLabel` in widgets/ui.dart, test/buttons_test.dart); Wasl network: hostStart times out after 25 s,
  while hosting the app asks the system every 3 s and resets if the hotspot was closed from outside, password can be
  hidden again, "close the network" button on the Share page. Phone tests postponed by the owner. Search Console:
  sitemap still "couldn't fetch" (common for new github.io sites) — owner should use URL inspection → request indexing.
- 2026-11-27 — **1.6 built and published** (owner's OK): https://github.com/AdamG00D/Wasl/releases/tag/v1.6 — tag at
  ffaeba8, 6 APKs (incl. stable `Wasl-android*.apk` for the site button) + SHA256SUMS, certificate fa4ecf16…c341,
  versionCode 7. The website's download button now serves 1.6. Next: the Bluetooth library plan (kept locally).
- 2026-11-27 — Bluetooth library plan approved and **postponed**; kept locally (not published).
  Next now: an Arabic promo/demo video made entirely by Claude (owner: no voice, no phone recordings needed).
- 2026-11-27 — **Renamed to Ganbak (جنبك), version 2.0.0+8** (code, package `com.adam.ganbak`, Dart package `ganbak`,
  docs, store texts, banners, README/store/site images; repo renamed to `AdamG00D/Ganbak`; site live at
  `https://adamg00d.github.io/Ganbak/`). Protocol labels / Nearby service id kept, so 2.0 still talks to Wasl 1.6.
  Owner's name no longer appears in samples / screenshots (neutral name).
- 2026-11-27 — Promo video made (Arabic, ~45 s, vertical 9:16 + horizontal 16:9, real app running on a simulated
  mesh, original background music); the video tooling and files are kept locally, not in the repo.
- 2026-11-27 — Websites for the owner's other apps Shen and Mongez (`adamg00d.github.io/Shen`, `/Mongez`), same
  generator idea (`tool/site.py` in each repo, Pages workflow, download button finds the latest APK via the GitHub
  API). Owner: add each site to Google Search Console.
- 2026-11-27 — Fixed: game scores were swapped in Arabic (the score text was forced LTR while the names flip in RTL;
  now a Row that follows the direction; test added). **Ganbak 2.0 built and published** (owner kept 2.0):
  https://github.com/AdamG00D/Ganbak/releases/tag/v2.0 — 7 files incl. `Ganbak-android*.apk`, same certificate,
  versionCode 8, labels جنبك / Ganbak. The same Google verification file is live on /Ganbak/, /Shen/ and /Mongez/.
  Folder rename: owner runs `~/Downloads/rename_ganbak_folders.sh` after closing VS Code (copies the Claude project
  folder to the new path); then update the folder line in AGENTS.md.

