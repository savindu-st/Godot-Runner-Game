extends SceneTree

func _init() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	print("Running standup animation test...")
	
	var game_settings = root.get_node("GameSettings")
	game_settings.selected_character_index = 0
	var player_scene = load("res://scenes/player/player_scene.tscn")
	var player = player_scene.instantiate()
	root.add_child(player)
	
	for i in range(20):
		if player.is_character_ready():
			break
		await process_frame
		
	assert(player.is_character_ready(), "Player character should be ready")
	print("Leonard player character ready!")
	print("Leonard stand_anim: ", player.stand_anim)
	assert(player.stand_anim != "", "stand_anim must not be empty")
	assert("standup" in player.stand_anim, "stand_anim should contain 'standup'")
	
	# Check attract mode
	player._enter_attract_mode()
	assert(not player.anim_player.is_playing(), "AnimationPlayer should be paused at frame 0 in attract mode")
	assert(not player.game_started, "game_started should be false")
	assert(not player._countdown_running, "_countdown_running should be false")
	
	# Test countdown start
	player._on_start_pressed()
	assert(player._countdown_running, "Countdown should be running")
	assert(player.anim_player.is_playing(), "AnimationPlayer should be playing standup during countdown")
	assert(player.anim_player.current_animation == player.stand_anim, "Current anim should be standup")
	print("Leonard playing anim: ", player.anim_player.current_animation)
	
	# Wait for countdown completion
	await create_timer(3.4).timeout
	assert(player.game_started, "game_started should be true after countdown")
	assert(player.anim_player.current_animation == player.run_anim, "Current anim should be run after countdown")
	print("Leonard transitioned to run successfully!")
	player.queue_free()
	await process_frame
	
	# 2. Test Remy (character index 1)
	print("\nTesting Remy character...")
	game_settings.selected_character_index = 1
	var remy_player = player_scene.instantiate()
	root.add_child(remy_player)
	
	for i in range(20):
		if remy_player.is_character_ready():
			break
		await process_frame
		
	assert(remy_player.is_character_ready(), "Remy player character should be ready")
	print("Remy player character ready!")
	print("Remy stand_anim: ", remy_player.stand_anim)
	assert(remy_player.stand_anim != "", "Remy stand_anim must not be empty")
	assert("standup" in remy_player.stand_anim, "Remy stand_anim should contain 'standup'")
	
	remy_player._enter_attract_mode()
	assert(not remy_player.anim_player.is_playing(), "Remy AnimationPlayer should be paused at frame 0 in attract mode")
	
	remy_player._on_start_pressed()
	assert(remy_player._countdown_running, "Remy countdown should be running")
	assert(remy_player.anim_player.is_playing(), "Remy AnimationPlayer should be playing standup during countdown")
	print("Remy playing anim: ", remy_player.anim_player.current_animation)
	
	await create_timer(3.4).timeout
	assert(remy_player.game_started, "Remy game_started should be true after countdown")
	assert(remy_player.anim_player.current_animation == remy_player.run_anim, "Remy current anim should be run after countdown")
	print("Remy transitioned to run successfully!")
	remy_player.queue_free()
	
	# Reset character setting
	game_settings.selected_character_index = 0
	
	print("\n🎉 ALL STANDUP ANIMATION TESTS (LEONARD & REMY) PASSED!")
	quit(0)
