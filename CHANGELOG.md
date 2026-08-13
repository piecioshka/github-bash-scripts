# Changelog

All notable changes to this project, newest first.

- 2026-08-13 — Renamed the `--only-empty` flag of `github-find-repos-with-wikis` to `--only-unused`, matching the flag of `github-find-repos-with-projects-feature` (`-e` stays the short form in both).
- 2026-08-13 — Fixed `github-find-repos-with-only-readme` silently undercounting when the GitHub API rate limit kicks in mid-scan: rate-limited repos now produce a `WARN` on stderr instead of being treated as "not README-only".
- 2026-08-13 — Added `-p` / `--check-pages` to `github-find-repos-with-only-readme`: each found repository is additionally checked for GitHub Pages — enabled shows the Pages URL in green, disabled a red `pages off`; the summary counts how many have Pages on.
- 2026-08-13 — Renamed `github-find-repos-with-unused-projects-feature` to `github-find-repos-with-projects-feature`: it now lists every repository with the Projects feature enabled together with its linked-project count, and the old behaviour (unused only) moved behind the new `-e` / `--only-unused` flag.
- 2026-08-13 — Clarified the progress and summary messages of `github-find-repos-with-wikis`: the header counts "candidate repos (wiki flag on)" and the summary reports how many candidates were skipped because the wiki feature is not actually available.
- 2026-08-13 — Renamed `github-find-repos-with-empty-wikis` to `github-find-repos-with-wikis`: it now lists every repository with the wiki feature enabled together with its wiki page count, and the old behaviour (empty wikis only) moved behind the new `-e` / `--only-empty` flag.
- 2026-08-13 — Changed `github-find-repos-with-license` to leave a wider gap between the repository name and the license info (repo column grew from 45 to 60 characters).
- 2026-08-13 — Changed `github-find-repos-with-license` to print the license badge without the `📄` emoji.
- 2026-08-13 — Fixed `github-find-repos-with-empty-wikis` reporting repositories whose wiki feature is off: the GraphQL `hasWikiEnabled` flag used for pre-filtering can disagree with the repo settings, so each candidate is now re-checked against the REST `has_wiki` field before its wiki content is inspected.
- 2026-08-13 — Changed `github-find-repos-with-branch` to require `-b <branch>`; the implicit `gh-pages` default is gone.
- 2026-08-13 — Changed `github-find-repos-with-broken-homepages` to print only the `BROKEN` rows by default; the new `-a` / `--all` flag restores the full listing (replaces `-b` / `--broken-only`).
- 2026-08-13 — Renamed all sixteen scripts to verb-first names so each name reads as the question it answers — `github-find-*` for filtering (e.g. `github-find-repos-without-description`, `github-find-repos-with-broken-homepages`), `github-list-*` for reports, and action verbs for the rest (`github-enable-pages`, `github-disable-wikis`, `github-clear-homepages`, `github-scan-secrets`, `github-find-user-repos`).
- 2026-07-16 — Added `-b` / `--broken-only` to `github-homepage-list-broken`: prints only the repositories whose homepage is broken, skipping the `OK` rows. ([`dd1fb79`])
- 2026-06-10 — Added `github-projects-disable`: turns off the Projects tab in a user's repositories, with `DRY_RUN=1` support. ([`8804155`])
- 2026-06-10 — Added `github-projects-list-empty`: lists repositories whose Projects tab is enabled but holds no projects. ([`79c61e3`])
- 2026-06-10 — Added `github-wiki-disable`: turns off the wiki in a user's repositories, with `DRY_RUN=1` support. ([`fc16fcc`])
- 2026-06-10 — Added `github-wiki-list-empty`: lists repositories that have the wiki enabled but never wrote a page into it. ([`cd0ba99`])
- 2026-06-10 — Added `github-repos-with-license`: lists repositories that ship a `LICENSE` file, with `-n` to narrow the scan down to Node.js projects. ([`c812c78`])
- 2026-06-10 — Added `github-description-list-empty`: lists repositories with no description set. ([`86530e7`])
- 2026-06-10 — Changed `github-repos-readme-only` to stop requiring `jq`; `jq` is now needed only by `github-repos-search`. ([`d3aa205`])
- 2026-04-20 — Changed `github-pages-list` to show where each Pages site is built from — `[⚙️ actions]` for workflow builds, `[📁 <branch>:<path>]` for branch-based ones. ([`0c0b96b`])
- 2026-04-20 — Added `github-repos-with-branch`: lists repositories that still carry a given branch (`gh-pages` by default, `-b` for any other name). ([`be2f9b5`])
- 2026-04-20 — Changed the listing scripts to mark repository state on a TTY with badges: `[🔐 private]`, `[🍴 fork]` and `[📦 archived]`. Badges are never written to `-o` output files. ([`d934b2e`])
- 2026-04-20 — Added `github-repos-readme-only`: lists repositories that contain nothing but a README. ([`0c6b4a2`])
- 2026-04-18 — **Changed:** the `list` and `search` scripts now print to stdout by default instead of always writing a file. Pass `-o <path>` to also save URLs to a chosen file, or a bare `-o` for an auto-named `<name>-<user>_YYYY-MM-DD_HH-mm-ss.txt` in `$PWD`. ([`44ee0aa`])
- 2026-04-18 — Initial project set-up: `github-homepage-clear`, `github-homepage-list`, `github-homepage-list-broken`, `github-pages-disable`, `github-pages-enable`, `github-pages-list`, `github-repos-scan-secrets` and `github-repos-search`, plus a ShellCheck workflow on GitHub Actions. ([`62cc4cf`])

