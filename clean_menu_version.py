import re

with open('scripts/menu.gd', 'r') as f:
    content = f.read()

# Remove lines with VersionCheck
lines = content.split('\n')
new_lines = [line for line in lines if 'VersionCheck' not in line and 'func _on_update_required' not in line]

content = '\n'.join(new_lines)

with open('scripts/menu.gd', 'w') as f:
    f.write(content)
