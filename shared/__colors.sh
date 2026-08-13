#!/usr/bin/env bash
# Terminal colors (C_* variables), enabled only when stdout is a TTY.
# Sourced by shared/__shared.sh - scripts in bin/ do not source this file
# directly. Variables are exported so parallel workers (xargs + bash -c)
# inherit them.

if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_DIM=$'\033[90m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[94m'
    C_CYAN=$'\033[36m'
    C_BROWN=$'\033[38;5;94m'
else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
    C_BROWN=""
fi

export C_RESET C_BOLD C_DIM C_RED C_GREEN C_YELLOW C_BLUE C_CYAN C_BROWN
