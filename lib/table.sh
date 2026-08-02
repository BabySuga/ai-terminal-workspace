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

# Helper to strip ANSI escape sequences for printable width calculation
strip_ansi() {
    local str="$1"
    local esc=$'\033'
    local pattern="${esc}\[[0-9;]*[a-zA-Z]"
    while [[ "${str}" =~ ${pattern} ]]; do
        str="${str//${BASH_REMATCH[0]}/}"
    done
    echo "${str}"
}

# Apply color to status indicators
colorize_val() {
    local val="$1"
    if ! table_supports_color; then
        echo "${val}"
        return
    fi

    case "${val}" in
        "READY"|"Running"|"Reachable"|"✓ OK"|"✓")
            echo "${COLOR_GREEN}${val}${COLOR_RESET}"
            ;;
        "Failed"|"Stopped"|"Unreachable"|"NOT READY"|"✗ FAIL"|"Error")
            echo "${COLOR_RED}${val}${COLOR_RESET}"
            ;;
        "WARNING"|"Warning"|"WARN"|"Warn"|"Warnings"|"Skipped")
            echo "${COLOR_YELLOW}${val}${COLOR_RESET}"
            ;;
        *)
            echo "${val}"
            ;;
    esac
}

colorize_line() {
    local line="$1"
    echo "${line}"
}

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

        local plain_hdr
        plain_hdr="$(strip_ansi "${hdr}")"
        local vis_w=${#plain_hdr}
        local pad_len=$(( w - vis_w ))
        if (( pad_len < 0 )); then pad_len=0; fi

        local spaces=""
        if (( pad_len > 0 )); then
            printf -v spaces '%*s' "${pad_len}" ''
        fi

        local formatted
        if [[ "${align}" == "R" ]]; then
            formatted="${spaces}${hdr}"
        else
            formatted="${hdr}${spaces}"
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

        local colored_val
        colored_val="$(colorize_val "${val}")"

        local plain_val
        plain_val="$(strip_ansi "${val}")"

        local vis_w=${#plain_val}
        local pad_len=$(( w - vis_w ))
        if (( pad_len < 0 )); then pad_len=0; fi

        local spaces=""
        if (( pad_len > 0 )); then
            printf -v spaces '%*s' "${pad_len}" ''
        fi

        local formatted
        if [[ "${align}" == "R" ]]; then
            formatted="${spaces}${colored_val}"
        else
            formatted="${colored_val}${spaces}"
        fi
        line+=" ${formatted} │"
    done
    echo "${line}"
}

print_separator() {
    print_border_middle "$1"
}

print_footer() {
    print_border_bottom "$1"
}

# Comprehensive N-column table printer
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

    # Calculate column widths using printable character length
    local widths=()
    local c
    for (( c=0; c<num_cols; c++ )); do
        local max_w=0
        if [[ "${no_header}" != "true" ]] && [[ -n "${headers_var}" ]] && [[ ${#__tbl_headers[@]} -gt c ]]; then
            local plain_hdr
            plain_hdr="$(strip_ansi "${__tbl_headers[c]}")"
            max_w=${#plain_hdr}
        fi
        if [[ ${#min_widths[@]} -gt c ]] && (( min_widths[c] > max_w )); then
            max_w=${min_widths[c]}
        fi

        local r
        for (( r=0; r<num_rows; r++ )); do
            local idx=$(( r * num_cols + c ))
            local val="${__tbl_data[idx]}"
            local plain_val
            plain_val="$(strip_ansi "${val}")"
            if (( ${#plain_val} > max_w )); then
                max_w=${#plain_val}
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

    local num_rows=${#__kv_keys[@]}
    local plain_h1
    plain_h1="$(strip_ansi "${header1}")"
    local plain_h2
    plain_h2="$(strip_ansi "${header2}")"

    local w1=${#plain_h1}
    local w2=${#plain_h2}
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
        local plain_k
        plain_k="$(strip_ansi "${k}")"
        local plain_v
        plain_v="$(strip_ansi "${v}")"
        if (( ${#plain_k} > w1 )); then w1=${#plain_k}; fi
        if (( ${#plain_v} > w2 )); then w2=${#plain_v}; fi
    done

    local widths=("${w1}" "${w2}")

    if [[ -n "${title}" ]]; then
        print_title "${title}"
    fi

    print_border_top widths

    if [[ "${no_header}" != "true" ]]; then
        local aligns=("L" "${align2}")
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

        if [[ "${k}" == "Model" || "${k}" == "Start Mode" || "${k}" == "Version" || "${k}" == "Config File" || "${k}" == "Ollama Endpoint" || "${k}" == "Endpoint" || "${k}" == "Status" || "${k}" == "Git Commit" || "${k}" == "Build Date" || "${k}" == "Platform" || "${k}" == "Shell" ]]; then
            cell_align2="L"
        fi

        local row_aligns=("L" "${cell_align2}")
        local row_cells=("${k}" "${v}")
        print_row row_aligns widths row_cells
    done

    print_border_bottom widths
    echo ""
}

