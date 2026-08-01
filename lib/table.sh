#!/usr/bin/env bash
# AI Terminal Workspace - Reusable Box Table Formatting Library (lib/table.sh)
# Pure Bash Implementation - No External Dependencies

# Check if stdout supports ANSI colors
table_supports_color() {
    if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]] && [[ "${TERM:-}" != "dumb" ]]; then
        return 0
    fi
    return 1
}

# Color definitions
if table_supports_color; then
    COLOR_GREEN=$'\033[32m'
    COLOR_RED=$'\033[31m'
    COLOR_YELLOW=$'\033[33m'
    COLOR_CYAN=$'\033[36m'
    COLOR_RESET=$'\033[0m'
else
    COLOR_GREEN=""
    COLOR_RED=""
    COLOR_YELLOW=""
    COLOR_CYAN=""
    COLOR_RESET=""
fi

# Print title line
print_title() {
    if [[ -n "${1:-}" ]]; then
        echo "$1"
    fi
}

# Helper to generate repeated characters in pure bash without subshells
repeat_char() {
    local char="$1"
    local count="$2"
    if (( count <= 0 )); then
        echo ""
        return
    fi
    local pad
    printf -v pad '%*s' "$count" ''
    echo "${pad// /$char}"
}

# Apply color to status indicators without affecting character spacing
colorize_line() {
    local line="$1"
    if ! table_supports_color; then
        echo "${line}"
        return
    fi

    line="${line//✓ OK/${COLOR_GREEN}✓ OK${COLOR_RESET}}"
    line="${line//✓/${COLOR_GREEN}✓${COLOR_RESET}}"
    line="${line// ✗ FAIL / ${COLOR_RED}✗ FAIL${COLOR_RESET} }"
    line="${line//│ ✗ FAIL /│ ${COLOR_RED}✗ FAIL${COLOR_RESET} }"
    line="${line// READY / ${COLOR_GREEN}READY${COLOR_RESET} }"
    line="${line// NOT READY / ${COLOR_RED}NOT READY${COLOR_RESET} }"
    line="${line// Running / ${COLOR_GREEN}Running${COLOR_RESET} }"
    line="${line// Stopped / ${COLOR_RED}Stopped${COLOR_RESET} }"
    line="${line// Reachable / ${COLOR_GREEN}Reachable${COLOR_RESET} }"
    line="${line// Unreachable / ${COLOR_RED}Unreachable${COLOR_RESET} }"
    line="${line// WARNING / ${COLOR_YELLOW}WARNING${COLOR_RESET} }"
    echo "${line}"
}

