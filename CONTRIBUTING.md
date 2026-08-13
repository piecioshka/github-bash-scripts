# Contributing

Thanks for considering a contribution! This repo is a set of bash helpers for
bulk operations on GitHub repos. The bar is small, focused scripts - not a
framework.

## Reporting issues

Open a GitHub issue and include:

- Which script you ran and the full command line
- Output (stdout + stderr) - scrub any tokens or private repo names
- Your OS, `bash --version`, `gh --version`

## Submitting a pull request

1. Fork the repo
2. Create a branch off `main`
3. Make your change and run the verification steps below
4. Open a PR with a short description of the change and why it's needed

Keep PRs focused. One logical change per PR is easier to review than a
bundle.

## Repository layout

- `bin/` - the executable scripts
- `shared/__shared.sh` - common helpers (usage extraction, arg validation,
  row/status printing, badges, slug parsing, input source resolution, the
  gh-token git credential helper); it sources `shared/__colors.sh` itself
- `shared/__colors.sh` - `C_*` color variables, enabled only when stdout is a
  TTY, exported for parallel workers

Every script starts with:

```bash
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=../shared/__shared.sh
source "$script_dir/../shared/__shared.sh"
```

## Bash style & shared conventions

All scripts in `bin/` follow these rules. Match them when editing or adding
scripts.

- Shebang: `#!/usr/bin/env bash`; bash 4.4+ is required (`mapfile`,
  empty-array expansion under `set -u`) - the macOS system bash 3.2 does not
  run these scripts
- `set -u` at the top (fail on unset variables). Avoid `set -e` - we handle
  command failures explicitly with `|| true` where needed
- `shellcheck -x` clean - no warnings on default severity
- Usage block in a comment header at the top, extracted at runtime by the
  shared `show_usage()` (`sed -n '2,/^$/p' "$0" | sed -E 's/^# ?//'`). Running
  the script with `--help` prints that block
- Input sources for scripts that consume a repo list, in priority order:
  positional args → `-f <file>` → `-u <user>` → stdin → show usage and exit if
  none provided (`github-scan-secrets` combines all given sources instead of
  picking the first). The shared `input_source()` implements this order
- Common flags (keep letters consistent repo-wide):
  - `-u, --user <username>` - scope to a user's repos
  - `-f, --file <path>` - input file
  - `-v, --visibility public|private|all` - visibility filter (default: `all`)
  - `-F, --include-forks` - include forks (default: excluded)
  - `-e` - narrow output to the "problematic" subset (`--only-broken`,
    `--only-unused`)
  - `-r, --repo-url` - output repository URLs instead of the default URLs
  - `-o, --output [<path>]` - opt-in: also save results to a file (default:
    stdout only). With `<path>` writes to that exact path; bare `-o` (or
    followed by another flag) generates `<name>_YYYY-MM-DD_HH-mm-ss.txt`
    in `$PWD`
  - `-h, --help` - show usage
- Short-flag registry (one meaning per letter across the whole repo):
  `-b` branch, `-c` case-sensitive, `-d` results dir, `-e` only-problematic,
  `-g` grep pattern, `-n` no-check, `-N` node-only, `-p` Pages source path,
  `-P` check-pages, `-q` query, `-E` regex. Never reuse a taken letter for a
  different meaning in another script
- Write scripts must support `DRY_RUN=1` and `--dry-run` to preview actions.
  Normalize the env var through the shared `normalize_dry_run` - every value
  except an explicit off (`0`, `false`, `no`, `off`, empty) enables dry-run
- Exit codes: write scripts count `FAIL` rows in a `FAILED` counter (keep the
  processing loop in the main shell: `while ... done < <(input_source ...)`,
  not `input_source | while ...`) and exit `1` when any repo failed.
  `github-find-repos-with-homepage` exits `1` on `BROKEN` rows;
  `github-scan-secrets` exits `1` on scan failures and `2` on findings
- `find` scripts print results to stdout only; file output is opt-in via
  `-o [<path>]`. A per-repo check that fails inconclusively (network, auth,
  rate limit) must WARN on stderr and skip - never silently misreport
- Colored columnar output only when stdout is a TTY (handled by
  `shared/__colors.sh`)
- Repo state badges (`[🔐 private]` yellow, `[🍴 fork]` blue, `[📦 archived]`
  brown) come from the shared `format_badges` - appended to TTY output for
  non-default states only, and must never leak into `-o` output files (which
  stay as plain URL lists for chaining)
- Lines in input files starting with `#` are treated as comments and ignored
- Functions and variables used inside parallel workers (`xargs -P ... bash -c`)
  must be exported (`export -f`, `export`); the shared library already exports
  `paint_status`, `print_row`, `format_badges`, `git_authed` and the `C_*`
  colors
- git access with the gh token goes through the shared `git_authed` (token via
  a credential helper reading an env var - never on the command line) with
  `GIT_TERMINAL_PROMPT=0`, so workers can never hang on a credential prompt

## Local verification

Before opening a PR:

```bash
# Lint all scripts and the shared libraries (install: brew install shellcheck)
shellcheck -x bin/* shared/*.sh

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

- `github-delete-pages-branch` only deletes the `gh-pages` branch. It refuses
  any other branch name, an unknown source branch, and Pages built by GitHub
  Actions (`build_type=workflow`) - never turn an absent `.source.branch`
  into a default of `gh-pages`
- Destructive scripts default to narrow matching (e.g. `github-clear-homepage`
  only clears URLs matching `*.github.io`). Broader matching must be opt-in
  via an explicit `--force` flag
- `github-disable-wiki` only disables the wiki feature when the wiki has no
  pages; `github-disable-projects-feature` only when no Projects are linked.
  Each refuses the non-empty case unless `--force` is passed. These
  "empty-only" guards are the load-bearing safety; don't relax them to
  match-anything by default
- `DRY_RUN` must stay fail-safe: anything that is not an explicit off value
  enables the dry run (see `normalize_dry_run`)
- `github-scan-secrets` reports must stay redacted (gitleaks `--redact`, the
  grep matches masked) and the results directory owner-only (`chmod 700`)
