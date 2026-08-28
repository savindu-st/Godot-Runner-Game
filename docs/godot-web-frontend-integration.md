# Frontend integration guide (Godot client)

API base: configure in `scripts/secure/sim_constants.gd` → `API_BASE` (default `http://localhost:8080`). Set `CORS_ORIGIN` on the server for web/HTML5 builds.

**Score rule:** only collected **coins** count. Distance does not add score. Leaderboard uses each player’s **best run coin total**.

---

## User flow

```
Register or Login → AuthSession stores JWT
	   ↓
POST /v1/session/start  (Bearer JWT) → session_id + signing_secret
	   ↓
POST /v1/run/start      (HMAC signed) → run_id + seed
	   ↓
Play → POST /v1/run/checkpoint or /v1/run/finish (HMAC signed)
	   ↓
On finish: server returns final_coins, best_coins, rank
```

User must **login before play** when `API_BASE` is set. Menu shows **LOGIN TO PLAY** until authenticated.

---

## Godot autoloads

| Autoload | Role |
|----------|------|
| `AuthSession` | JWT, username, index_number, best_coins |
| `ApiClient` | `post_unsigned`, `post_with_jwt`, `post_signed`, `get_json` |
| `RunSession` | Game session, seeds, checkpoints, `run_total_coins` |
| `MoveLog` | Verifiable event log |
| `SimConstants` | `SIM_VERSION`, spawn tuning, `API_BASE` |

---

## UI (implemented)

| Screen | File |
|--------|------|
| Menu + auth overlay | `scripts/menu.gd`, `scripts/auth_panel.gd` |
| Leaderboard overlay | Menu → **LEADERBOARD** |
| Game HUD | `scripts/player_script.gd` — coins only |
| Game over rank | Waits for `RunSession.finish_resolved` |

### Menu

- **LOGIN / REGISTER** — opens auth panel (index, password; register adds username + optional contact)
- **PLAY** — disabled until logged in (when API configured)
- User line: `Username · Best N coins`
- **LEADERBOARD** — top 10 + your rank if logged in
- **LOGOUT** — clears `AuthSession`

### Auth panel

- Login: `POST /v1/auth/login`
- Register: `POST /v1/auth/register` (201)
- On success: `AuthSession.set_auth(body)` → refreshes menu

---

## API quick reference

### Register

`POST /v1/auth/register`

```json
{
  "index_number": "B2024001",
  "username": "Nipun",
  "password": "secret123",
  "contact_number": "+94771234567"
}
```

### Login

`POST /v1/auth/login`

```json
{
  "index_number": "B2024001",
  "password": "secret123"
}
```

Response includes: `token`, `user_id`, `index_number`, `username`, `best_coins`.

### Session start (JWT)

`POST /v1/session/start` — header `Authorization: Bearer <token>`

### Run start / checkpoint / finish (HMAC)

Signed headers: `X-Session-Id`, `X-Timestamp`, `X-Nonce`, `X-Signature`

Checkpoint response fields: `run_total_coins`, `next_seed`, `next_segment_index`

Finish response fields: `final_coins`, `best_coins`, `rank`, `total_players`

---

## Debugging

- `SimConstants.DEBUG_API = true` — logs all HTTP in console
- `SimConstants.OFFLINE_FALLBACK = false` — fail loudly instead of offline mode when API is down
- Empty `API_BASE` — full offline/local seeds (no login required)

---

## Web export notes

- Set `API_BASE` to your **public** API URL (not `localhost` in browser builds)
- Server must allow your game origin via `CORS_ORIGIN`
- JWT kept in memory only (`AuthSession`)

---

## Related docs

- [godot-web-secure-client.md](./godot-web-secure-client.md)
- [godot-web-secure-server.md](./godot-web-secure-server.md)
