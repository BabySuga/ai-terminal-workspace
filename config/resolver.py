#!/usr/bin/env python3
"""
Configuration Resolver and Manager for AI Terminal Workspace (Phase 7)
"""

import sys
import os
import json
import time
import urllib.request
import urllib.error
from pathlib import Path

try:
    import tomllib
except ImportError:
    print("Error: Python 3.11+ is required for tomllib", file=sys.stderr)
    sys.exit(1)

CONFIG_PATH = Path.home() / ".config" / "aiw" / "config.toml"
DEFAULT_ENDPOINT = "http://127.0.0.1:11434"

DEFAULT_CONFIG_TOML = """[ollama]
endpoint = "http://localhost:11434"
timeout = 300

[benchmark]
repeat = 1
prompt = "default"

[ui]
interactive = true
"""

def normalize_endpoint(url):
    if not url:
        return DEFAULT_ENDPOINT
    url = url.strip()
    if not (url.startswith("http://") or url.startswith("https://")):
        url = "http://" + url
    return url.rstrip("/")

def read_config():
    if not CONFIG_PATH.is_file():
        return {}
    try:
        with open(CONFIG_PATH, "rb") as f:
            return tomllib.load(f)
    except Exception:
        return {}

def get_resolved_endpoint(cli_endpoint=None):
    # Priority 1: --endpoint CLI argument
    if cli_endpoint:
        return normalize_endpoint(cli_endpoint)

    # Priority 2: AIW_OLLAMA_ENDPOINT env var
    aiw_env = os.environ.get("AIW_OLLAMA_ENDPOINT", "").strip()
    if aiw_env:
        return normalize_endpoint(aiw_env)

    # Priority 3: OLLAMA_HOST env var
    ollama_env = os.environ.get("OLLAMA_HOST", "").strip()
    if ollama_env:
        return normalize_endpoint(ollama_env)

    # Priority 4: ~/.config/aiw/config.toml
    config_data = read_config()
    toml_endpoint = config_data.get("ollama", {}).get("endpoint", "")
    if isinstance(toml_endpoint, str) and toml_endpoint.strip():
        return normalize_endpoint(toml_endpoint)

    # Priority 5: Default fallback
    return DEFAULT_ENDPOINT

def parse_cli_endpoint(args):
    cli_ep = None
    remaining_args = []
    i = 0
    while i < len(args):
        arg = args[i]
        if arg == "--endpoint" and i + 1 < len(args):
            cli_ep = args[i + 1]
            i += 2
        elif arg.startswith("--endpoint="):
            cli_ep = arg.split("=", 1)[1]
            i += 1
        else:
            remaining_args.append(arg)
            i += 1
    return cli_ep, remaining_args

def cmd_init():
    CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
    with open(CONFIG_PATH, "w", encoding="utf-8") as f:
        f.write(DEFAULT_CONFIG_TOML)
    print(f"Initialized default configuration at {CONFIG_PATH}")

def cmd_show(cli_endpoint=None):
    resolved_endpoint = get_resolved_endpoint(cli_endpoint)
    exists_str = "Exists" if CONFIG_PATH.is_file() else "Not Found"
    cfg_file_val = f"{CONFIG_PATH} ({exists_str})"

    col1_w = 17
    col2_w = max(40, len(cfg_file_val), len(resolved_endpoint))

    print("Configuration Summary")
    print(f"┌{'─' * (col1_w + 2)}┬{'─' * (col2_w + 2)}┐")
    print(f"│ {'Property':<{col1_w}} │ {'Value':<{col2_w}} │")
    print(f"├{'─' * (col1_w + 2)}┼{'─' * (col2_w + 2)}┤")
    print(f"│ {'Config File':<{col1_w}} │ {cfg_file_val:<{col2_w}} │")
    print(f"│ {'Ollama Endpoint':<{col1_w}} │ {resolved_endpoint:<{col2_w}} │")
    print(f"└{'─' * (col1_w + 2)}┴{'─' * (col2_w + 2)}┘")
    print("")

    print("Config File Contents")
    lines = []
    if CONFIG_PATH.is_file():
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                content = f.read().strip()
                if content:
                    lines = content.splitlines()
                else:
                    lines = ["(Empty file)"]
        except Exception as e:
            lines = [f"Error reading file: {e}"]
    else:
        lines = ["(No config file found, using defaults)"]

    max_line_w = max(40, max(len(l) for l in lines)) if lines else 40
    print(f"┌{'─' * (max_line_w + 2)}┐")
    for l in lines:
        print(f"│ {l:<{max_line_w}} │")
    print(f"└{'─' * (max_line_w + 2)}┘")
    print("")

