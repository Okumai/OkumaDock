"""Discover portable default pins from this user's desktop entries and defaults."""
import configparser
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess


def read_entries():
    roots = [Path(os.environ.get('XDG_DATA_HOME', str(Path.home() / '.local/share')))]
    roots += [Path(p) for p in os.environ.get('XDG_DATA_DIRS', '/usr/local/share:/usr/share').split(':') if p]
    entries = {}
    for root in roots:
        appdir = root / 'applications'
        if not appdir.is_dir():
            continue
        for path in sorted(appdir.rglob('*.desktop')):
            identifier = str(path.relative_to(appdir)).replace('/', '-')[:-8]
            if identifier in entries:
                continue
            parser = configparser.ConfigParser(interpolation=None, strict=False)
            try:
                parser.read(path, encoding='utf-8')
                data = dict(parser['Desktop Entry'])
                if data.get('hidden', '').lower() == 'true':
                    entries[identifier] = None
                else:
                    entries[identifier] = data
            except (OSError, configparser.Error, KeyError):
                continue
    return {key: value for key, value in entries.items() if value}


def command_output(argv):
    try:
        return subprocess.run(argv, capture_output=True, text=True, timeout=5, check=True).stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ''


def executable(entry):
    try:
        tokens = shlex.split(entry.get('exec', ''))
        if tokens and tokens[0] == 'env':
            tokens = [token for token in tokens[1:] if '=' not in token]
        return Path(tokens[0]).name if tokens else ''
    except ValueError:
        return ''


def make_pin(entries, key, identifier, command=None, aliases=()):
    entry = entries.get(identifier, {})
    classes = [identifier, entry.get('startupwmclass', ''), executable(entry), *aliases]
    pin = dict(key=key, name=entry.get('name', key.title()), desktop=identifier,
               icon=entry.get('icon', 'application-x-executable'),
               classes=list(dict.fromkeys(value.lower() for value in classes if value)))
    if command:
        pin['command'] = command
    return pin


def discover():
    entries = read_entries()
    pins = []
    browser = command_output(['omarchy-cmd-default-browser']).removesuffix('.desktop')
    if not browser:
        browser = command_output(['xdg-settings', 'get', 'default-web-browser']).removesuffix('.desktop')
    if browser == 'omarchy-browser':
        browser = command_output(['xdg-mime', 'query', 'default', 'x-scheme-handler/https']).removesuffix('.desktop')
    if browser in entries:
        pins.append(make_pin(entries, 'browser', browser, ['omarchy', 'launch', 'browser']))
    files = command_output(['xdg-mime', 'query', 'default', 'inode/directory']).removesuffix('.desktop')
    if files not in entries:
        files = next((key for key in ('org.gnome.Nautilus', 'thunar', 'org.kde.dolphin') if key in entries), '')
    if files:
        pins.append(make_pin(entries, 'files', files))
    state = Path(os.environ.get('XDG_STATE_HOME', str(Path.home() / '.local/state')))
    try:
        editor = (state / 'omarchy/defaults/editor').read_text().strip()
    except OSError:
        editor = 'nvim'
    editor_id = next((key for key, value in entries.items() if executable(value) == Path(editor).name), '')
    if editor_id:
        aliases = ['org.omarchy.nvim', 'tui.float'] if editor == 'nvim' else []
        pins.append(make_pin(entries, 'editor', editor_id, ['omarchy', 'launch', 'editor', '.'], aliases))
    pins.append(dict(key='launcher', name='Applications', icon='view-app-grid-symbolic',
                     classes=[], shellPlugin='omarchy.menu', payload={'initialMenu': 'apps'}))
    if shutil.which('dua') and shutil.which('xdg-terminal-exec'):
        pins.append(dict(key='disk', name='Disk Usage', icon='disk-usage', classes=['org.okumarchy.dock.disk-usage'],
                         command=['xdg-terminal-exec', '--app-id=org.okumarchy.dock.disk-usage', '-e', 'dua', 'i', '/']))
    return pins


if __name__ == '__main__':
    print(json.dumps(discover()))
