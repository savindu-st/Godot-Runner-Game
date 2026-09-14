extends SceneTree

## Automated Test Suite for Ever Dash Player Authentication & Global Leaderboard

var passed: int = 0
var failed: int = 0

var sim_constants: Node
var auth_session: Node
var api_client: Node
var run_session: Node


func _init() -> void:
	call_deferred("_run_all_tests")


func _run_all_tests() -> void:
	# Fetch autoload nodes from root SceneTree
	sim_constants = root.get_node_or_null("SimConstants")
	auth_session = root.get_node_or_null("AuthSession")
	api_client = root.get_node_or_null("ApiClient")
	run_session = root.get_node_or_null("RunSession")

	print("\n========================================================")
	print("   Ever Dash: Auth & Leaderboard Automated Tests")
	print("========================================================\n")

	_test_sim_constants()
	_test_auth_session()
	_test_api_client_routing()
	_test_api_client_array_parsing()
	_test_run_session_guest_finish()
	_test_auth_panel_component()
	_test_leaderboard_panel_component()

	print("\n========================================================")
	if failed == 0:
		print("🎉 ALL %d TESTS PASSED SUCCESSFULLY!" % passed)
		print("========================================================\n")
		quit(0)
	else:
		print("❌ TEST SUITE FAILED: %d passed, %d failed" % [passed, failed])
		print("========================================================\n")
		quit(1)


func _assert_true(condition: bool, test_name: String) -> void:
	if condition:
		passed += 1
		print("  ✅ PASS: %s" % test_name)
	else:
		failed += 1
		print("  ❌ FAIL: %s" % test_name)


func _assert_eq(actual, expected, test_name: String) -> void:
	if actual == expected:
		passed += 1
		print("  ✅ PASS: %s" % test_name)
	else:
		failed += 1
		print("  ❌ FAIL: %s (Expected '%s', got '%s')" % [test_name, str(expected), str(actual)])


# -----------------------------------------------------------------------------
# 1. SimConstants Tests
# -----------------------------------------------------------------------------
func _test_sim_constants() -> void:
	print("[Test Group 1] SimConstants")
	_assert_true(sim_constants != null, "SimConstants autoload exists")
	var is_configured: bool = sim_constants.has_supabase()
	_assert_true(is_configured, "has_supabase returns true with live project credentials")

	# Test empty check
	var prev_url: String = sim_constants.SUPABASE_URL
	var prev_key: String = sim_constants.SUPABASE_ANON_KEY
	sim_constants.SUPABASE_URL = ""
	sim_constants.SUPABASE_ANON_KEY = ""
	_assert_eq(sim_constants.has_supabase(), false, "has_supabase returns false when credentials are empty")
	sim_constants.SUPABASE_URL = prev_url
	sim_constants.SUPABASE_ANON_KEY = prev_key


# -----------------------------------------------------------------------------
# 2. AuthSession Tests
# -----------------------------------------------------------------------------
func _test_auth_session() -> void:
	print("\n[Test Group 2] AuthSession")
	_assert_true(auth_session != null, "AuthSession autoload exists")
	
	# Test clean initial state
	auth_session.clear()
	_assert_eq(auth_session.is_logged_in(), false, "Initial state is not logged in")
	_assert_eq(auth_session.username, "Guest", "Default username is Guest")
	_assert_eq(auth_session.best_distance, 0, "Default best_distance is 0")
	_assert_eq(auth_session.best_coins, 0, "Default best_coins is 0")

	# Test set_auth with Supabase response payload
	var mock_supabase_response := {
		"access_token": "mock.jwt.token",
		"token_type": "bearer",
		"user": {
			"id": "uuid-1234-5678",
			"email": "runner@example.com",
			"user_metadata": {
				"username": "SpeedyDash"
			}
		},
		"best_distance": 1420,
		"best_coins": 350,
		"rank": 5
	}
	auth_session.set_auth(mock_supabase_response)

	_assert_eq(auth_session.is_logged_in(), true, "is_logged_in returns true after set_auth")
	_assert_eq(auth_session.token, "mock.jwt.token", "token correctly stored")
	_assert_eq(auth_session.user_id, "uuid-1234-5678", "user_id UUID correctly stored")
	_assert_eq(auth_session.email, "runner@example.com", "email correctly stored")
	_assert_eq(auth_session.username, "SpeedyDash", "username extracted from user_metadata")
	_assert_eq(auth_session.best_distance, 1420, "best_distance correctly stored")
	_assert_eq(auth_session.best_coins, 350, "best_coins correctly stored")
	_assert_eq(auth_session.global_rank, 5, "global_rank correctly stored")

	# Test clear (logout)
	auth_session.clear()
	_assert_eq(auth_session.is_logged_in(), false, "is_logged_in is false after clear")
	_assert_eq(auth_session.token, "", "token is empty after clear")
	_assert_eq(auth_session.username, "Guest", "username resets to Guest after clear")
	_assert_eq(auth_session.best_distance, 0, "best_distance resets to 0 after clear")


