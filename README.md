# github-bash-scripts

<!-- prettier-ignore-start -->

[![github-ci](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml)

<!-- prettier-ignore-end -->

Collection of bash helpers for managing GitHub repositories in bulk: listing, auditing and cleaning up Pages, homepages, wikis, projects, descriptions and secrets.

## Features

- 🔎 Nine `find` scripts to audit repositories in bulk: GitHub Pages, homepages (with HTTP status checks), wikis, Projects, branches, LICENSE files, README-only placeholders, missing descriptions and free-text metadata search
- 🧹 Write scripts to clean up in bulk: enable Pages, delete leftover `gh-pages` branches, clear homepages, disable empty wikis and unused Projects
- 🕵️ Secret scanning of the full git history of each repo (`gitleaks` + a grep pattern), with partially redacted reports saved to an owner-only directory
- 🛡️ Safety first: `--dry-run`/`DRY_RUN=1` previews, narrow matching by default with explicit `--force` for anything broader, and hard guards around destructive actions
- ⛓️ Chainable by design: plain URL lists on stdout and in `-o` files feed straight into the next script
- 🚦 CI-friendly exit codes: non-zero on failures, broken homepages and secret findings
- ⚡ Parallel per-repo checks (`CONCURRENCY`), colored columnar TTY output and repo state badges (`[🔐 private]`, `[🍴 fork]`, `[📦 archived]`)
- 🧩 One shared bash library (`shared/`), `shellcheck -x` clean, no dependencies beyond `gh`, `jq`, `curl`, `git` and `gitleaks`

## Repository layout

- [`bin/`](bin/) - the executable scripts (add this directory to `PATH`)
- [`VERSION`](VERSION) - the version reported by every script's `--version`
- [`shared/`](shared/) - libraries sourced by every script: [`__shared.sh`](shared/__shared.sh) (common helpers) and [`__colors.sh`](shared/__colors.sh) (TTY colors)

The scripts locate `shared/` relative to their own path, so keep the clone intact - copying a single file out of `bin/` breaks it.

## Installation

```bash
cd ~/projects

git clone https://github.com/piecioshka/github-bash-scripts.git
cd github-bash-scripts

# Bash: please add to `~/.bash_profile`
export PATH="$HOME/projects/github-bash-scripts/bin/:$PATH"

# Fish: please add to `~/.config/fish/config.fish`
set -gx PATH $HOME/projects/github-bash-scripts/bin/ $PATH

# Authenticate the GitHub CLI once
gh auth login
```

Install the required CLIs if you don't have them yet:

```bash
brew install bash gh jq curl
brew install gitleaks   # only if you plan to use bin/github-scan-secrets
```

## Example usage

### Read / list

```bash
# List repos that have GitHub Pages enabled
# TTY output includes a source badge: [📁 <branch>:<path>] or [⚙️ actions]
github-find-repos-with-pages -u piecioshka
github-find-repos-with-pages -u piecioshka -v public
github-find-repos-with-pages -u piecioshka -v private
github-find-repos-with-pages -u piecioshka -F                       # include forks
github-find-repos-with-pages -u piecioshka -r                       # output repo URLs instead of Pages URLs
github-find-repos-with-pages -u piecioshka -o                       # also save to auto-named file in $PWD
github-find-repos-with-pages -u piecioshka -o my-pages.txt          # also save to a specific file
CONCURRENCY=20 github-find-repos-with-pages -u piecioshka

# List repos with a homepage set and check each URL over HTTP (OK / BROKEN)
github-find-repos-with-homepage -u piecioshka
github-find-repos-with-homepage -u piecioshka -v public
github-find-repos-with-homepage -u piecioshka -F
github-find-repos-with-homepage -u piecioshka -e             # only broken homepages (non-2xx/3xx)
github-find-repos-with-homepage -u piecioshka -e -r          # repo URLs of broken ones (chainable)
github-find-repos-with-homepage -u piecioshka -n             # just list, skip the HTTP check
github-find-repos-with-homepage -u piecioshka -o             # also save to auto-named file in $PWD
github-find-repos-with-homepage -u piecioshka -o broken.txt  # also save to a specific file
CONCURRENCY=20 TIMEOUT=30 github-find-repos-with-homepage -u piecioshka

# List repos that contain only a single README.md file (placeholders)
github-find-repos-with-only-readme -u piecioshka
github-find-repos-with-only-readme -u piecioshka -v public
github-find-repos-with-only-readme -u piecioshka -F
github-find-repos-with-only-readme -u piecioshka -P                # also check GitHub Pages status (green URL / red "pages off")
github-find-repos-with-only-readme -u piecioshka -o                # also save repo URLs to auto-named file
github-find-repos-with-only-readme -u piecioshka -o readme.txt     # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-only-readme -u piecioshka

# List repos that have a given branch (-b is required)
github-find-repos-with-branch -u piecioshka -b gh-pages
github-find-repos-with-branch -u piecioshka -b main
github-find-repos-with-branch -u piecioshka -b develop -v public
github-find-repos-with-branch -u piecioshka -b main -F
github-find-repos-with-branch -u piecioshka -b main -r                # output repo URLs instead of branch URLs
github-find-repos-with-branch -u piecioshka -b main -o                # also save to auto-named file in $PWD
github-find-repos-with-branch -u piecioshka -b main -o branches.txt   # also save to a specific file
CONCURRENCY=20 github-find-repos-with-branch -u piecioshka -b main

# List repos that contain a LICENSE file (LICENSE/LICENCE/COPYING/UNLICENSE)
github-find-repos-with-license -u piecioshka
github-find-repos-with-license -u piecioshka -N                # only Node.js projects (have package.json)
github-find-repos-with-license -u piecioshka -v public
github-find-repos-with-license -u piecioshka -F
github-find-repos-with-license -u piecioshka -o               # also save repo URLs to auto-named file
github-find-repos-with-license -u piecioshka -o licensed.txt  # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-license -u piecioshka

# Search across repo metadata (name, description, homepage, topics, language)
github-find-repos-by-metadata -u piecioshka -q angular
github-find-repos-by-metadata -u piecioshka -q angular -v public
github-find-repos-by-metadata -u piecioshka -q angular -F
github-find-repos-by-metadata -u piecioshka -q TypeScript -c       # case-sensitive
github-find-repos-by-metadata -u piecioshka -q '^workshop-.*2019' -E   # regex
github-find-repos-by-metadata -u piecioshka -q react -o               # also save repo URLs to auto-named file
github-find-repos-by-metadata -u piecioshka -q react -o matches.txt   # also save repo URLs to a specific file

# List repos with the wiki feature enabled, together with their wiki page counts
github-find-repos-with-wiki -u piecioshka
github-find-repos-with-wiki -u piecioshka -v public
github-find-repos-with-wiki -u piecioshka -F
github-find-repos-with-wiki -u piecioshka -e                  # only wikis with no pages (empty)
github-find-repos-with-wiki -u piecioshka -o                  # also save repo URLs to auto-named file
github-find-repos-with-wiki -u piecioshka -o wikis.txt        # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-wiki -u piecioshka

# List repos with the Projects feature enabled, together with linked-project counts
github-find-repos-with-projects-feature -u piecioshka
github-find-repos-with-projects-feature -u piecioshka -v public
github-find-repos-with-projects-feature -u piecioshka -F
github-find-repos-with-projects-feature -u piecioshka -e                  # only repos with no linked projects (unused)
github-find-repos-with-projects-feature -u piecioshka -o                  # also save repo URLs to auto-named file
github-find-repos-with-projects-feature -u piecioshka -o projects.txt     # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-projects-feature -u piecioshka

# List repos that have no description set
github-find-repos-without-description -u piecioshka
github-find-repos-without-description -u piecioshka -v public
github-find-repos-without-description -u piecioshka -F
github-find-repos-without-description -u piecioshka -o                 # also save repo URLs to auto-named file
github-find-repos-without-description -u piecioshka -o no-desc.txt     # also save repo URLs to a specific file
```

### Audit (secrets)

```bash
# Scan git history of each repo with gitleaks + grep pattern (parallel)
# Reports land in ./scan-results (created chmod 700) and are partially
# redacted: gitleaks --redact plus masking of 20+ char token-like strings,
# so SHORT secrets stay readable - treat the reports as sensitive.
# Exit code 2 signals findings, 1 signals scan failures.
github-scan-secrets -u piecioshka
github-scan-secrets -u piecioshka -v public
github-scan-secrets -u piecioshka -F
github-scan-secrets -f repos.txt
github-scan-secrets owner/repo another-owner/repo        # positional slugs
echo "https://github.com/owner/repo" | github-scan-secrets

github-scan-secrets -u piecioshka -g 'my_secret|prod_token'   # custom grep regex
github-scan-secrets -u piecioshka -d /path/to/reports         # custom reports directory
CONCURRENCY=8 github-scan-secrets -u piecioshka
```

### Modify (write operations)

All write operations support `DRY_RUN=1` (or `--dry-run`) to preview changes.

```bash
# Enable GitHub Pages for each repo (source: main / root by default)
github-enable-pages -f repos.txt
cat repos.txt | github-enable-pages
github-enable-pages owner/repo another/repo              # positional slugs
github-enable-pages -f repos.txt -b gh-pages             # custom source branch
github-enable-pages -f repos.txt -b main -p /docs        # custom source path

# Disable GitHub Pages by DELETING the 'gh-pages' branch (destructive!)
# Refuses when the Pages source is another branch, is unknown, or the site
# is built by GitHub Actions (build_type=workflow).
DRY_RUN=1 github-delete-pages-branch -f repos.txt
github-delete-pages-branch -f repos.txt
cat repos.txt | github-delete-pages-branch
github-delete-pages-branch owner/repo another/repo       # positional slugs

# Clear the repo website/homepage URL
github-clear-homepage -u piecioshka                      # only clears *.github.io
github-clear-homepage -u piecioshka -v public
github-clear-homepage -u piecioshka -v private
github-clear-homepage -u piecioshka -F
github-clear-homepage -u piecioshka --force              # clears ANY homepage
github-clear-homepage -f repos.txt
cat repos.txt | github-clear-homepage
github-clear-homepage owner/repo another/repo            # positional slugs
DRY_RUN=1 github-clear-homepage -u piecioshka

# Disable the wiki feature on repos whose wiki is empty (no pages lost)
DRY_RUN=1 github-disable-wiki -u piecioshka
github-disable-wiki -u piecioshka                        # only disables EMPTY wikis
github-disable-wiki -u piecioshka --force                # disable wiki even if it has pages
github-disable-wiki -f empty-wikis.txt
cat empty-wikis.txt | github-disable-wiki
github-disable-wiki owner/repo another/repo              # positional slugs

# Disable the Projects feature on repos with no linked projects
DRY_RUN=1 github-disable-projects-feature -u piecioshka
github-disable-projects-feature -u piecioshka                    # only disables EMPTY projects
github-disable-projects-feature -u piecioshka --force            # disable even if projects exist
github-disable-projects-feature -f empty-proj.txt
github-disable-projects-feature owner/repo another/repo   # positional slugs
```

### Chained workflows

```bash
# 1) Find repos whose homepage is broken, then clear those homepages
#    (-e is essential: without it broken.txt would list EVERY repo with
#    a homepage and the next line would clear all of them)
github-find-repos-with-homepage -u piecioshka -e -r -o broken.txt
github-clear-homepage -f broken.txt --force

# 2) Find repos matching a query, then scan them for secrets
github-find-repos-by-metadata -u piecioshka -q legacy -o legacy.txt
github-scan-secrets -f legacy.txt

# 3) Get all repos with Pages, then disable Pages for a curated subset
github-find-repos-with-pages -u piecioshka -r -o all-pages.txt
# ...edit all-pages.txt to keep only the ones you want disabled...
DRY_RUN=1 github-delete-pages-branch -f all-pages.txt
github-delete-pages-branch -f all-pages.txt

# 4) Find repos with empty wikis, review the list, then disable those wikis
github-find-repos-with-wiki -u piecioshka -e -o empty-wikis.txt
# ...review empty-wikis.txt...
DRY_RUN=1 github-disable-wiki -f empty-wikis.txt
github-disable-wiki -f empty-wikis.txt
```

## Shared conventions

- `-u <username>` - scope to a user's repos (via `gh repo list`, up to 1000 repos)
- `-f <file>` - input file with URLs (one per line; lines starting with `#` are ignored)
- stdin - pipe URLs in
- positional slugs - scripts that consume a repo list also take `owner/repo` args directly (e.g. `github-disable-wiki owner/repo`)
- input priority (scripts that consume a repo list): positional args → `-f <file>` → `-u <username>` → stdin, first available wins; `github-scan-secrets` instead combines positional args, `-f` and `-u`, and falls back to stdin only when those yield nothing
- entries can be repo URLs (`https://github.com/owner/repo`) or bare `owner/repo` slugs; duplicates are collapsed and unrecognized lines are reported as `SKIP`
- `-v public|private|all` - visibility filter (default: `all`)
- `-F/--include-forks` - include forks (default: excluded)
- `-e` - narrow the output to the "problematic" subset: `--only-broken` (homepage) or `--only-unused` (wiki, projects)
- `-r/--repo-url` - output repository URLs instead of the script's default URLs (Pages/branch/homepage)
- `DRY_RUN=1` or `--dry-run` - preview without making changes (all write scripts). Any `DRY_RUN` value other than `0`, `false`, `no`, `off` or empty enables the dry run, so a typo can never run a destructive action for real
- Colored columnar output when writing to a TTY
- Repo state badges on TTY: `[🔐 private]` (yellow), `[🍴 fork]` (blue), `[📦 archived]` (brown) - shown only for non-default states, never written to `-o` output files
- `find` scripts print to stdout by default. Pass `-o <path>` to also save URLs to a specific file, or bare `-o` for an auto-named file (`<name>_YYYY-MM-DD_HH-mm-ss.txt`) in `$PWD`

Run any script with `--help` to see its full usage, or `--version` to print the version (shared across all scripts, from the [`VERSION`](VERSION) file).

### Exit codes

- write scripts (`github-clear-homepage`, `github-enable-pages`, `github-delete-pages-branch`, `github-disable-wiki`, `github-disable-projects-feature`): `0` = no failures, `1` = at least one repo ended in a `FAIL` row
- `github-find-repos-with-homepage`: `0` = all checked homepages OK (or `-n`), `1` = at least one `BROKEN`
- `github-scan-secrets`: `0` = clean, `1` = at least one scan failed (e.g. clone error), `2` = scans succeeded but findings were reported
- other `find` scripts: `0` (inconclusive per-repo checks are reported as `WARN` on stderr)

## Requirements

- `bash` 4.4+ - the macOS system bash (3.2) is NOT enough (the scripts use `mapfile` and empty-array expansion under `set -u`); install a current bash with `brew install bash`, the `#!/usr/bin/env bash` shebang picks it up from `PATH`
- [`gh`](https://cli.github.com/) - authenticated (`gh auth login`); used by every script that talks to the GitHub API. `github-scan-secrets` needs it only for `-u` and for cloning private repos
- `jq` - for `github-find-repos-by-metadata` and `github-scan-secrets`
- `curl` - for `github-find-repos-with-homepage`
- `gitleaks` (`brew install gitleaks`) - for `github-scan-secrets`
- `git` - for `github-scan-secrets` and the wiki scripts (`github-find-repos-with-wiki`, `github-disable-wiki`)

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
shared bash conventions, how to run `shellcheck`, and the PR flow.

## License

[MIT](LICENSE) © 2026 Piotr Kowalski
