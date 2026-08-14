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

# show_version - prints "<script name> <version>" and exits. The version lives
# in the repo's VERSION file, so every script reports the same one.
show_version() {
    local version="unknown"
    [[ -r "$__shared_dir/../VERSION" ]] && read -r version < "$__shared_dir/../VERSION"
    echo "$(basename "$0") ${version:-unknown}"
    exit 0
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

# require_value <flag> <value> <what> - exits when a flag's value is missing or
# looks like another flag. Without the second check `-u -F` would silently set
# the username to "-F" and the run would go looking for a user named after a
# flag. Values that legitimately start with a dash can be passed as --flag=-x
# is not supported; use `--` semantics by quoting, e.g. -q ' -x'.
require_value() {
    local flag="$1" value="${2:-}" what="${3:-a value}"
    if [[ -z "$value" ]]; then
        echo "ERROR: $flag requires $what" >&2
        exit 1
    fi
    if [[ "$value" == -* ]]; then
        echo "ERROR: $flag requires $what, got the flag '$value'" >&2
        exit 1
    fi
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

# How many repos `gh repo list` may return. gh silently returns exactly this
# many when a user has more, so warn_if_truncated below reports the cut.
REPO_LIMIT="${REPO_LIMIT:-1000}"

# warn_if_truncated <count> - warns when a listing came back exactly at the
# limit, which is indistinguishable from a listing that was cut short.
warn_if_truncated() {
    [[ "${1:-0}" -ge "$REPO_LIMIT" ]] || return 0
    echo "${C_YELLOW}WARN:${C_RESET} fetched $1 repos, the current REPO_LIMIT - the list may be truncated." >&2
    echo "      Raise it if this user has more, e.g. REPO_LIMIT=5000 $(basename "$0") ..." >&2
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
# Slugs are spliced into privileged API paths (repos/<slug>, DELETE refs), so
# only the characters GitHub allows in owner and repo names get through -
# anything else (query strings, fragments, extra path segments, scp-style git
# URLs, stray protocols) is rejected as unrecognized.
__valid_slug() {
    [[ "$1" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]]
}

url_to_slug() {
    local input="$1" candidate=""
    input="${input#"${input%%[![:space:]]*}"}"
    input="${input%"${input##*[![:space:]]}"}"
    if [[ "$input" =~ ^https?://github\.com/([^/?#]+)/([^/?#]+) ]]; then
        candidate="${BASH_REMATCH[1]}/${BASH_REMATCH[2]%.git}"
    elif [[ "$input" =~ ^https?://([^./]+)\.github\.io/([^/?#]+) ]]; then
        candidate="${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$input" != *://* && "$input" != *@* && "$input" == */* ]]; then
        candidate="${input%.git}"
    fi
    if [[ -n "$candidate" ]] && __valid_slug "$candidate"; then
        echo "$candidate"
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

# Marker file used to signal a `gh repo list` failure out of the process
# substitution that input_source usually runs in (a subshell cannot set a
# variable in its parent). Created empty on failure, checked afterwards by
# input_source_failed.
GH_LIST_FAILED="$(mktemp -u -t gh-list-failed.XXXXXX)"
export GH_LIST_FAILED
# shellcheck disable=SC2064  # expand GH_LIST_FAILED now, not at trap time
trap "rm -f '$GH_LIST_FAILED'" EXIT

# input_source_failed - true when input_source could not list the user's repos.
# Call it after the processing loop so the script can exit non-zero instead of
# reporting a silent, empty run.
input_source_failed() {
    [[ -e "$GH_LIST_FAILED" ]]
}

# validate_input_source - input_source is consumed via a process substitution
# (`while ... done < <(input_source ...)`), where its `exit 1` would die in the
# subshell and the script would still finish with exit 0. Call this in the
# MAIN shell before the loop: it performs the same error checks (missing input
# file, no source at all) where exiting actually terminates the script.
validate_input_source() {
    if [[ -n "$INPUT_FILE" && ! -f "$INPUT_FILE" ]]; then
        echo "ERROR: file does not exist: $INPUT_FILE" >&2
        exit 1
    fi
    if [[ ${#POSITIONAL[@]} -eq 0 && -z "$INPUT_FILE" && -z "$GH_USER" && -t 0 ]]; then
        show_usage
        exit 1
    fi
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
        # A failing `gh repo list` (unknown user, expired auth, rate limit)
        # must not look like "this user has no repos": capture it, then let
        # GH_LIST_FAILED tell the caller (input_source usually runs inside a
        # process substitution, where exiting would be swallowed).
        local listing
        if ! listing=$(gh repo list "$GH_USER" "${vis_args[@]}" --limit "$REPO_LIMIT" \
            --json "$fields" --jq "$jq_filter" 2>&1); then
            echo "ERROR: gh repo list failed for '$GH_USER': $(head -n1 <<< "$listing")" >&2
            : > "$GH_LIST_FAILED"
            return
        fi
        local slug listed=0
        while IFS= read -r slug; do
            [[ -n "$slug" ]] && { echo "https://github.com/$slug"; listed=$((listed + 1)); }
        done <<< "$listing"
        warn_if_truncated "$listed"
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

# normalize_input - filter between input_source and a processing loop. Drops
# blank lines and # comments, and emits one entry per remaining line: repo URLs
# and bare owner/repo slugs alike (both work as positional arguments, so an
# edited -f file or a piped list must accept them too). Unrecognized lines are
# passed through unchanged so the loop can report them as SKIP rather than
# dropping them silently. Duplicates are emitted once - the same repo listed
# twice would otherwise be acted on twice.
normalize_input() {
    local line slug
    while IFS= read -r line; do
        [[ "$line" =~ ^[[:space:]]*(#|$) ]] && continue
        # strip surrounding whitespace and anything after the first space
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%%[[:space:]]*}"
        [[ -z "$line" ]] && continue
        slug=$(url_to_slug "$line")
        if [[ -n "$slug" ]]; then
            echo "https://github.com/$slug"
        else
            echo "$line"
        fi
    done | awk '!seen[$0]++'
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
