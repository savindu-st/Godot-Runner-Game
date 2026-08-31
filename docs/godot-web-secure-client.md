# Godot Web Export — Secure Client Architecture

> **Game:** Ever Dash (Godot 4.6, HTML5/WASM export)  
> **Companion:** [godot-web-secure-server.md](./godot-web-secure-server.md)  
> **Scope:** No login/registration yet — anonymous **session + HMAC** only.  
> **Rule:** Client is fast; server is truth for score, seeds, and progression.

---

## 1. How this maps to your project today

| Current (`level.gd`, `player_script.gd`) | Secure target |
|------------------------------------------|---------------|
| `randomize()` + global `randf()` / `randi()` | **Seeded** `RandomNumberGenerator` or custom Xoshiro per segment |
| Timer-based spawns (coins, rocks, trees) | **Deterministic** spawn schedule from segment seed |
| 3 lanes `road_spawnx = [-2, 0, 2]` | Same lanes — server must use identical constants |
| `run_distance`, `LANE_SCROLL_SPEED = 15` | Distance is the primary replay axis |
| Local `score`, `coin_count` in HUD | Display only — server returns verified totals |
| No network | `HTTPRequest` + signed checkpoint payloads |

Cosmetic spawns (trees, bushes, signs) may stay non-deterministic **only if they do not affect score or collisions**. Anything that affects gameplay must come from the seed.

---

## 2. Architecture overview

```
┌──────────────────────────────────────────────────────────────┐
│  Browser (Godot HTML5 export: WASM + .pck)                    │
│                                                               │
│  menu.tscn ──► RunSession (autoload) ──► POST /session/start │
│                     │                                         │
│  level.tscn ◄───────┘  map_seed, signing_secret               │
│       │                                                       │
│       ├── SegmentMapGen (seeded spawns)                       │
│       ├── Player (lanes, jump, collision)                     │
│       └── MoveLog (compact events)                              │
│                     │                                         │
│                     └──► ApiClient.sign_and_post(checkpoint)  │
└──────────────────────────────┬───────────────────────────────┘
                               ▼
                        Server re-simulates
```

---

## 3. Recommended folder layout

Add under `scripts/secure/` (keep game code separate from anti-cheat plumbing):

```
scripts/secure/
├── run_session.gd      # Autoload: session_id, secret, run_id, current seed
├── api_client.gd       # HTTPRequest, HMAC headers, JSON bodies
├── move_log.gd         # Event buffer + serialize for checkpoint
├── seeded_rng.gd       # Deterministic PRNG (match server)
├── segment_map.gd      # Spawn table from seed (coins, rocks)
├── sim_constants.gd    # Shared numbers — copy to server doc verbatim
└── hmac_sign.gd        # Canonical string + HMACContext
```

**Autoloads** (in `project.godot`):

```
RunSession="*res://scripts/secure/run_session.gd"
ApiClient="*res://scripts/secure/api_client.gd"
SimConstants="*res://scripts/secure/sim_constants.gd"
```

---

## 4. Web export hardening

### 4.1 Export preset (Godot 4.6)

| Setting | Value | Why |
|---------|-------|-----|
| Platform | Web | |
| Threading | **Single-threaded** (Godot 4.3+) | Fewer COOP/COEP issues on itch.io / static hosts |
| Debug | **Off** for release | No debug symbols in shipped build |
| Custom template | Release export template | Strip unused modules if you build custom templates |
| Encrypt pack | Optional (export encryption key) | Raises bar; not foolproof |

### 4.2 Post-export pipeline

```bash
# After export to build/web/
wasm-opt -Oz build/web/Runner.wasm -o build/web/Runner.wasm
```

Run in CI for every release build.

### 4.3 Hosting headers

- **Single-threaded export:** standard static hosting is usually enough.
- If you enable threads later: `Cross-Origin-Opener-Policy: same-origin` and `Cross-Origin-Embedder-Policy: require-corp`.

### 4.4 Code hygiene

- Put **spawn rules, cooldowns, and segment length** in `sim_constants.gd` — one file to mirror on the server.
- Avoid `randomize()` anywhere in gameplay paths after secure mode is on.
- Do not embed the signing secret in the project; it arrives at runtime from `/session/start`.

---

## 5. Shared simulation constants

`scripts/secure/sim_constants.gd` — **must match server byte-for-byte logic:**

