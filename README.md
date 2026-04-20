# github-bash-scripts

[![github-ci](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml)

Collection of bash helpers for managing GitHub repositories in bulk: listing, auditing and cleaning up Pages, homepages and secrets.

All scripts live in [`bin/`](bin/). Most share the same conventions:

- `-u <username>` — scope to a user's repos (via `gh repo list`)
- `-f <file>` — input file with URLs (one per line; lines starting with `#` are ignored)
- stdin — pipe URLs in
- `-v public|private|all` — visibility filter (where applicable)
- `-F/--include-forks` — include forks (default: excluded)
- `DRY_RUN=1` — preview without making changes (for destructive actions)
- Colored columnar output when writing to a TTY
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
brew install gitleaks   # only if you plan to use bin/github-repos-scan-secrets
```

## Example usage

### Read / list

```bash
# List repos that have GitHub Pages enabled
github-pages-list -u piecioshka
github-pages-list -u piecioshka -v public
github-pages-list -u piecioshka -v private
github-pages-list -u piecioshka -F                       # include forks
github-pages-list -u piecioshka -r                       # output repo URLs instead of Pages URLs
github-pages-list -u piecioshka -o                       # also save to auto-named file in $PWD
github-pages-list -u piecioshka -o my-pages.txt          # also save to a specific file
CONCURRENCY=20 github-pages-list -u piecioshka

# List repos that have a non-empty website/homepage set
github-homepage-list -u piecioshka
github-homepage-list -u piecioshka -v public
github-homepage-list -u piecioshka -v private
github-homepage-list -u piecioshka -F
github-homepage-list -u piecioshka -r                    # output repo URLs
github-homepage-list -u piecioshka -o                    # also save to auto-named file in $PWD
github-homepage-list -u piecioshka -o my-homepages.txt   # also save to a specific file

# List repos whose homepage URL is broken (non-2xx/3xx)
github-homepage-list-broken -u piecioshka
github-homepage-list-broken -u piecioshka -v public
github-homepage-list-broken -u piecioshka -F
github-homepage-list-broken -u piecioshka -r             # output repo URLs (chainable)
github-homepage-list-broken -u piecioshka -o             # also save to auto-named file in $PWD
github-homepage-list-broken -u piecioshka -o broken.txt  # also save to a specific file
CONCURRENCY=20 TIMEOUT=30 github-homepage-list-broken -u piecioshka

# List repos that contain only a single README.md file (placeholders)
github-repos-readme-only -u piecioshka
github-repos-readme-only -u piecioshka -v public
github-repos-readme-only -u piecioshka -F
github-repos-readme-only -u piecioshka -o                # also save repo URLs to auto-named file
github-repos-readme-only -u piecioshka -o readme.txt     # also save repo URLs to a specific file
CONCURRENCY=20 github-repos-readme-only -u piecioshka

# Search across repo metadata (name, description, homepage, topics, language)
github-repos-search -u piecioshka -q angular
github-repos-search -u piecioshka -q angular -v public
github-repos-search -u piecioshka -q angular -F
github-repos-search -u piecioshka -q TypeScript -c       # case-sensitive
github-repos-search -u piecioshka -q '^workshop-.*2019' -E   # regex
github-repos-search -u piecioshka -q react -o               # also save repo URLs to auto-named file
github-repos-search -u piecioshka -q react -o matches.txt   # also save repo URLs to a specific file
```

### Audit (secrets)

```bash
# Scan git history of each repo with gitleaks + grep pattern (parallel)
github-repos-scan-secrets -u piecioshka
github-repos-scan-secrets -u piecioshka -v public
github-repos-scan-secrets -u piecioshka -F
github-repos-scan-secrets -f repos.txt
github-repos-scan-secrets owner/repo another-owner/repo        # positional slugs
echo "https://github.com/owner/repo" | github-repos-scan-secrets

# Env overrides
CONCURRENCY=8 github-repos-scan-secrets -u piecioshka
GREP_PATTERN="my_secret|prod_token" github-repos-scan-secrets -u piecioshka
RESULTS_DIR=/tmp/reports github-repos-scan-secrets -u piecioshka
```

### Modify (write operations)

All destructive operations support `DRY_RUN=1` to preview changes.

```bash
# Enable GitHub Pages for each repo (source: main / root by default)
github-pages-enable repos.txt
cat repos.txt | github-pages-enable
BRANCH=gh-pages github-pages-enable repos.txt
BRANCH=main PATH_IN_REPO=/docs github-pages-enable repos.txt

# Disable GitHub Pages (deletes the 'gh-pages' branch; refuses other branches)
DRY_RUN=1 github-pages-disable -f repos.txt
github-pages-disable -f repos.txt
cat repos.txt | github-pages-disable

# Clear the repo website/homepage URL
github-homepage-clear -u piecioshka                      # only clears *.github.io
github-homepage-clear -u piecioshka -v public
github-homepage-clear -u piecioshka -v private
github-homepage-clear -u piecioshka -F
github-homepage-clear -u piecioshka --force              # clears ANY homepage
github-homepage-clear -f repos.txt
cat repos.txt | github-homepage-clear
DRY_RUN=1 github-homepage-clear -u piecioshka
```

### Chained workflows

```bash
# 1) Find repos whose homepage is broken, then clear those homepages
github-homepage-list-broken -u piecioshka -r -o broken.txt
github-homepage-clear -f broken.txt --force

# 2) Find repos matching a query, then scan them for secrets
github-repos-search -u piecioshka -q legacy -o legacy.txt
github-repos-scan-secrets -f legacy.txt

# 3) Get all repos with Pages, then disable Pages for a curated subset
github-pages-list -u piecioshka -r -o all-pages.txt
# ...edit all-pages.txt to keep only the ones you want disabled...
DRY_RUN=1 github-pages-disable -f all-pages.txt
github-pages-disable -f all-pages.txt
```

## Requirements

- `bash` 4+ / macOS default bash works
- [`gh`](https://cli.github.com/) — authenticated (`gh auth login`)
- `jq`
- `curl`
- `gitleaks` (`brew install gitleaks`) — only for `github-repos-scan-secrets`
- `git` — only for `github-repos-scan-secrets`

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
shared bash conventions, how to run `shellcheck`, and the PR flow.

## License

[MIT](LICENSE) © 2026 Piotr Kowalski
