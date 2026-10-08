import re

with open('scripts/player_script.gd', 'r') as f:
    content = f.read()

# Replace sessions
content = content.replace('AuthSession', 'SaveManager')
content = content.replace('RunSession', 'RunManager')

# Remove all MoveLog lines
content = re.sub(r'^\s*MoveLog\..*$\n', '', content, flags=re.MULTILINE)

# Remove _auth_panel and _leaderboard_panel variables
content = re.sub(r'^\s*var _auth_panel.*$\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*var _leaderboard_panel.*$\n', '', content, flags=re.MULTILINE)

# Remove the auth panel instantiation block
content = re.sub(r'\s*_auth_panel = load\("res://scripts/auth_panel\.gd"\)\.new\(\)\n\s*_hud_layer\.add_child\(_auth_panel\)\n\s*_auth_panel\.logged_in\.connect\(func\(\):\n\s*_finish_ui_finalized = false\n\s*if coin_count > 0 and SimConstants\.has_supabase\(\):\n\s*ApiClient\.post_with_jwt\("/v1/run/finish", \{\n\s*"p_coins": coin_count,\n\s*"p_duration_sec": 60\.0,\n\s*\}\)\n\s*_trigger_game_over\(\)\n\s*\)', '', content)

# Remove the leaderboard panel instantiation block
content = re.sub(r'\s*_leaderboard_panel = load\("res://scripts/leaderboard_panel\.gd"\)\.new\(\)\n\s*_hud_layer\.add_child\(_leaderboard_panel\)\n\s*_leaderboard_panel\.request_open_auth\.connect\(func\(\):\n\s*if _auth_panel:\n\s*_auth_panel\.open\(\)\n\s*\)', '', content)

# Remove guest/name labels
content = re.sub(r'^\s*var _name_label: Label$\n', '', content, flags=re.MULTILINE)
content = re.sub(r'^\s*var _name_sign: HudSign$\n', '', content, flags=re.MULTILINE)

content = re.sub(r'\s*_name_sign = HudSign\.create_sign\(HudSign\.SignType\.PLAYER, "Guest"\)\n\s*_hud_layer\.add_child\(_name_sign\)\n\s*_name_label = _name_sign\.label\n', '', content)

# Remove leaderboard button from UI if exists
content = re.sub(r'^\s*var _lb_btn: Button$\n', '', content, flags=re.MULTILINE)

content = re.sub(r'\s*if _name_sign:\n\s*_name_sign\.align_left\(pad_left \+ menu_size \+ 10\.0, pad_top \+ 2\.0\)\n\s*elif _name_label:\n\s*_name_label\.position = Vector2\(pad_left, pad_top \+ menu_size \+ 10\.0\)', '', content)

content = re.sub(r'\s*if _name_sign: _name_sign\.visible = show_hud\n', '\n', content)
content = re.sub(r'\s*if _name_label and not _name_sign: _name_label\.visible = show_hud\n', '\n', content)

content = re.sub(r'\s*if _name_sign:\n\s*_name_sign\.set_text\(player_name\)\n\s*_name_sign\.align_left\(pad_left \+ 48\.0 \+ 10\.0, 24\.0\)\n\s*elif _name_label:\n\s*_name_label\.text = player_name\n', '', content)

with open('scripts/player_script.gd', 'w') as f:
    f.write(content)
