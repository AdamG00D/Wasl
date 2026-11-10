# Wasl protocol

This is the reference for everything that goes over the air. The tests in `test/` cover these rules — keep them
green, and update this file with any change.

Layers, bottom to top:

```
MeshLink      neighbour links carrying text frames      lib/mesh/{lan,nearby,dual}_link.dart
MeshRouter    presence, flooding, unicast routes        lib/mesh/mesh_router.dart
PeerLink      session ids for a direct chat             lib/mesh/peer_link.dart
SecureChannel end-to-end encrypted direct chat          lib/features/chat/core/secure_channel.dart
GroupSession  group-key encrypted broadcast             lib/features/groups/group_session.dart
GroupOps      authenticated group admin commands        lib/features/groups/group.dart
```

## 1. Identity

- Every profile has a static X25519 key pair derived from a random 32-byte seed.
- **Node id** = hex of the first 8 bytes of `SHA-256(public key)` (16 hex chars).
- Anything claiming an id must show the public key that hashes to it; the direct-chat handshake proves possession
  of the private key.

## 2. Links

A link carries UTF-8 text frames between two neighbours.

| Link | Discovery | Transport | Frame limit |
|---|---|---|---|
| `LanLink` | UDP broadcast beacon `{"wasl":1,"id","port"}` every 1.5 s on port 47332 | one TCP connection per neighbour (port 47331), newline-delimited | 200 KiB |
| `NearbyLink` | Google Nearby Connections, `P2P_CLUSTER`, service id `com.adam.wasl.mesh` | BYTES payloads, auto-accept, ≤ 5 links | 30 000 chars |
| `DualLink` | both at once | link ids prefixed `w:` / `b:` | per link |

The node with the smaller id dials first; the other side tries after a delay. Connections are accepted
automatically — security is end-to-end, not at the link.

With `DualLink`, if the same node is reachable both ways the Wi-Fi link wins (`rank`) and the Bluetooth one is
dropped.

## 3. Mesh frames

```
kind|src|dst|pid|ttl|body
```

| kind | meaning | dst |
|---|---|---|
| `P` | presence (broadcast) | `*` |
| `X` | leaving (broadcast) | `*` |
| `G` | group packet (broadcast) | group id |
| `D` | direct-chat data (unicast) | node id |
| `U` | control JSON (unicast) | node id |

Link-local frames (never routed):

- `H|<id>` — hello; must arrive within 8 s of the link coming up.
- `F|<fid>|<i>|<n>|<part>` — fragment. A frame longer than the outgoing link's limit is split into `n ≤ 64` parts,
  sent in order, and reassembled by the neighbour (max 256 KiB). This is what lets a Wi-Fi-sized frame cross a
  Bluetooth hop.

Rules:

- `ttl` starts at 6 and is decremented by each relay; a frame with `ttl ≤ 1` is not forwarded.
- Dedupe by `src + pid`.
- **Broadcast**: forward once to every neighbour except the one it came from and except neighbours that are also
  neighbours of that sender (they already have it).
- **Unicast**: send on the direct link, else via the neighbour the destination's last packet arrived through, else
  flood.
- **Presence** body: `{n: name, c: colour, k: base64 public key, a?: avatar hash, e?: cartoon avatar number,
  g: [group ads], nb: [neighbour ids]}`. Dropped unless `k` hashes to `src`. Sent every 3 s; a node silent for 11 s
  is gone.
- **Group ad**: `{i: id, n: name, m: o|p|a, o: owner id, c?: key check, h?: admin-state digest}`.

Control messages (`U`, JSON with `t`):

| `t` | purpose | authenticated by |
|---|---|---|
| `av?` / `av` | ask for / send an avatar JPEG by hash | content hash |
| `gj` | join request to a group owner | — (owner decides) |
| `gk` | group key grant | AES-GCM with `pairKey(owner, member, "wasl/group-grant")`, aad `wasl/grant\|gid\|member` |
| `gr` | join request rejected | same pair key, aad `wasl/reject\|gid\|member` |
| `ga` | group admin command (§6) | pair key, see below |

`pairKey(a, b, info)` = `HKDF(X25519(static a, static b), info)`. Because a node id is the hash of its static key,
a box that opens with the pair key of id *x* was made by the holder of *x*'s private key.

## 4. Direct chat (SecureChannel, protocol v1)

`PeerLink` prefixes every frame with a random session id: `sid|frame`. A hello with a new sid replaces the session;
on simultaneous dials the smaller node id's sid wins; frames with an old sid are dropped.

Handshake:

1. Each side sends `hello {v, name, pub: ephemeral X25519, id: static X25519, n: nonce}`.
2. `ikm = X25519(eph, eph) ‖ X25519(static, static)`; keys = `HKDF-SHA256(ikm, info, salt = transcript hash)` for
   `A->B`, `B->A`, `confirm-A`, `confirm-B`.