[`dd1fb79`]: https://github.com/piecioshka/github-bash-scripts/commit/dd1fb7909fc0ebd89dc18514279ed8e2b34c1c44
[`8804155`]: https://github.com/piecioshka/github-bash-scripts/commit/880415592a00defa2f9b24f47973ac6ff97fe25d
[`79c61e3`]: https://github.com/piecioshka/github-bash-scripts/commit/79c61e32d17f7ba25c3c7872f76092a82cba5306
[`fc16fcc`]: https://github.com/piecioshka/github-bash-scripts/commit/fc16fccaec084b607454ec246a7374e560040947
[`cd0ba99`]: https://github.com/piecioshka/github-bash-scripts/commit/cd0ba992075f9f08fcae9a1070d8db13c58014bb
[`c812c78`]: https://github.com/piecioshka/github-bash-scripts/commit/c812c78391f16b001d7d7db4b215ca34a2a1279f
[`86530e7`]: https://github.com/piecioshka/github-bash-scripts/commit/86530e76eb39e23418ec97a6dda815aa5db4fc05
[`d3aa205`]: https://github.com/piecioshka/github-bash-scripts/commit/d3aa205998e43ff0f8f577765fb6d5646dafd670
[`0c0b96b`]: https://github.com/piecioshka/github-bash-scripts/commit/0c0b96bea1e7fc58fd2c6a112588cc3c0d9e9e91
[`be2f9b5`]: https://github.com/piecioshka/github-bash-scripts/commit/be2f9b53da0ccaaa89830d1afad1a0ea321cba88
[`d934b2e`]: https://github.com/piecioshka/github-bash-scripts/commit/d934b2e8689bb0d6f1ea1e192c6618c5d0a4b511
[`0c6b4a2`]: https://github.com/piecioshka/github-bash-scripts/commit/0c6b4a258743ccd718bd97ee9483f4e02cb7df88
[`44ee0aa`]: https://github.com/piecioshka/github-bash-scripts/commit/44ee0aaf0dab0054cfd300334a0a78f0db83be7a
[`62cc4cf`]: https://github.com/piecioshka/github-bash-scripts/commit/62cc4cfac9609cd562f11037d851ca200c480aec
