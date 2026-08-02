#!/usr/bin/env python3
"""
Interactive TUI for AIW Benchmark (Phase 6)
"""

import sys
import json
import curses
import urllib.request
import subprocess
import os

def parse_args():
    cli_ep = None
    args = sys.argv[1:]
    i = 0
    while i < len(args):
        if args[i] == "--endpoint" and i + 1 < len(args):
            cli_ep = args[i + 1]
            i += 2
        elif args[i].startswith("--endpoint="):
            cli_ep = args[i].split("=", 1)[1]
            i += 1
        else:
            i += 1
    return cli_ep

def resolve_endpoint(cli_ep):
    try:
        from pathlib import Path
        sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
        from config.resolver import get_resolved_endpoint
        return get_resolved_endpoint(cli_ep)
    except Exception:
        return cli_ep or "http://127.0.0.1:11434"

def get_ollama_models(endpoint):
    """Retrieve installed Ollama models via API or CLI."""
    try:
        req = urllib.request.Request(f"{endpoint}/api/tags")
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode("utf-8"))
            models = [m["name"] for m in data.get("models", [])]
            if models:
                return models
    except Exception:
        pass

    try:
        out = subprocess.check_output(["ollama", "list"], text=True, stderr=subprocess.DEVNULL)
        lines = out.strip().split("\n")
        models = []
        for line in lines[1:]:
            parts = line.split()
            if parts:
                models.append(parts[0])
        return models
    except Exception:
        pass

    return []

def draw_menu(stdscr, cursor_idx):
    stdscr.erase()
    max_y, max_x = stdscr.getmaxyx()

    lines = [
        "AIW Benchmark",
        "",
        "Choose Benchmark Mode",
        "",
        "> Single Model" if cursor_idx == 0 else "  Single Model",
        "> Multiple Models" if cursor_idx == 1 else "  Multiple Models",
        "> q Quit" if cursor_idx == 2 else "  q Quit",
        "",
        "Arrow Up / Down",
        "Enter Select"
    ]

    for idx, line in enumerate(lines):
        if idx < max_y:
            if idx in (4, 5, 6) and cursor_idx == (idx - 4):
                stdscr.addstr(idx, 0, line[:max_x-1], curses.A_BOLD)
            else:
                stdscr.addstr(idx, 0, line[:max_x-1])
    stdscr.refresh()

def draw_single_model(stdscr, models, cursor_idx):
    stdscr.erase()
    max_y, max_x = stdscr.getmaxyx()

    lines = [
        "Select Model",
        ""
    ]

    for i, m in enumerate(models):
        prefix = "> " if i == cursor_idx else "  "
        lines.append(f"{prefix}{m}")

    lines.extend([
        "",
        "Arrow keys move.",
        "Enter starts benchmark immediately."
    ])

    for idx, line in enumerate(lines):
        if idx < max_y:
            if 2 <= idx < 2 + len(models) and (idx - 2) == cursor_idx:
                stdscr.addstr(idx, 0, line[:max_x-1], curses.A_BOLD)
            else:
                stdscr.addstr(idx, 0, line[:max_x-1])
    stdscr.refresh()

def draw_multiple_models(stdscr, models, checked_set, cursor_idx):
    stdscr.erase()
    max_y, max_x = stdscr.getmaxyx()

    lines = []
    for i, m in enumerate(models):
        mark = "x" if i in checked_set else " "
        lines.append(f"[{mark}] {m}")

    lines.extend([
        "",
        "Controls",
        "Arrow Up / Down",
        "Move cursor",
        "",
        "Space",
        "Toggle selection",
        "",
        "Enter",
        "Start benchmark queue",
        "",
        "q",
        "Quit"
    ])

    for idx, line in enumerate(lines):
        if idx < max_y:
            if 0 <= idx < len(models) and idx == cursor_idx:
                stdscr.addstr(idx, 0, line[:max_x-1], curses.A_REVERSE | curses.A_BOLD)
            else:
                stdscr.addstr(idx, 0, line[:max_x-1])
    stdscr.refresh()

def draw_no_models(stdscr):
    stdscr.erase()
    max_y, max_x = stdscr.getmaxyx()
    lines = [
        "Error: No installed Ollama models found.",
        "Please ensure Ollama is running and models are installed.",
        "",
        "Press any key to exit."
    ]
    for idx, line in enumerate(lines):
        if idx < max_y:
            stdscr.addstr(idx, 0, line[:max_x-1])
    stdscr.refresh()
    stdscr.getch()