# Print top border
print_border_top() {
    local -n __top_widths=$1
    local border="┌"
    local i
    for (( i=0; i<${#__top_widths[@]}; i++ )); do
        border+="$(repeat_char "─" $(( __top_widths[i] + 2 )))"
        if (( i < ${#__top_widths[@]} - 1 )); then
            border+="┬"
        else
            border+="┐"
        fi
    done
    echo "${border}"
}

# Print middle / row separator border
print_border_middle() {
    local -n __mid_widths=$1
    local border="├"
    local i
    for (( i=0; i<${#__mid_widths[@]}; i++ )); do
        border+="$(repeat_char "─" $(( __mid_widths[i] + 2 )))"
        if (( i < ${#__mid_widths[@]} - 1 )); then
            border+="┼"
        else
            border+="┤"
        fi
    done
    echo "${border}"
}

# Print bottom border
print_border_bottom() {
    local -n __bot_widths=$1
    local border="└"
    local i
    for (( i=0; i<${#__bot_widths[@]}; i++ )); do
        border+="$(repeat_char "─" $(( __bot_widths[i] + 2 )))"
        if (( i < ${#__bot_widths[@]} - 1 )); then
            border+="┴"
        else
            border+="┘"
        fi
    done
    echo "${border}"
}

# Alias for print_border / print_separator / print_footer
print_border() {
    local type="$1"
    shift
    case "${type}" in
        top) print_border_top "$@" ;;
        middle|sep|separator) print_border_middle "$@" ;;
        bottom|footer) print_border_bottom "$@" ;;
    esac
}

print_header() {
    local -n __hdr_aligns=$1
    local -n __hdr_widths=$2
    local -n __hdr_names=$3

    local line="│"
    local i
    for (( i=0; i<${#__hdr_names[@]}; i++ )); do
        local hdr="${__hdr_names[i]}"
        local w="${__hdr_widths[i]}"
        local align="${__hdr_aligns[i]:-L}"
        local formatted
        if [[ "${align}" == "R" ]]; then
            printf -v formatted "%*s" "${w}" "${hdr}"
        else
            printf -v formatted "%-*s" "${w}" "${hdr}"
        fi
        line+=" ${formatted} │"
    done
    echo "${line}"
}

print_row() {
    local -n __row_aligns=$1
    local -n __row_widths=$2
    local -n __row_cells=$3

    local line="│"
    local i
    for (( i=0; i<${#__row_cells[@]}; i++ )); do
        local val="${__row_cells[i]}"
        local w="${__row_widths[i]}"
        local align="${__row_aligns[i]:-L}"
        local formatted
        if [[ "${align}" == "R" ]]; then
            printf -v formatted "%*s" "${w}" "${val}"
        else
            printf -v formatted "%-*s" "${w}" "${val}"
        fi
        line+=" ${formatted} │"
    done
    colorize_line "${line}"
}

print_separator() {
    print_border_middle "$1"
}

print_footer() {
    print_border_bottom "$1"
}

# Comprehensive N-column table printer
# Options:
#   --title "Title"
#   --row-separators
#   --sep-before-last
#   --no-header
#   --min-widths "w1 w2 ..."
print_table_impl() {
    local title=""
    local row_seps=false
    local sep_before_last=false
    local no_header=false
    local min_widths=()

    local headers_var=""
    local aligns_var=""
    local data_var=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                title="$2"
                shift 2
                ;;
            --row-separators)
                row_seps=true
                shift
                ;;
            --sep-before-last)
                sep_before_last=true
                shift
                ;;
            --no-header)
                no_header=true
                shift
                ;;
            --min-widths)
                read -r -a min_widths <<< "$2"
                shift 2
                ;;
            *)
                if [[ -z "${headers_var}" ]]; then
                    headers_var="$1"
                elif [[ -z "${aligns_var}" ]]; then
                    aligns_var="$1"
                elif [[ -z "${data_var}" ]]; then
                    data_var="$1"
                fi
                shift
                ;;
        esac
    done

    local -n __tbl_headers="${headers_var}" 2>/dev/null || true
    local -n __tbl_aligns="${aligns_var}"
    local -n __tbl_data="${data_var}"

    local num_cols=${#__tbl_aligns[@]}
    if (( num_cols == 0 )); then
        return 0
    fi

    local num_cells=${#__tbl_data[@]}
    local num_rows=$(( num_cells / num_cols ))

    # Calculate column widths
    local widths=()
    local c
    for (( c=0; c<num_cols; c++ )); do
        local max_w=0
        if [[ "${no_header}" != "true" ]] && [[ -n "${headers_var}" ]] && [[ ${#__tbl_headers[@]} -gt c ]]; then
            max_w=${#__tbl_headers[c]}
        fi
        if [[ ${#min_widths[@]} -gt c ]] && (( min_widths[c] > max_w )); then
            max_w=${min_widths[c]}
        fi

        local r
        for (( r=0; r<num_rows; r++ )); do
            local idx=$(( r * num_cols + c ))
            local val="${__tbl_data[idx]}"
            if (( ${#val} > max_w )); then
                max_w=${#val}
            fi
        done
        widths+=( "${max_w}" )
    done

    # Output title
    if [[ -n "${title}" ]]; then
        print_title "${title}"
    fi

    # Output top border
    print_border_top widths

    # Output header if not disabled
    if [[ "${no_header}" != "true" ]] && [[ -n "${headers_var}" ]] && [[ ${#__tbl_headers[@]} -gt 0 ]]; then
        print_header __tbl_aligns widths __tbl_headers
        print_border_middle widths
    fi

    # Output data rows
    local r
    for (( r=0; r<num_rows; r++ )); do
        if (( r > 0 )); then
            if [[ "${row_seps}" == "true" ]]; then
                print_border_middle widths
            elif [[ "${sep_before_last}" == "true" ]] && (( r == num_rows - 1 )); then
                print_border_middle widths
            fi
        fi

        local row_cells=()
        for (( c=0; c<num_cols; c++ )); do
            local idx=$(( r * num_cols + c ))
            row_cells+=( "${__tbl_data[idx]}" )
        done
        print_row __tbl_aligns widths row_cells
    done

    # Output bottom border
    print_border_bottom widths
    echo ""
}

print_table() {
    print_table_impl "$@"
}

# Key-Value 2-column table helper
print_kv_table() {
    local title=""
    local header1="Metric"
    local header2="Value"
    local align2="R"
    local sep_before_last=false
    local no_header=false
    local min_w1=17
    local min_w2=20

    local keys_var=""
    local vals_var=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --title)
                title="$2"
                shift 2
                ;;
            --headers)
                header1="$2"
                header2="$3"
                shift 3
                ;;
            --align2)
                align2="$2"
                shift 2
                ;;
            --sep-before-last)
                sep_before_last=true
                shift
                ;;
            --no-header)
                no_header=true
                shift
                ;;
            --min-width1)
                min_w1="$2"
                shift 2
                ;;
            --min-width2)
                min_w2="$2"
                shift 2
                ;;
            *)
                if [[ -z "${keys_var}" ]]; then
                    keys_var="$1"
                elif [[ -z "${vals_var}" ]]; then
                    vals_var="$1"
                fi
                shift
                ;;
        esac
    done

    local -n __kv_keys="${keys_var}"
    local -n __kv_vals="${vals_var}"

    local headers=("${header1}" "${header2}")
    local aligns=("L" "${align2}")

    local num_rows=${#__kv_keys[@]}
    local w1=${#header1}
    local w2=${#header2}
    if [[ "${no_header}" == "true" ]]; then
        w1=0
        w2=0
    fi
    if (( min_w1 > w1 )); then w1=${min_w1}; fi
    if (( min_w2 > w2 )); then w2=${min_w2}; fi

    local i
    for (( i=0; i<num_rows; i++ )); do
        local k="${__kv_keys[i]}"
        local v="${__kv_vals[i]}"
        if (( ${#k} > w1 )); then w1=${#k}; fi
        if (( ${#v} > w2 )); then w2=${#v}; fi
    done

    local widths=("${w1}" "${w2}")

    if [[ -n "${title}" ]]; then
        print_title "${title}"
    fi

    print_border_top widths

    if [[ "${no_header}" != "true" ]]; then
        print_header aligns widths headers
        print_border_middle widths
    fi

    for (( i=0; i<num_rows; i++ )); do
        if [[ "${sep_before_last}" == "true" ]] && (( i == num_rows - 1 )); then
            print_border_middle widths
        fi

        local k="${__kv_keys[i]}"
        local v="${__kv_vals[i]}"
        local cell_align2="${align2}"

        if [[ "${k}" == "Model" || "${k}" == "Version" || "${k}" == "Config File" || "${k}" == "Ollama Endpoint" || "${k}" == "Endpoint" || "${k}" == "Status" || "${k}" == "Git Commit" || "${k}" == "Build Date" || "${k}" == "Platform" || "${k}" == "Shell" ]]; then
            cell_align2="L"
        fi

        local row_aligns=("L" "${cell_align2}")
        local row_cells=("${k}" "${v}")
        print_row row_aligns widths row_cells
    done

    print_border_bottom widths
    echo ""
}
