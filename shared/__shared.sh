#!/usr/bin/env bash
# Shared helpers for all scripts in bin/. Source it at the top of a script:
#
#   script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
#   source "$script_dir/../shared/__shared.sh"
#
# Sources shared/__colors.sh (C_* variables) on its own. Functions used inside
# parallel workers (xargs + bash -c) are exported at the bottom of this file.

__shared_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=__colors.sh
source "$__shared_dir/__colors.sh"

# Defaults for the common globals, so `set -u` scripts can rely on them before
# flag parsing assigns real values.
GH_USER=""
VISIBILITY="all"
INCLUDE_FORKS=0
INPUT_FILE=""
# shellcheck disable=SC2034  # assigned here, used by the sourcing scripts
OUTPUT_FILE=""
POSITIONAL=()
# shellcheck disable=SC2034  # assigned here, used by the sourcing scripts
FORCE=0

# Prints the usage block: the comment header at the top of the running script
# (lines from 2 up to the first empty line).
show_usage() {
    sed -n '2,/^$/p' "$0" | sed -E 's/^# ?//'
}

# require_cmd <command> [install hint] - exits when the command is missing.
require_cmd() {
    command -v "$1" > /dev/null 2>&1 && return 0
    if [[ -n "${2:-}" ]]; then
        echo "ERROR: $1 not found. Install with: $2" >&2
    else
        echo "ERROR: $1 not found." >&2
    fi
    exit 1
}

# validate_visibility <value> - exits on anything except public/private/all.
validate_visibility() {
    case "$1" in
        public|private|all) ;;
        *) echo "ERROR: invalid visibility '$1' (use: public, private, all)" >&2; exit 1 ;;
    esac
}

# Normalizes the DRY_RUN env var to 0/1. Everything except an explicit "off"
# value enables dry-run, so a typo like DRY_RUN=true can never run a
# destructive action for real.
normalize_dry_run() {
    case "${DRY_RUN:-0}" in
        0|false|no|off|"") DRY_RUN=0 ;;
        *) DRY_RUN=1 ;;
    esac
}

# make_timestamp -> e.g. 2026-08-13_15-44-02 (for auto-named output files).
make_timestamp() {
    date +%Y-%m-%d_%H-%M-%S
}

# paint_status <status> - prints the status padded to 6 chars, colorized on TTY.
paint_status() {
    local status="$1"
    local padded
    printf -v padded "%-6s" "$status"
    case "$status" in
        OK)                  printf "%s%s%s" "$C_GREEN"  "$padded" "$C_RESET" ;;
        DRY|WARN)            printf "%s%s%s" "$C_YELLOW" "$padded" "$C_RESET" ;;
        FAIL|BROKEN)         printf "%s%s%s" "$C_RED"    "$padded" "$C_RESET" ;;
        KEEP|SKIP|NONE|HAVE) printf "%s%s%s" "$C_DIM"    "$padded" "$C_RESET" ;;
        *)                   printf "%s" "$padded" ;;
    esac
}

# print_row <status> <repo> [details] - one result row in the shared layout.
print_row() {
    local status="$1"
    local repo="$2"
    local details="${3:-}"
    printf "%s  %-45s  %s\n" "$(paint_status "$status")" "$repo" "$details"
}

# print_kv <label> <value> - aligned "Label:  value" header line.
print_kv() {
    printf "%s%-12s%s %s\n" "$C_BOLD" "$1:" "$C_RESET" "$2"
}

