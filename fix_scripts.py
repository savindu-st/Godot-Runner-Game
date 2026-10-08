import os
import re

files_to_fix = [
    'scripts/level.gd',
    'scripts/player_script.gd',
    'scripts/menu.gd'
]

for file_path in files_to_fix:
    with open(file_path, 'r') as f:
        content = f.read()

    # Replace AuthSession with SaveManager
    content = content.replace('AuthSession', 'SaveManager')
    # Replace RunSession with RunManager
    content = content.replace('RunSession', 'RunManager')

    # Remove all MoveLog lines
    content = re.sub(r'^\s*MoveLog\..*$\n', '', content, flags=re.MULTILINE)
    
    # In level.gd, remove specific secure spawns block and checkpoints
    if 'level.gd' in file_path:
        # Just simple remove connections to checkpoint_resolved
        content = re.sub(r'^\s*if not RunManager\.checkpoint_resolved\.is_connected.*?$\n\s*RunManager\.checkpoint_resolved\.connect.*?$\n', '', content, flags=re.MULTILINE)
        content = re.sub(r'^\s*RunManager\.ensure_segment_for_level.*?$\n', '', content, flags=re.MULTILINE)
        content = re.sub(r'^\s*RunManager\.apply_next_segment.*?$\n', '', content, flags=re.MULTILINE)
        content = re.sub(r'^\s*RunManager\.submit_checkpoint.*?$\n', '', content, flags=re.MULTILINE)
        
    with open(file_path, 'w') as f:
        f.write(content)

print("Fixed scripts")
