"""Build a deterministic application icon index without Qt's theme cache."""
import json
import os
from pathlib import Path

home = Path.home()
roots = [home / '.icons', Path(os.environ.get('XDG_DATA_HOME', str(home / '.local/share'))) / 'icons']
roots += [Path(p) / 'icons' for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p]
roots += [Path('/usr/share/pixmaps')]
index = {}
for root in dict.fromkeys(roots):
    if not root.is_dir():
        continue
    candidates = []
    for directory, _, files in os.walk(root):
        parent = Path(directory)
        if root.name != 'pixmaps' and not {'apps', 'devices', 'actions'}.intersection(parent.parts):
            continue
        for filename in files:
            path = parent / filename
            if path.suffix.lower() not in ('.svg', '.png', '.xpm'):
                continue
            # Standard application icons first, scalable artwork before bitmaps.
            priority = (0 if 'hicolor' in path.parts else 1,
                        0 if 'apps' in path.parts else 1,
                        0 if path.suffix == '.svg' else 1,
                        0 if '256x256' in path.parts else 1, str(path))
            candidates.append((priority, path))
    for _, path in sorted(candidates):
        index.setdefault(path.stem, str(path))
print(json.dumps(index))