```gdscript
extends Node

const SIM_VERSION: int = 1

const NUM_LANES: int = 3
const LANE_X: Array = [-2.0, 0.0, 2.0]

const SEGMENT_LENGTH: float = 2000.0      # distance units per server segment
const CHUNK_LENGTH: float = 200.0

const SCROLL_SPEED: float = 15.0          # matches LANE_SCROLL_SPEED
const LANE_SWITCH_SPEED: float = 14.0
const LANE_SWITCH_COOLDOWN_MS: int = 100
const JUMP_FORCE: float = 9.0
const GRAVITY: float = 22.0
const JUMP_CLEAR_Y: float = 0.72          # rock hitbox tuning

const COIN_SCORE: int = 10
const DISTANCE_SCORE_PER_UNIT: float = 0.1
```

Bump `SIM_VERSION` whenever any constant or spawn algorithm changes.

---

## 6. Seeded procedural map generation

### 6.1 Why not global `rand*`

Your `level.gd` today:

```gdscript
randomize()
spawn_timer.wait_time = randf_range(1.2, 2.2)
var lane_idx: int = randi() % 3
```

That cannot be verified server-side. Replace gameplay spawns with seed-driven logic.

### 6.2 RNG class (Godot-native, portable)

```gdscript
# scripts/secure/seeded_rng.gd
class_name SeededRng
extends RefCounted

var _rng: RandomNumberGenerator

func _init(seed: int) -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = seed

func randf() -> float:
	return _rng.randf()

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)

func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func randi_mod(n: int) -> int:
	return _rng.randi() % n
```

**Important:** Use the same seed type (`int` / `uint64`) and call order on server. For cross-language parity tests, prefer a **custom Xoshiro** in GDScript if Node/Rust results diverge — document the choice in both docs.

### 6.3 Segment and chunk seeds

```gdscript
# Per segment (from server)
var segment_seed: int = RunSession.current_seed

# Per chunk along the segment
func chunk_seed(segment_seed: int, chunk_index: int) -> int:
	return hash(str(segment_seed, ":", chunk_index))
```

Use Godot’s `hash()` only if the server ports the same function (e.g. same string format). Safer: implement an explicit `fnv1a64(a, b)` in GDScript and duplicate on server.

### 6.4 Segment map output (compact)

`SegmentMapGen.generate(segment_seed) -> Array[SpawnEntry]`

```gdscript
class SpawnEntry:
	var kind: String       # "coin" | "rock"
	var lane: int          # 0..2
	var distance: float    # along segment, 0 .. SEGMENT_LENGTH
	var object_id: int     # stable id for verification
```

Generation rules (example):

1. Walk chunks `0 .. SEGMENT_LENGTH/CHUNK_LENGTH`.
2. For each chunk, roll obstacle count from seeded RNG.
3. Enforce min gap between rocks in the same lane.
4. Place coins in gaps (lower density than today’s timer spam).
5. **Do not spawn** trees/signs from this table — visuals can stay client-only.

### 6.5 Runtime spawning change in `level.gd`

Instead of `spawn_obstacle_timer` calling `randi()`:

1. Precompute or lazy-load spawn entries for the current segment.
2. When `run_distance` crosses `entry.distance`, instantiate coin/rock at `LANE_X[lane]`, `startz` equivalent.
3. Store `object_id` on the node (`set_meta("object_id", id)`).
4. On pickup/collision, log `{ object_id, lane, distance }`.

At `run_distance >= SEGMENT_LENGTH` and player alive → **checkpoint** (§8).

---

## 7. Movement and event logging

### 7.1 `MoveLog` responsibilities

- Record **semantic events**, not frames.
- Sort key: `distance` then `t_ms` (ms since segment start).

### 7.2 Event types (v1)

| `kind` | Fields | When |
|--------|--------|------|
| `lane_change` | `from`, `to`, `distance`, `t_ms` | Lane switch committed |
| `jump_start` | `distance`, `t_ms` | Jump initiated |
| `jump_land` | `distance`, `t_ms` | Optional; helps verify rock clears |
| `coin` | `object_id`, `lane`, `distance`, `t_ms` | Coin collected |
| `collision` | `object_id`, `lane`, `distance`, `t_ms` | Rock hit / death |

### 7.3 Example GDScript API