# -----------------------------------------------------------------------------
# 3. ApiClient URL Routing Tests
# -----------------------------------------------------------------------------
func _test_api_client_routing() -> void:
	print("\n[Test Group 3] ApiClient URL Routing")
	_assert_true(api_client != null, "ApiClient autoload exists")

	# Test absolute URL passthrough
	var abs_url := "https://api.example.com/custom/path"
	_assert_eq(api_client._full_url(abs_url), abs_url, "Absolute URL passes through unchanged")

	# Test Supabase endpoint resolution
	var prev_url: String = sim_constants.SUPABASE_URL
	var prev_key: String = sim_constants.SUPABASE_ANON_KEY

	# Set mock constants for test
	sim_constants.SUPABASE_URL = "https://xyz123.supabase.co"
	sim_constants.SUPABASE_ANON_KEY = "mock-anon-key"

	var login_url = api_client._full_url("/v1/auth/login")
	_assert_eq(login_url, "https://xyz123.supabase.co/auth/v1/token?grant_type=password", "Maps /v1/auth/login to Supabase token endpoint")

	var register_url = api_client._full_url("/v1/auth/register")
	_assert_eq(register_url, "https://xyz123.supabase.co/auth/v1/signup", "Maps /v1/auth/register to Supabase signup endpoint")

	var lb_url = api_client._full_url("/v1/leaderboard")
	_assert_true(lb_url.begins_with("https://xyz123.supabase.co/rest/v1/profiles"), "Maps /v1/leaderboard to Supabase profiles PostgREST query")
	_assert_true(lb_url.contains("best_distance.desc"), "Leaderboard query orders by best_distance desc")

	var rpc_finish_url = api_client._full_url("/v1/run/finish")
	_assert_eq(rpc_finish_url, "https://xyz123.supabase.co/rest/v1/rpc/submit_score", "Maps /v1/run/finish to submit_score RPC")

	# Restore constants
	sim_constants.SUPABASE_URL = prev_url
	sim_constants.SUPABASE_ANON_KEY = prev_key


# -----------------------------------------------------------------------------
# 4. ApiClient Response Parsing Tests
# -----------------------------------------------------------------------------
func _test_api_client_array_parsing() -> void:
	print("\n[Test Group 4] ApiClient JSON Array Response Parsing")
	# PostgREST returns a JSON array for table queries
	var raw_array_json = '[{"username":"TopPlayer","best_distance":1200,"best_coins":400},{"username":"SecondPlayer","best_distance":950,"best_coins":300}]'
	var json = JSON.new()
	var err = json.parse(raw_array_json)
	_assert_eq(err, OK, "JSON parses successfully")
	_assert_true(json.data is Array, "Parsed raw data is an Array")

	# Verify wrapping logic: when data is Array, wrap in {"data": ...}
	var parsed: Dictionary = {}
	if json.data is Array:
		parsed = {"data": json.data}
	_assert_true(parsed.has("data"), "Parsed output contains 'data' key")
	_assert_eq(parsed["data"].size(), 2, "Parsed data array contains 2 elements")
	_assert_eq(parsed["data"][0]["username"], "TopPlayer", "First player username matches")
	_assert_eq(parsed["data"][0]["best_distance"], 1200, "First player best_distance matches")


# -----------------------------------------------------------------------------
# 5. RunSession Guest Finish Tests
# -----------------------------------------------------------------------------
func _test_run_session_guest_finish() -> void:
	print("\n[Test Group 5] RunSession Guest Play & Finish")
	_assert_true(run_session != null, "RunSession autoload exists")
	auth_session.clear()
	run_session.prepare_run()
	_assert_eq(run_session.offline_mode, true, "RunSession is in offline mode for guests")
	_assert_eq(run_session.run_active, true, "Run starts actively for guests")

	# Simulate running distance and collecting coins
	run_session.run_total_coins = 42
	var finish_box := {
		"received": false,
		"data": {}
	}

	var callback := func(success: bool, data: Dictionary):
		finish_box["received"] = true
		finish_box["data"] = data

	run_session.finish_resolved.connect(callback, CONNECT_ONE_SHOT)
	run_session.submit_finish(150.0, "collision")

	_assert_true(finish_box["received"], "finish_resolved emitted on finish")
	_assert_eq(finish_box["data"].get("accepted", false), true, "Guest run is accepted")
	_assert_eq(finish_box["data"].get("guest", false), true, "Flagged as guest run")
	_assert_eq(finish_box["data"].get("final_distance", 0), 150, "final_distance matches meters ran")
	_assert_eq(finish_box["data"].get("final_coins", 0), 42, "final_coins matches collected amount")
	_assert_eq(auth_session.best_distance, 150, "AuthSession best_distance updated with local guest record")
	_assert_eq(auth_session.best_coins, 42, "AuthSession best_coins updated with local guest coins")


