import re

with open('scripts/player_script.gd', 'r') as f:
    content = f.read()

lines = content.split('\n')
new_lines = []

skip = False
for line in lines:
    # Skip block creating claim and lb buttons
    if line.startswith('\t_claim_btn = Button.new()'):
        skip = True
    if line.startswith('\t_play_again_btn = Button.new()'):
        skip = False

    if skip:
        continue
        
    if any(x in line for x in [
        'var _claim_btn: Button',
        'var _lb_btn: Button',
        'if _claim_btn:',
        '_claim_btn.visible = false',
        '_claim_btn.visible = true',
        'if SaveManager.is_logged_in():'
    ]):
        continue
    new_lines.append(line)

content = '\n'.join(new_lines)

# Also there was a block for claim_btn under `if SaveManager.is_logged_in():`.
# Because I removed `if SaveManager.is_logged_in():`, the `else:` block below it might remain.
# Let's clean that up too.

content = re.sub(r'^\s*else:\n\s*if _lb_btn:\n\s*_lb_btn\.visible = false\n\s*if _claim_btn:\n\s*_claim_btn\.visible = true\n', '', content, flags=re.MULTILINE)

with open('scripts/player_script.gd', 'w') as f:
    f.write(content)