def cmd_test(cli_endpoint=None):
    endpoint = get_resolved_endpoint(cli_endpoint)
    reachability = "Unreachable"
    version = "N/A"
    model_count = "N/A"
    latency_str = "N/A"

    start_time = time.perf_counter()
    try:
        req = urllib.request.Request(f"{endpoint}/api/version")
        with urllib.request.urlopen(req, timeout=5) as resp:
            elapsed = (time.perf_counter() - start_time) * 1000.0
            data = json.loads(resp.read().decode("utf-8"))
            version = data.get("version", "N/A")
            reachability = "Reachable"
            latency_str = f"{round(elapsed)} ms"
    except Exception:
        reachability = "Unreachable"

    if reachability == "Reachable":
        try:
            req_tags = urllib.request.Request(f"{endpoint}/api/tags")
            with urllib.request.urlopen(req_tags, timeout=5) as resp:
                tags_data = json.loads(resp.read().decode("utf-8"))
                models = tags_data.get("models", [])
                model_count = str(len(models))
        except Exception:
            model_count = "N/A"

    print("Configuration Test")
    col1_w = 23
    col2_w = max(30, len(endpoint))

    params = [
        ("Endpoint", endpoint),
        ("Reachability", reachability),
        ("Ollama Version", version),
        ("Installed Model Count", model_count),
        ("Request Latency", latency_str),
    ]

    print(f"┌{'─' * (col1_w + 2)}┬{'─' * (col2_w + 2)}┐")
    print(f"│ {'Parameter':<{col1_w}} │ {'Value':<{col2_w}} │")
    print(f"├{'─' * (col1_w + 2)}┼{'─' * (col2_w + 2)}┤")
    for name, val in params:
        if name in ("Installed Model Count", "Request Latency"):
            print(f"│ {name:<{col1_w}} │ {val:>{col2_w}} │")
        else:
            print(f"│ {name:<{col1_w}} │ {val:<{col2_w}} │")
    print(f"└{'─' * (col1_w + 2)}┴{'─' * (col2_w + 2)}┘")
    print("")

def cmd_set(args):
    if len(args) < 2:
        print("Error: Usage: aiw config set <key> <value>", file=sys.stderr)
        sys.exit(1)

    key = args[0]
    value = args[1]

    if key in ("endpoint", "ollama.endpoint"):
        CONFIG_PATH.parent.mkdir(parents=True, exist_ok=True)
        if not CONFIG_PATH.is_file():
            cmd_init()

        lines = []
        with open(CONFIG_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()

        new_lines = []
        in_ollama = False
        updated = False

        for line in lines:
            stripped = line.strip()
            if stripped.startswith("[") and stripped.endswith("]"):
                if stripped == "[ollama]":
                    in_ollama = True
                else:
                    if in_ollama and not updated:
                        new_lines.append(f'endpoint = "{value}"\n')
                        updated = True
                    in_ollama = False
            elif in_ollama and stripped.startswith("endpoint"):
                new_lines.append(f'endpoint = "{value}"\n')
                updated = True
                continue
            new_lines.append(line)

        if not updated:
            if in_ollama:
                new_lines.append(f'endpoint = "{value}"\n')
            else:
                idx = -1
                for i, l in enumerate(new_lines):
                    if l.strip() == "[ollama]":
                        idx = i
                        break
                if idx != -1:
                    new_lines.insert(idx + 1, f'endpoint = "{value}"\n')
                else:
                    new_lines.append("\n[ollama]\n")
                    new_lines.append(f'endpoint = "{value}"\n')

        with open(CONFIG_PATH, "w", encoding="utf-8") as f:
            f.writelines(new_lines)
        print(f"Updated endpoint to {value} in {CONFIG_PATH}")
    else:
        print(f"Error: Setting '{key}' is not supported yet.", file=sys.stderr)
        sys.exit(1)

def cmd_reset():
    cmd_init()

def main():
    if len(sys.argv) < 2:
        print(get_resolved_endpoint())
        return

    subcmd = sys.argv[1]
    args = sys.argv[2:]

    if subcmd == "get-endpoint":
        cli_ep, _ = parse_cli_endpoint(args)
        print(get_resolved_endpoint(cli_ep))
    elif subcmd == "init":
        cmd_init()
    elif subcmd == "show":
        cli_ep, _ = parse_cli_endpoint(args)
        cmd_show(cli_ep)
    elif subcmd == "test":
        cli_ep, _ = parse_cli_endpoint(args)
        cmd_test(cli_ep)
    elif subcmd == "set":
        cmd_set(args)
    elif subcmd == "reset":
        cmd_reset()
    else:
        print(f"Error: Unknown subcommand '{subcmd}'", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