3. Each side sends an HMAC over the transcript (`confirm`). No confirm → no channel.
4. The hub also checks that the peer's static key hashes to the node id the chat is with.

Then every packet is `{"t":"e","d": base64(nonce ‖ AES-256-GCM(json) ‖ tag)}`, aad `wasl/chat/v1`, with a strictly
increasing `seq` (replays dropped). Heartbeat every 5 s; no traffic for 15 s → `lost`.

Packet kinds (`k`): `msg` (`id, text, ts, rp?, fw?`), `ack`, `typing`, `read {ids}`, `del {id}`, `edit {id, text}`,
`react {id, e, by}`, `file-start / file-chunk / file-end / file-ack / file-cancel`, `call` (WebRTC signalling),
`ping`, `bye`.

- Unknown kinds are ignored, so new kinds are backwards compatible. **Changing the meaning or shape of an existing
  one requires bumping `protocolVersion`.**
- Safety code: 6 digits from a hash of both static keys — the same on both phones, stable across sessions.

File transfer: `file-start {id, mk, size, ext, name?, cs, n, ae, …}` → `file-chunk {id, i, d}` … →
`file-end {id, sha}`. The receiver acks every `ae` chunks (`file-ack {id, got, need?}`); the sender keeps at most
`window` chunks unacknowledged and resumes from `got` after a reconnect (up to 90 s).

## 5. Groups

Body of a `G` frame = `base64(AES-256-GCM(groupKey, json))`, aad `wasl/group/v1|<group id>`.

| Mode | Key |
|---|---|
| open (`o`) | `SHA-256("wasl-open-group\|" + id)` — public by design |
| password (`p`) | `Argon2id(password, salt = SHA-256("wasl-group-salt\|" + id)[0..16])` |
| join request (`a`) | random 32 bytes, handed over with `gk` |

`check` = `HKDF(key, "wasl/group/check", 8 bytes)` hex; used to validate a password or a granted key.

Packet: `{k, s: sender id, n: sender name, …}`. **A packet is dropped unless `s` equals the mesh `src`** and the
sender is not in the group's removed list.

| `k` | fields |
|---|---|
| `msg` | `id, text, ts, rp?, mn? {id: name}, fw?` |
| `edit` / `del` | `id` (+ `text`) — own messages only |
| `fs` / `fc` / `fe` / `fx` | file start / chunk / end (SHA-256) / cancel — broadcast in order, no acks, size-limited |
| `typ` | typing now |
| `rd` | `ids` — "I read these" |
| `rx` | `id, e, o` — reaction on message `id` whose author is `o` (`e` empty = remove) |
| `join` / `leave` | — |

## 6. Group administration (GroupOps)

Group packets are sealed with a key every member has, so they cannot carry authority. Admin commands are sent as
`U` control messages, one per recipient:

```
{"t":"ga","g": group id,"d": base64(AES-256-GCM(pairKey(sender, recipient, "wasl/group-admin"), json))}
aad = "wasl/ga|<group id>|<sender id>|<recipient id>"
```

The command JSON has `op`, a strictly increasing `n` per sender (replay protection) and `rev`.

| `op` | who | effect |
|---|---|---|
| `kick {id}` | owner; admin (not on owner/admins) | add to removed list, drop from admins/members |
| `unban {id}` | owner, admin | remove from removed list |
| `admin {id, on}` | owner only | appoint / dismiss an admin |
| `name {name}` | owner, admin | rename |
| `del {mid, sid}` | owner; admin (not on the owner's messages) | delete message `mid` of author `sid` for everyone |
| `key {key, kr}` | owner, admin | new group key (join-request groups, after a removal) |
| `state {rev, name, admins, banned, members, kr, key?}` | owner, admin | full snapshot |

- The owner can never be removed, demoted or overridden.
- Join-request groups rotate the key on `kick` and send `key` to the remaining members only.
- State converges through `digest` (`h` in the group ad): an admin who sees a member advertising a different
  digest sends `state`. From the owner, `state` with `rev ≥` mine replaces mine. From an admin, only a newer `rev`
  does (ties: plain members follow the admin; between admins the smaller id wins). The owner takes only removals
  from an admin's `state` and then bumps `rev`, so the owner's view always wins.
- A fresh member trusts only the owner until the owner's `state` tells it who the admins are.

## 7. Storage

- A random storage key encrypts every file (AES-256-GCM); the storage key is wrapped by an AES key inside Android
  Keystore.
- A conversation is written only if `saveOverride ?? AppSettings.saveChats` (default off). Media of saved chats
  lives in `vault/media/<id>/`; everything else is in temp folders wiped when the hub stops.
- Mute/pin choices for unsaved chats are dropped when the hub stops.
