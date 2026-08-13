# github-bash-scripts

[![github-ci](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml)

Collection of bash helpers for managing GitHub repositories in bulk: listing, auditing and cleaning up Pages, homepages, wikis, projects, descriptions and secrets.

All scripts live in [`bin/`](bin/). Most share the same conventions:

- `-u <username>` — scope to a user's repos (via `gh repo list`)
- `-f <file>` — input file with URLs (one per line; lines starting with `#` are ignored)
- stdin — pipe URLs in
- `-v public|private|all` — visibility filter (where applicable)
- `-F/--include-forks` — include forks (default: excluded)
- `DRY_RUN=1` — preview without making changes (for destructive actions)
- Colored columnar output when writing to a TTY
- Repo state badges on TTY: `[🔐 private]` (yellow), `[🍴 fork]` (blue), `[📦 archived]` (brown) — shown only for non-default states, never written to `-o` output files
- `list`/`search` scripts print to stdout by default. Pass `-o <path>` to also save URLs to a specific file, or bare `-o` for an auto-named file (`<name>_YYYY-MM-DD_HH-mm-ss.txt`) in `$PWD`

Run any script with `--help` to see its full usage.

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
brew install gh jq curl
brew install gitleaks   # only if you plan to use bin/github-scan-secrets
```

## Example usage

### Read / list

```bash
# List repos that have GitHub Pages enabled
# TTY output includes a source badge: [📁 <branch>:<path>] or [⚙️ actions]
github-list-pages -u piecioshka
github-list-pages -u piecioshka -v public
github-list-pages -u piecioshka -v private
github-list-pages -u piecioshka -F                       # include forks
github-list-pages -u piecioshka -r                       # output repo URLs instead of Pages URLs
github-list-pages -u piecioshka -o                       # also save to auto-named file in $PWD
github-list-pages -u piecioshka -o my-pages.txt          # also save to a specific file
CONCURRENCY=20 github-list-pages -u piecioshka

# List repos that have a non-empty website/homepage set
github-list-homepages -u piecioshka
github-list-homepages -u piecioshka -v public
github-list-homepages -u piecioshka -v private
github-list-homepages -u piecioshka -F
github-list-homepages -u piecioshka -r                    # output repo URLs
github-list-homepages -u piecioshka -o                    # also save to auto-named file in $PWD
github-list-homepages -u piecioshka -o my-homepages.txt   # also save to a specific file

# List repos whose homepage URL is broken (non-2xx/3xx)
github-find-repos-with-broken-homepages -u piecioshka
github-find-repos-with-broken-homepages -u piecioshka -v public
github-find-repos-with-broken-homepages -u piecioshka -F
github-find-repos-with-broken-homepages -u piecioshka -r             # output repo URLs (chainable)
github-find-repos-with-broken-homepages -u piecioshka -b             # print only broken links
github-find-repos-with-broken-homepages -u piecioshka -o             # also save to auto-named file in $PWD
github-find-repos-with-broken-homepages -u piecioshka -o broken.txt  # also save to a specific file
CONCURRENCY=20 TIMEOUT=30 github-find-repos-with-broken-homepages -u piecioshka

# List repos that contain only a single README.md file (placeholders)
github-find-repos-with-only-readme -u piecioshka
github-find-repos-with-only-readme -u piecioshka -v public
github-find-repos-with-only-readme -u piecioshka -F
github-find-repos-with-only-readme -u piecioshka -o                # also save repo URLs to auto-named file
github-find-repos-with-only-readme -u piecioshka -o readme.txt     # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-only-readme -u piecioshka

# List repos that have a given branch (default: gh-pages)
github-find-repos-with-branch -u piecioshka
github-find-repos-with-branch -u piecioshka -b main
github-find-repos-with-branch -u piecioshka -b develop -v public
github-find-repos-with-branch -u piecioshka -F
github-find-repos-with-branch -u piecioshka -r                # output repo URLs instead of branch URLs
github-find-repos-with-branch -u piecioshka -o                # also save to auto-named file in $PWD
github-find-repos-with-branch -u piecioshka -o branches.txt   # also save to a specific file
CONCURRENCY=20 github-find-repos-with-branch -u piecioshka

# List repos that contain a LICENSE file (LICENSE/LICENCE/COPYING/UNLICENSE)
github-find-repos-with-license -u piecioshka
github-find-repos-with-license -u piecioshka -n                # only Node.js projects (have package.json)
github-find-repos-with-license -u piecioshka -v public
github-find-repos-with-license -u piecioshka -F
github-find-repos-with-license -u piecioshka -o               # also save repo URLs to auto-named file
github-find-repos-with-license -u piecioshka -o licensed.txt  # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-license -u piecioshka

# Search across repo metadata (name, description, homepage, topics, language)
github-find-user-repos -u piecioshka -q angular
github-find-user-repos -u piecioshka -q angular -v public
github-find-user-repos -u piecioshka -q angular -F
github-find-user-repos -u piecioshka -q TypeScript -c       # case-sensitive
github-find-user-repos -u piecioshka -q '^workshop-.*2019' -E   # regex
github-find-user-repos -u piecioshka -q react -o               # also save repo URLs to auto-named file
github-find-user-repos -u piecioshka -q react -o matches.txt   # also save repo URLs to a specific file

# List repos whose wiki feature is enabled but has no pages (empty wiki)
github-find-repos-with-empty-wikis -u piecioshka
github-find-repos-with-empty-wikis -u piecioshka -v public
github-find-repos-with-empty-wikis -u piecioshka -F
github-find-repos-with-empty-wikis -u piecioshka -o                  # also save repo URLs to auto-named file
github-find-repos-with-empty-wikis -u piecioshka -o empty-wikis.txt  # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-empty-wikis -u piecioshka

# List repos whose Projects feature is enabled but have no linked projects (empty)
github-find-repos-with-unused-projects-feature -u piecioshka
github-find-repos-with-unused-projects-feature -u piecioshka -v public
github-find-repos-with-unused-projects-feature -u piecioshka -F
github-find-repos-with-unused-projects-feature -u piecioshka -o                  # also save repo URLs to auto-named file
github-find-repos-with-unused-projects-feature -u piecioshka -o empty-proj.txt   # also save repo URLs to a specific file
CONCURRENCY=20 github-find-repos-with-unused-projects-feature -u piecioshka

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
github-scan-secrets -u piecioshka
github-scan-secrets -u piecioshka -v public
github-scan-secrets -u piecioshka -F
github-scan-secrets -f repos.txt
github-scan-secrets owner/repo another-owner/repo        # positional slugs
echo "https://github.com/owner/repo" | github-scan-secrets

# Env overrides
CONCURRENCY=8 github-scan-secrets -u piecioshka
GREP_PATTERN="my_secret|prod_token" github-scan-secrets -u piecioshka
RESULTS_DIR=/tmp/reports github-scan-secrets -u piecioshka
```

### Modify (write operations)

All destructive operations support `DRY_RUN=1` to preview changes.

```bash
# Enable GitHub Pages for each repo (source: main / root by default)
github-enable-pages repos.txt
cat repos.txt | github-enable-pages
BRANCH=gh-pages github-enable-pages repos.txt
BRANCH=main PATH_IN_REPO=/docs github-enable-pages repos.txt

# Disable GitHub Pages (deletes the 'gh-pages' branch; refuses other branches)
DRY_RUN=1 github-disable-pages -f repos.txt
github-disable-pages -f repos.txt
cat repos.txt | github-disable-pages

# Clear the repo website/homepage URL
github-clear-homepages -u piecioshka                      # only clears *.github.io
github-clear-homepages -u piecioshka -v public
github-clear-homepages -u piecioshka -v private
github-clear-homepages -u piecioshka -F
github-clear-homepages -u piecioshka --force              # clears ANY homepage
github-clear-homepages -f repos.txt
cat repos.txt | github-clear-homepages
DRY_RUN=1 github-clear-homepages -u piecioshka

# Disable the wiki feature on repos whose wiki is empty (no pages lost)
DRY_RUN=1 github-disable-wikis -u piecioshka
github-disable-wikis -u piecioshka                        # only disables EMPTY wikis
github-disable-wikis -u piecioshka --force                # disable wiki even if it has pages
github-disable-wikis -f empty-wikis.txt
cat empty-wikis.txt | github-disable-wikis

# Disable the Projects feature on repos with no linked projects
DRY_RUN=1 github-disable-projects-feature -u piecioshka
github-disable-projects-feature -u piecioshka                    # only disables EMPTY projects
github-disable-projects-feature -u piecioshka --force            # disable even if projects exist
github-disable-projects-feature -f empty-proj.txt
```

### Chained workflows

```bash
# 1) Find repos whose homepage is broken, then clear those homepages
github-find-repos-with-broken-homepages -u piecioshka -r -o broken.txt
github-clear-homepages -f broken.txt --force

# 2) Find repos matching a query, then scan them for secrets
github-find-user-repos -u piecioshka -q legacy -o legacy.txt
github-scan-secrets -f legacy.txt

# 3) Get all repos with Pages, then disable Pages for a curated subset
github-list-pages -u piecioshka -r -o all-pages.txt
# ...edit all-pages.txt to keep only the ones you want disabled...
DRY_RUN=1 github-disable-pages -f all-pages.txt
github-disable-pages -f all-pages.txt

# 4) Find repos with empty wikis, review the list, then disable those wikis
github-find-repos-with-empty-wikis -u piecioshka -o empty-wikis.txt
# ...review empty-wikis.txt...
DRY_RUN=1 github-disable-wikis -f empty-wikis.txt
github-disable-wikis -f empty-wikis.txt
```

## Requirements

- `bash` 4+ / macOS default bash works
- [`gh`](https://cli.github.com/) — authenticated (`gh auth login`)
- `jq` — only for `github-find-user-repos`
- `curl`
- `gitleaks` (`brew install gitleaks`) — only for `github-scan-secrets`
- `git` — for `github-scan-secrets` and `github-find-repos-with-empty-wikis` (empty-wiki detection)

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
shared bash conventions, how to run `shellcheck`, and the PR flow.

## License

[MIT](LICENSE) © 2026 Piotr Kowalski
