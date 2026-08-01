#!/usr/bin/env bash
# Module: summary.sh - Format and display doctor status output

print_summary() {
    local -n _names=$1
    local -n _statuses=$2
    local -n _missing=$3

    python3 - "${#_missing[@]}" "${_names[@]}" "---STATUSES---" "${_statuses[@]}" << 'PYEOF'
import sys

missing_count = int(sys.argv[1])
args = sys.argv[2:]

sep_idx = args.index("---STATUSES---")
names = args[:sep_idx]
statuses = [int(x) for x in args[sep_idx + 1:]]

col1_w = 25
col2_w = 12

top_border  = f"┌{'─' * (col1_w + 2)}┬{'─' * (col2_w + 2)}┐"
header_line = f"│ {'Component':<{col1_w}} │ {'Status':<{col2_w}} │"
mid_border  = f"├{'─' * (col1_w + 2)}┼{'─' * (col2_w + 2)}┤"
bot_border  = f"└{'─' * (col1_w + 2)}┴{'─' * (col2_w + 2)}┘"

print(top_border)
print(header_line)
print(mid_border)

for name, status in zip(names, statuses):
    st_str = "✓ OK" if status == 0 else "✗ FAIL"
    print(f"│ {name:<{col1_w}} │ {st_str:<{col2_w}} │")

print(mid_border)
sys_status = "READY" if missing_count == 0 else "NOT READY"
print(f"│ {'System Status':<{col1_w}} │ {sys_status:<{col2_w}} │")
print(bot_border)
print("")
PYEOF
}
