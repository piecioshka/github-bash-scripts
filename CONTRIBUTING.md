# Contributing

Thanks for considering a contribution! This repo is a set of bash helpers for
bulk operations on GitHub repos. The bar is small, focused, well-tested
scripts — not a framework.

## Reporting issues

Open a GitHub issue and include:

- Which script you ran and the full command line
- Output (stdout + stderr) — scrub any tokens or private repo names
- Your OS, `bash --version`, `gh --version`

## Submitting a pull request

1. Fork the repo
2. Create a branch off `main`
3. Make your change and run the verification steps below
4. Open a PR with a short description of the change and why it's needed

Keep PRs focused. One logical change per PR is easier to review than a
bundle.

## Bash style & shared conventions

All scripts in `bin/` follow these rules. Match them when editing or adding
scripts.

- Shebang: `#!/usr/bin/env bash`
- `set -u` at the top (fail on unset variables). Avoid `set -e` — we handle
  command failures explicitly with `|| true` where needed
- `shellcheck` clean — no warnings on default severity
- Usage block in a comment header at the top, extracted at runtime by
  `show_usage()` (`sed -n '2,/^$/p' "$0" | sed -E 's/^# ?//'`). Running the
  script with `--help` prints that block
- Input sources (priority order): `-f <file>` → `-u <user>` → stdin →
  positional args (where supported) → show usage and exit if none provided
- Flags:
  - `-u, --user <username>` — scope to a user's repos
  - `-f, --file <path>` — input file
  - `-v, --visibility public|private|all` — visibility filter (default: `all`)
  - `-F, --include-forks` — include forks (default: excluded)
  - `-o, --output [<path>]` — opt-in: also save results to a file (default:
    stdout only). With `<path>` writes to that exact path; bare `-o` (or
    followed by another flag) generates `<name>_YYYY-MM-DD_HH-mm-ss.<ext>`
    in `$PWD`
  - `-h, --help` — show usage
- Destructive scripts must support `DRY_RUN=1` to preview actions
- `list`/`search` scripts print results to stdout only; file output is opt-in
  via `-o [<path>]`
- Colored columnar output only when stdout is a TTY (check `[[ -t 1 ]]`)
- Repo state badges (`[🔐 private]` yellow, `[🍴 fork]` blue, `[📦 archived]` brown) — appended to TTY output for non-default states only, and must never leak into `-o` output files (which stay as plain URL lists for chaining)
- Lines in input files starting with `#` are treated as comments and ignored

## Local verification

Before opening a PR:

```bash
# Lint all scripts (install shellcheck: brew install shellcheck)
shellcheck bin/*

# Smoke test: every script prints its USAGE for --help
for script in bin/*; do
  "$script" --help > /dev/null && echo "OK: $script" || echo "FAIL: $script"
done
```

Any `--help` smoke test failure is a blocker. Any `shellcheck` warning should
either be fixed or silenced with an inline `# shellcheck disable=SCxxxx`
comment and a rationale.

## Safety rules

Some behaviours are load-bearing safety guards. Do not relax them without a
strong reason and a PR discussion:

- `github-pages-disable` only deletes the `gh-pages` branch. It refuses any
  other branch name (even if the Pages source points there)
- Destructive scripts default to narrow matching (e.g. `github-homepage-clear`
  only clears URLs matching `*.github.io`). Broader matching must be opt-in
  via an explicit `--force` flag
