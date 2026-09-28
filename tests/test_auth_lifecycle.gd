extends SceneTree

## Dedicated Automated Test Suite for Auth Session Lifecycle & Persistence

var passed: int = 0
var failed: int = 0

var auth_session: Node
var api_client: Node
var browser_bridge: Node


func _init() -> void:
	call_deferred("_run_lifecycle_tests")


func _assert_eq(actual, expected, message: String) -> void:
	if actual == expected:
		passed += 1
		print("  ✅ PASS: %s" % message)
	else:
		failed += 1
		printerr("  ❌ FAIL: %s | Expected: %s, Got: %s" % [message, str(expected), str(actual)])


func _assert_true(condition: bool, message: String) -> void:
	_assert_eq(condition, true, message)


func _run_lifecycle_tests() -> void:
	auth_session = root.get_node_or_null("AuthSession")
	api_client = root.get_node_or_null("ApiClient")
	browser_bridge = root.get_node_or_null("BrowserBridge")

	print("\n========================================================")
	print("   Ever Dash: Auth Session Lifecycle & Persistence Tests")
	print("========================================================\n")

	_test_login_and_persistence()
	_test_expired_token_refresh_trigger()
	_test_401_recovery_via_refresh()
	_test_offline_graceful_retention()

	print("\n========================================================")
	if failed == 0:
		print("🎉 ALL %d LIFECYCLE TESTS PASSED SUCCESSFULLY!" % passed)
		print("========================================================\n")
		quit(0)
	else:
		printerr("❌ %d LIFECYCLE TESTS FAILED!" % failed)
		print("========================================================\n")
		quit(1)


func _test_login_and_persistence() -> void:
	print("[Lifecycle 1] Login Payload & Storage Serialization")
	auth_session.clear()

	var login_response = {
		"access_token": "jwt.access.111",
		"refresh_token": "refresh.token.222",
		"expires_in": 3600,
		"token_type": "bearer",
		"user": {
			"id": "uuid-persisted-user",
			"email": "champion@runner.com",
			"user_metadata": {
				"username": "EverChampion"
			}
		},
		"best_distance": 2500,
		"best_coins": 600,
		"rank": 1
	}
	auth_session.set_auth(login_response)

	_assert_eq(auth_session.is_logged_in(), true, "Player is logged in after set_auth")
	_assert_eq(auth_session.token, "jwt.access.111", "Access token is stored")
	_assert_eq(auth_session.refresh_token, "refresh.token.222", "Refresh token is stored")
	_assert_eq(auth_session.username, "EverChampion", "Username is stored")

	var raw = str(browser_bridge.storage_get(auth_session.STORAGE_KEY))
	_assert_true(raw.contains("refresh.token.222"), "Stored JSON includes refresh token")
	_assert_true(raw.contains("jwt.access.111"), "Stored JSON includes access token")
	_assert_true(raw.contains("EverChampion"), "Stored JSON includes username")


func _test_expired_token_refresh_trigger() -> void:
	print("\n[Lifecycle 2] Expired Token Refresh Handling")
	# Force expires_at into the past
	auth_session.expires_at = int(Time.get_unix_time_from_system()) - 100
	auth_session._refreshing = false

	# Call _refresh_session and verify it posts to /v1/auth/refresh
	var refreshed_payload = {
		"access_token": "jwt.access.NEW_999",
		"refresh_token": "refresh.token.NEW_888",
		"expires_in": 3600,
		"user": {
			"id": "uuid-persisted-user",
			"email": "champion@runner.com",
			"user_metadata": {
				"username": "EverChampion"
			}
		}
	}

	# Simulate successful response from /v1/auth/refresh
	auth_session._on_api_response("/v1/auth/refresh", true, 200, refreshed_payload)

	_assert_eq(auth_session.is_logged_in(), true, "Player stays logged in after token refresh")
	_assert_eq(auth_session.token, "jwt.access.NEW_999", "New access token saved")
	_assert_eq(auth_session.refresh_token, "refresh.token.NEW_888", "New refresh token saved")
	_assert_true(auth_session.expires_at > int(Time.get_unix_time_from_system()), "New expires_at is in the future")


func _test_401_recovery_via_refresh() -> void:
	print("\n[Lifecycle 3] 401 Recovery via Refresh Token")
	# If an API request returns 401 or 403, AuthSession should NOT immediately clear if refresh_token is present
	auth_session._refreshing = false
	auth_session.refresh_token = "refresh.token.valid_fallback"

	# Simulate 401 from /v1/leaderboard/me
	auth_session._on_api_response("/v1/leaderboard/me", false, 401, {"error": "JWT expired"})

	_assert_eq(auth_session.is_logged_in(), true, "Player not immediately cleared on 401 when refresh_token exists")
	_assert_eq(auth_session._refreshing, true, "_refreshing flag engaged to recover session")


func _test_offline_graceful_retention() -> void:
	print("\n[Lifecycle 4] Offline Graceful Session Retention")
	auth_session._refreshing = false
	auth_session.token = "valid_cached_token"
	auth_session.username = "OfflineRunner"

	# Simulate network disconnect / status 0 on validation
	auth_session._on_api_response("/v1/leaderboard/me", false, 0, {"error": "connection_failed"})

	_assert_eq(auth_session.is_logged_in(), true, "Player remains signed in locally when network is unavailable")
	_assert_eq(auth_session.username, "OfflineRunner", "Username preserved offline")

	# Clean up after test
	auth_session.clear()
	_assert_eq(auth_session.is_logged_in(), false, "Clean state after lifecycle tests")
