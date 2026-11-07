#!/usr/bin/env python3
"""Choose a live Applications panel at click time, not at shell startup."""
import argparse
import subprocess
import sys
import time

LAUNCHPAD = "okuma.dev_launchpad4omarchy"
MENU = "omarchy.menu"


def ipc(*args):
    result = subprocess.run(["omarchy-shell", "shell", *args],
                            capture_output=True, text=True, timeout=10)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or "Omarchy shell IPC failed")
    return result.stdout.strip()


def activate(plugin="auto"):
    if plugin in {"auto", LAUNCHPAD}:
        before = ipc("call", LAUNCHPAD, "status", "")
        if before in {"open", "closed"}:
            ipc("toggle", LAUNCHPAD, "{}")
            expected = "closed" if before == "open" else "open"
            for _ in range(10):
                if ipc("call", LAUNCHPAD, "status", "") == expected:
                    return LAUNCHPAD
                time.sleep(0.1)
            raise RuntimeError("Launchpad did not change state; inspect its plugin logs")
        if plugin != "auto":
            raise RuntimeError("Launchpad is not loaded/enabled; run its installer or doctor.py")
    # summon returns a result, whereas the shell's toggle method returns void.
    if ipc("summon", MENU, '{"initialMenu":"apps"}') != "ok":
        raise RuntimeError("The Omarchy Applications menu is unavailable")
    return MENU


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--plugin", choices=["auto", LAUNCHPAD, MENU], default="auto")
    args = parser.parse_args()
    try:
        print(activate(args.plugin))
    except (OSError, RuntimeError, subprocess.SubprocessError) as error:
        message = f"Cannot open Applications: {error}"
        print(message, file=sys.stderr)
        try:
            subprocess.run(["notify-send", "OkumarchyDock", message], timeout=5, check=False)
        except (OSError, subprocess.SubprocessError):
            pass
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