```gdscript
# scripts/secure/move_log.gd
class_name MoveLog
extends RefCounted

var segment_index: int
var seed: int
var initial_lane: int
var started_at_ms: int
var events: Array[Dictionary] = []

func reset(p_segment_index: int, p_seed: int, p_lane: int) -> void:
	segment_index = p_segment_index
	seed = p_seed
	initial_lane = p_lane
	started_at_ms = Time.get_ticks_msec()
	events.clear()

func add(kind: String, data: Dictionary) -> void:
	var e := data.duplicate()
	e["kind"] = kind
	e["t_ms"] = Time.get_ticks_msec() - started_at_ms
	events.append(e)

func to_dict(end_reason: String, final_distance: float) -> Dictionary:
	return {
		"sim_version": SimConstants.SIM_VERSION,
		"segment_index": segment_index,
		"seed": seed,
		"initial_lane": initial_lane,
		"events": events,
		"end_reason": end_reason,       # "segment_complete" | "collision"
		"final_distance": final_distance,
		"client_duration_ms": Time.get_ticks_msec() - started_at_ms,
	}
```

### 7.4 Hook points in existing scripts

**`player_script.gd`**

- On lane change: `MoveLog.add("lane_change", { "from": old, "to": new, "distance": _distance_from_level() })`
- On jump: `jump_start` / `jump_land`
- On death: `collision` with rock `object_id` from area metadata

**`coin.gd` / rock handler**

- On pickup: log `coin` with `object_id` from spawner meta

**Distance source:** expose `level.run_distance` (or segment-local distance) to the player via signal or group.

### 7.5 Client-side validation (soft)

Enforce before logging (server will reject anyway):

- Lane switch cooldown (`LANE_SWITCH_COOLDOWN_MS`)
- No lane change while `dying` / `game_over`
- One collision ends segment

---

## 8. Session and networking (no auth yet)

### 8.1 Flow

1. **Menu → Play:** `RunSession.start()` → `ApiClient.post("/v1/session/start")`
2. Server returns: `session_id`, `signing_secret` (base64), `expires_at`
3. `RunSession.begin_run()` → `POST /v1/run/start` → `run_id`, `seed`, `segment_index`
4. Load `level.tscn`; pass seed into `SegmentMapGen` + `MoveLog.reset`
5. On checkpoint/crash → signed `POST /v1/run/checkpoint` or `/finish`
6. On success: apply `next_seed`, reset segment distance, continue without menu

### 8.2 `RunSession` autoload (sketch)

```gdscript
extends Node

var session_id: String = ""
var signing_secret: PackedByteArray = PackedByteArray()
var run_id: String = ""
var segment_index: int = 0
var current_seed: int = 0
var api_base: String = "https://your-api.example/v1"

func has_session() -> bool:
	return session_id != "" and signing_secret.size() > 0
```

Store secrets **in memory only** — never `ConfigFile` / `localStorage` for v1.

### 8.3 HMAC signing (`HMACContext`)

```gdscript
# scripts/secure/hmac_sign.gd
class_name HmacSign
extends RefCounted

static func sha256_hex(body: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(body.to_utf8_buffer())
	return ctx.finish().hex_encode()

static func sign(secret: PackedByteArray, method: String, path: String, timestamp: String, nonce: String, body: String) -> String:
	var canonical := "%s\n%s\n%s\n%s\n%s" % [
		method, path, timestamp, nonce, sha256_hex(body)
	]
	var hmac := HMACContext.new()
	hmac.start(HashingContext.HASH_SHA256, secret)
	hmac.update(canonical.to_utf8_buffer())
	return hmac.finish().hex_encode()
```

### 8.4 `HTTPRequest` wrapper

```gdscript
# scripts/secure/api_client.gd — simplified
func post_signed(path: String, body_dict: Dictionary) -> void:
	var body := JSON.stringify(body_dict)
	var ts := str(int(Time.get_unix_time_from_system() * 1000.0))
	var nonce := _uuid()
	var sig := HmacSign.sign(RunSession.signing_secret, "POST", path, ts, nonce, body)

	var headers := [
		"Content-Type: application/json",
		"X-Session-Id: " + RunSession.session_id,
		"X-Timestamp: " + ts,
		"X-Nonce: " + nonce,
		"X-Signature: " + sig,
	]
	_request.request(RunSession.api_base + path, headers, HTTPClient.METHOD_POST, body)
```