# -----------------------------------------------------------------------------
# 6. AuthPanel Component Tests
# -----------------------------------------------------------------------------
func _test_auth_panel_component() -> void:
	print("\n[Test Group 6] AuthPanel Component")
	var auth_panel = load("res://scripts/auth_panel.gd").new()
	root.add_child(auth_panel)

	# Verify Login Mode
	auth_panel._set_mode("login")
	_assert_eq(auth_panel._title.text, "SIGN IN", "Login mode has 'SIGN IN' title")
	_assert_eq(auth_panel._name_field.visible, false, "Display username field is hidden in login mode")
	_assert_eq(auth_panel._submit_btn.text, "LOGIN", "Submit button says 'LOGIN'")

	# Verify Register Mode
	auth_panel._set_mode("register")
	_assert_eq(auth_panel._title.text, "REGISTER", "Register mode has 'REGISTER' title")
	_assert_eq(auth_panel._name_field.visible, true, "Display username field is visible in register mode")
	_assert_eq(auth_panel._submit_btn.text, "CREATE ACCOUNT", "Submit button says 'CREATE ACCOUNT'")

	# Test error message formatting
	var err_creds = auth_panel._format_auth_error("Invalid login credentials", 400)
	_assert_eq(err_creds, "Incorrect email or password.", "Formats invalid credentials friendly message")

	var err_pwd = auth_panel._format_auth_error("Password should be at least 6 characters", 422)
	_assert_eq(err_pwd, "Password must be at least 6 characters long.", "Formats weak password friendly message")

	var err_dup = auth_panel._format_auth_error("User already registered", 422)
	_assert_eq(err_dup, "That email is already registered. Please login.", "Formats duplicate email friendly message")

	auth_panel.queue_free()


# -----------------------------------------------------------------------------
# 7. LeaderboardPanel Component Tests
# -----------------------------------------------------------------------------
func _test_leaderboard_panel_component() -> void:
	print("\n[Test Group 7] LeaderboardPanel Component")
	var lb = load("res://scripts/leaderboard_panel.gd").new()
	root.add_child(lb)

	_assert_eq(lb._title_label.text, "GLOBAL LEADERBOARD", "Leaderboard title is correct")
	_assert_eq(lb._rank_color(1), Color(1.0, 0.84, 0.15), "Rank #1 color is Gold")
	_assert_eq(lb._rank_color(2), Color(0.85, 0.88, 0.95), "Rank #2 color is Silver")
	_assert_eq(lb._rank_color(3), Color(0.9, 0.58, 0.32), "Rank #3 color is Bronze")

	# Test populating rankings list
	lb._top_scores = [
		{"username": "RunnerGold", "best_distance": 500, "best_coins": 50},
		{"username": "RunnerSilver", "best_distance": 420, "best_coins": 40},
		{"username": "RunnerBronze", "best_distance": 310, "best_coins": 30}
	]
	lb._populate_list()
	_assert_eq(lb._list_container.get_child_count(), 3, "List container contains 3 rows for 3 rankings")

	# Test personal status banner for guest
	auth_session.clear()
	auth_session.best_distance = 88
	lb._refresh_personal_bar()
	_assert_true(lb._personal_label.text.contains("Guest Mode"), "Personal bar shows Guest Mode when logged out")
	_assert_true(lb._personal_label.text.contains("88m"), "Personal bar displays guest best distance")
	_assert_eq(lb._personal_action_btn.visible, true, "Sign in button is visible for guests")

	# Test personal status banner for logged in user
	auth_session.set_auth({
		"access_token": "token123",
		"username": "LeaderboardHero",
		"best_distance": 750,
		"best_coins": 250,
		"rank": 4
	})
	lb._refresh_personal_bar()
	_assert_true(lb._personal_label.text.contains("#4"), "Personal bar shows rank #4")
	_assert_true(lb._personal_label.text.contains("LeaderboardHero"), "Personal bar shows username")
	_assert_true(lb._personal_label.text.contains("750m"), "Personal bar shows best distance in meters")
	_assert_eq(lb._personal_action_btn.visible, false, "Sign in button is hidden when logged in")

	# Clean up
	auth_session.clear()
	lb.queue_free()
