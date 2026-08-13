# github-bash-scripts

[![github-ci](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml/badge.svg)](https://github.com/piecioshka/github-bash-scripts/actions/workflows/shellcheck.yml)

Collection of bash helpers for managing GitHub repositories in bulk: listing, auditing and cleaning up Pages, homepages, wikis, projects, descriptions and secrets.

All scripts live in [`bin/`](bin/). Most share the same conventions:

- `-u <username>` — scope to a user's repos (via `gh repo list`)
- `-f <file>` — input file with URLs (one per line; lines starting with `#` are ignored)
- stdin — pipe URLs in
- positional slugs — scripts that consume a repo list also take `owner/repo` args directly (e.g. `github-disable-wiki owner/repo`)
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
github-scan-secrets -u piecioshka
github-scan-secrets -u piecioshka -v public
github-scan-secrets -u piecioshka -F
github-scan-secrets -f repos.txt
github-scan-secrets owner/repo another-owner/repo        # positional slugs
echo "https://github.com/owner/repo" | github-scan-secrets

github-scan-secrets -u piecioshka -g 'my_secret|prod_token'   # custom grep regex
github-scan-secrets -u piecioshka -d /tmp/reports             # custom reports directory
CONCURRENCY=8 github-scan-secrets -u piecioshka
```

### Modify (write operations)

All destructive operations support `DRY_RUN=1` to preview changes.

```bash
# Enable GitHub Pages for each repo (source: main / root by default)
github-enable-pages -f repos.txt
cat repos.txt | github-enable-pages
github-enable-pages owner/repo another/repo              # positional slugs
github-enable-pages -f repos.txt -b gh-pages             # custom source branch
github-enable-pages -f repos.txt -b main -p /docs        # custom source path

# Disable GitHub Pages (deletes the 'gh-pages' branch; refuses other branches)
DRY_RUN=1 github-delete-pages-branch -f repos.txt
github-delete-pages-branch -f repos.txt
cat repos.txt | github-delete-pages-branch
github-delete-pages-branch owner/repo another/repo             # positional slugs

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
github-find-repos-with-homepage -u piecioshka -r -o broken.txt
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

## Requirements

- `bash` 4+ / macOS default bash works
- [`gh`](https://cli.github.com/) — authenticated (`gh auth login`)
- `jq` — only for `github-find-repos-by-metadata`
- `curl`
- `gitleaks` (`brew install gitleaks`) — only for `github-scan-secrets`
- `git` — for `github-scan-secrets` and `github-find-repos-with-wiki` (wiki page counting)

## Contributing

Contributions are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md) for the
shared bash conventions, how to run `shellcheck`, and the PR flow.

## License

[MIT](LICENSE) © 2026 Piotr Kowalski