def run_tui(stdscr, endpoint):
    try:
        curses.curs_set(0)
    except Exception:
        pass
    models = get_ollama_models(endpoint)

    if not models:
        draw_no_models(stdscr)
        return []

    state = "MENU"
    menu_cursor = 0
    single_cursor = 0
    multi_cursor = 0
    checked_set = set()

    while True:
        if state == "MENU":
            draw_menu(stdscr, menu_cursor)
            ch = stdscr.getch()
            if ch in (curses.KEY_UP, ord('k'), ord('K')):
                menu_cursor = max(0, menu_cursor - 1)
            elif ch in (curses.KEY_DOWN, ord('j'), ord('J')):
                menu_cursor = min(2, menu_cursor + 1)
            elif ch in (ord('q'), ord('Q'), 27):
                return []
            elif ch in (10, 13, curses.KEY_ENTER):
                if menu_cursor == 0:
                    state = "SINGLE_MODEL"
                    single_cursor = 0
                elif menu_cursor == 1:
                    state = "MULTIPLE_MODELS"
                    multi_cursor = 0
                elif menu_cursor == 2:
                    return []

        elif state == "SINGLE_MODEL":
            draw_single_model(stdscr, models, single_cursor)
            ch = stdscr.getch()
            if ch in (curses.KEY_UP, ord('k'), ord('K')):
                single_cursor = max(0, single_cursor - 1)
            elif ch in (curses.KEY_DOWN, ord('j'), ord('J')):
                single_cursor = min(len(models) - 1, single_cursor + 1)
            elif ch in (ord('q'), ord('Q'), 27):
                state = "MENU"
            elif ch in (10, 13, curses.KEY_ENTER):
                return [models[single_cursor]]

        elif state == "MULTIPLE_MODELS":
            draw_multiple_models(stdscr, models, checked_set, multi_cursor)
            ch = stdscr.getch()
            if ch in (curses.KEY_UP, ord('k'), ord('K')):
                multi_cursor = max(0, multi_cursor - 1)
            elif ch in (curses.KEY_DOWN, ord('j'), ord('J')):
                multi_cursor = min(len(models) - 1, multi_cursor + 1)
            elif ch == ord(' '):
                if multi_cursor in checked_set:
                    checked_set.remove(multi_cursor)
                else:
                    checked_set.add(multi_cursor)
            elif ch in (10, 13, curses.KEY_ENTER):
                if checked_set:
                    selected = [models[i] for i in sorted(checked_set)]
                    return selected
            elif ch in (ord('q'), ord('Q'), 27):
                return []

def print_failure_ux(reason):
    sys.stderr.write(
        "Interactive benchmark cannot start.\n\n"
        "Reason\n"
        f"  {reason}\n\n"
        "Possible fixes\n"
        "  - Run in an interactive terminal\n"
        "  - Specify model arguments directly: aiw benchmark <model>\n"
        "  - Run all installed models: aiw benchmark --all\n"
    )

def main():
    cli_ep = parse_args()
    endpoint = resolve_endpoint(cli_ep)

    res = []
    if sys.stdin.isatty() and sys.stdout.isatty():
        try:
            res = curses.wrapper(lambda stdscr: run_tui(stdscr, endpoint))
        except Exception as e:
            print_failure_ux(f"TUI initialization error ({e}).")
            sys.exit(1)
    else:
        try:
            tty_fd = os.open("/dev/tty", os.O_RDWR)
        except Exception as e:
            print_failure_ux(f"No controlling terminal (/dev/tty) available ({e}).")
            sys.exit(1)

        with open(tty_fd, "r+", buffering=1) as tty:
            old_stdin, old_stdout = sys.stdin, sys.stdout
            sys.stdin, sys.stdout = tty, tty
            try:
                res = curses.wrapper(lambda stdscr: run_tui(stdscr, endpoint))
            except Exception as e:
                sys.stdin, sys.stdout = old_stdin, old_stdout
                print_failure_ux(f"TUI initialization error ({e}).")
                sys.exit(1)
            finally:
                sys.stdin, sys.stdout = old_stdin, old_stdout

    print(json.dumps(res))

if __name__ == "__main__":
    main()