Use `HTTPRequest` node as child of autoload or scene tree root; connect `request_completed` for async UI.

### 8.5 Offline / failure UX

| Case | Client behavior |
|------|-----------------|
| No network at Play | Show “Connection required” (or offline practice mode with no leaderboard) |
| Checkpoint 422 | Show “Run invalid”; return to menu |
| Retry | Same body + nonce if idempotent (server doc) |

---

## 9. Client-side protections (defense in depth)

| Measure | Notes |
|---------|-------|
| Input cooldowns | Already partly in player; align with `SimConstants` |
| Speed cap | Distance advance only via `SCROLL_SPEED` (+ verified jump arc) |
| Seed mixing | Optional: `effective_seed = hash(segment_seed, client_pepper)` — pepper is public in WASM; real security is server replay |
| Script encryption | Export with encryption key |
| Anti-debug | Weak: detect large `Engine.get_frames_per_second()` drops — optional, do not rely on |
| Hide API URL | Obfuscation only; assume exposed |

**Never trust:** local `score`, `coin_count` for rewards — update HUD from server response after checkpoint.

---

## 10. Integration checklist for `level.gd`

Phase 1 minimal loop:

- [ ] Remove `randomize()` from `_ready` for gameplay RNG
- [ ] Add `var segment_local_distance: float` reset each segment
- [ ] Replace coin/rock timer random spawns with `SegmentMapGen` driven by `RunSession.current_seed`
- [ ] Tag spawned nodes with `object_id`
- [ ] Fire checkpoint when `segment_local_distance >= SimConstants.SEGMENT_LENGTH`
- [ ] Pause input during checkpoint HTTP (or continue scroll — design choice)
- [ ] On checkpoint OK: increment `segment_index`, set new seed, clear spawned gameplay objects, reset log

Keep decorative `spawn_env_timer` trees **non-scoring** until you need full determinism.

---

## 11. Testing (client)

### 11.1 Golden map test (Editor)

```gdscript
# test/test_segment_map.gd
func test_seed_12345_stable() -> void:
	var a = SegmentMapGen.generate(12345)
	var b = SegmentMapGen.generate(12345)
	assert_eq(a.size(), b.size())
	for i in a.size():
		assert_eq(a[i].object_id, b[i].object_id)
		assert_eq(a[i].distance, b[i].distance)
```

Export the same seed JSON for server CI.

### 11.2 Cheat injection tests

- Log fake coin without overlap → expect server reject in integration test
- Impossible lane teleport in log → server reject
- Double-submit same checkpoint → idempotent OK

### 11.3 Web export smoke test

- Export HTML5, serve locally, complete one segment, verify network tab shows signed POST

---

## 12. Implementation phases

### Phase 1 — Minimal secure loop

- [ ] `SimConstants`, `SeededRng`, `SegmentMapGen`
- [ ] `MoveLog` + hooks in player/coin/rock
- [ ] `RunSession` + `ApiClient` + `HmacSign`
- [ ] Menu waits for `/session/start` + `/run/start` before `change_scene_to_file(level)`
- [ ] Mock server or real backend (see server doc)

### Phase 2 — Seamless segments

- [ ] Checkpoint without scene reload
- [ ] Prefetch next seed while playing last 10% of segment
- [ ] Server score drives HUD

### Phase 3 — Hardening

- [ ] wasm-opt in export script
- [ ] Pack encryption
- [ ] MessagePack bodies (optional)
- [ ] Anomaly messaging for rejected runs

---

## 13. Godot Web specifics

| Topic | Guidance |
|-------|----------|
| `HTTPRequest` | Works in web export; CORS must allow your API origin |
| `OS.shell_open` | Menu ticket link — fine on web |
| `Time.get_ticks_msec()` | Use for segment duration; server allows slack |
| Threading | Avoid for v1 |
| File write | No local replay files in browser |
| Debugging | Use remote debug sparingly; test signed flow in exported build |

---

## 14. References

- Server verification, API, DB: [godot-web-secure-server.md](./godot-web-secure-server.md)
- Existing gameplay: `scripts/level.gd`, `scripts/player_script.gd`, `scripts/coin.gd`
- Godot docs: [Exporting for Web](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [HMACContext](https://docs.godotengine.org/en/stable/classes/class_hmaccontext.html), [HTTPRequest](https://docs.godotengine.org/en/stable/classes/class_httprequest.html)
