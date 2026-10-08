import re

with open('scripts/menu.gd', 'r') as f:
    content = f.read()

lines = content.split('\n')
new_lines = []

skip = False
for line in lines:
    if line.startswith('func _show_auth_panel()'):
        skip = True
    elif line.startswith('func _show_leaderboard()'):
        skip = True
    elif line.startswith('func _on_logged_in()'):
        skip = True
    elif line.startswith('func _on_logout()'):
        skip = True
    elif line.startswith('func _on_offline_name_changed('):
        skip = True
    elif line.startswith('func '):
        skip = False

    if skip:
        continue
        
    if any(x in line for x in [
        'var _auth_panel', 'var _leaderboard_panel', 'var _login_btn', 'var _logout_btn', 'var _offline_name_field',
        '_auth_panel =', '_leaderboard_panel =', '_login_btn =', '_logout_btn =', '_offline_name_field =',
        'auth_layer.name =', 'CanvasLayer.new()', 'auth_layer.layer', 'add_child(auth_layer)', 'auth_layer.add_child',
        'res://scripts/auth_panel.gd', 'res://scripts/leaderboard_panel.gd',
        '_auth_panel.', '_leaderboard_panel.', '_login_btn.', '_logout_btn.', '_offline_name_field.',
        '_show_auth_panel', '_show_leaderboard', '_on_logged_in', '_on_logout', 'GuestNickLabel',
        '_on_auth_ready', 'AuthSession.auth_ready', '_offline_name_field', 'username =', 'player_name =', '_menu_name_sign.set_text',
        '_menu_name_label =', '_menu_name_sign.align_left', '_menu_name_sign.gui_input.connect', '_menu_name_sign =', 'add_child(_menu_name_sign)'
    ]):
        # Don't keep lines that instantiate these or refer to them
        continue
        
    new_lines.append(line)

content = '\n'.join(new_lines)

# Also fix the top bar layout since _menu_name_sign is removed
content = content.replace('if _menu_name_sign == null:\n\t\treturn', '')
content = content.replace('_menu_name_sign.visible = show_hud', '')

with open('scripts/menu.gd', 'w') as f:
    f.write(content)