# url_to_slug <input> -> "owner/repo" (or "" when unrecognized). Accepts:
#   https://github.com/owner/repo[.git][/...]
#   https://owner.github.io/repo[/...]
#   owner/repo[.git]
url_to_slug() {
    local input="$1"
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    if [[ "$input" =~ ^https?://github\.com/([^/]+)/([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
        return
    fi
    if [[ "$input" =~ ^https?://([^./]+)\.github\.io/([^/]+) ]]; then
        echo "${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
        return
    fi
    if [[ "$input" != http*://* && "$input" == */* ]]; then
        echo "${input%.git}"
        return
    fi
    echo ""
}

# format_badges <visibility> <isFork> <isArchived> - repo state badges for TTY
# rows; prints nothing for default states (public, not a fork, not archived).
format_badges() {
    local vis="$1" is_fork="$2" is_archived="$3" badges=""
    [[ "$vis" == "private" ]] && badges="$badges ${C_YELLOW}[🔐 private]${C_RESET}"
    [[ "$is_fork" == "true" ]] && badges="$badges ${C_BLUE}[🍴 fork]${C_RESET}"
    [[ "$is_archived" == "true" ]] && badges="$badges ${C_BROWN}[📦 archived]${C_RESET}"
    printf "%s" "$badges"
}

# input_source [extra_json_fields] [extra_jq_select] [note]
# Emits one repo URL per line, taken from the FIRST available source:
# positional args -> -f file -> -u user (gh repo list) -> stdin.
# Prints the chosen source on stderr; shows usage and exits when none is given.
# extra_json_fields/extra_jq_select narrow the -u listing (e.g. only repos with
# the wiki feature on); note is appended to the stderr source line.
input_source() {
    local extra_fields="${1:-}" extra_select="${2:-}" note="${3:-}"

    if [[ ${#POSITIONAL[@]} -gt 0 ]]; then
        echo "${C_BOLD}Source:${C_RESET} positional arguments" >&2
        local arg
        for arg in "${POSITIONAL[@]}"; do
            if [[ "$arg" == http*://* ]]; then
                echo "$arg"
            else
                echo "https://github.com/${arg%.git}"
            fi
        done
        return
    fi

    if [[ -n "$INPUT_FILE" ]]; then
        if [[ ! -f "$INPUT_FILE" ]]; then
            echo "ERROR: file does not exist: $INPUT_FILE" >&2
            exit 1
        fi
        echo "${C_BOLD}Source:${C_RESET} file $INPUT_FILE" >&2
        cat "$INPUT_FILE"
        return
    fi

    if [[ -n "$GH_USER" ]]; then
        local vis_args=()
        [[ "$VISIBILITY" != "all" ]] && vis_args=(--visibility "$VISIBILITY")
        local fields="nameWithOwner,isFork"
        [[ -n "$extra_fields" ]] && fields="$fields,$extra_fields"
        local jq_filter='.[]'
        [[ -n "$extra_select" ]] && jq_filter="$jq_filter | select($extra_select)"
        [[ "$INCLUDE_FORKS" == "0" ]] && jq_filter="$jq_filter | select(.isFork==false)"
        jq_filter="$jq_filter | .nameWithOwner"

        local fork_note="(forks excluded)"
        [[ "$INCLUDE_FORKS" == "1" ]] && fork_note="(forks included)"
        echo "${C_BOLD}Source:${C_RESET} gh repo list $GH_USER --visibility $VISIBILITY $fork_note${note:+ $note}" >&2
        gh repo list "$GH_USER" "${vis_args[@]}" --limit 1000 \
            --json "$fields" --jq "$jq_filter" \
            | sed 's#^#https://github.com/#'
        return
    fi

    if [[ ! -t 0 ]]; then
        echo "${C_BOLD}Source:${C_RESET} stdin" >&2
        cat
        return
    fi

    show_usage
    exit 1
}

# require_gh_token - reads the gh auth token into GH_HELPER_TOKEN (exported for
# parallel workers) and exits when it is unavailable.
require_gh_token() {
    if ! GH_HELPER_TOKEN="$(gh auth token 2>/dev/null)" || [[ -z "$GH_HELPER_TOKEN" ]]; then
        echo "ERROR: cannot read gh auth token. Run: gh auth login" >&2
        exit 1
    fi
    export GH_HELPER_TOKEN
}

# optional_gh_token - like require_gh_token, but leaves GH_HELPER_TOKEN empty
# when gh is missing or not authenticated (anonymous git access still works
# for public repos).
optional_gh_token() {
    GH_HELPER_TOKEN="$(gh auth token 2>/dev/null || true)"
    export GH_HELPER_TOKEN
}

# git_authed <git args...> - runs git authenticated with GH_HELPER_TOKEN when
# it is set. The token is passed via a credential helper that reads the env
# var - never on the command line (visible in `ps`). GIT_TERMINAL_PROMPT=0
# prevents interactive credential prompts from hanging parallel workers.
git_authed() {
    if [[ -n "${GH_HELPER_TOKEN:-}" ]]; then
        # shellcheck disable=SC2016  # $1/$GH_HELPER_TOKEN must stay literal - git expands them when it runs the helper
        GIT_TERMINAL_PROMPT=0 git -c credential.helper='' \
            -c credential.helper='!f() { test "$1" = get && printf "username=x-access-token\npassword=%s\n" "$GH_HELPER_TOKEN"; }; f' \
            "$@"
    else
        GIT_TERMINAL_PROMPT=0 git "$@"
    fi
}

# Functions used inside parallel workers must be exported (xargs spawns fresh
# bash processes that only see exported functions and variables).
export -f paint_status print_row format_badges git_authed
