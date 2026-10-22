import os
import re

backend_dir = r'C:\Users\hp\Downloads\SkillSense_backend'
legacy_flash_models = re.compile(r'gemini-2[.]5-flash(?:-lite)?')
new_model = 'gemini-3.5-flash-lite'

patched = False
for root, dirs, files in os.walk(backend_dir):
    if 'venv' in root:
        continue
    for file in files:
        if file.endswith('.py'):
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            if legacy_flash_models.search(content):
                content = legacy_flash_models.sub(new_model, content)
                with open(filepath, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"Patched {filepath}")
                patched = True

if not patched:
    print("No files needed patching.")
