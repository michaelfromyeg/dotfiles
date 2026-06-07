# Personal Preferences

## Context

- I work at Notion.
  - I'm an engineer on the Product Infrastructure team.
  - I have about 2 years of experience, so keep that in mind when discussing.
  - Task IDs in PR titles refer to Notion's internal tracker.

## Communication

- Be concise. Skip preamble.
- Use plain text unless formatting genuinely helps.
- Feel free to push back on what I suggest. If I ask you a question, I'm genuinely asking, I'm not secretly suggesting you did something wrong. You have the ability to spawn `Explore` agents, use search tools, and more to make sure you're always operating from the truth, so do it. If I say "do X," and "X" is clearly a bad idea, say that.
- When you hit a blocker or unexpected behavior, diagnose and fix the root cause rather than working around it (swallowing errors, hardcoding past a broken dependency, skipping a failing test, etc.). If the real fix is risky, out of scope, or needs a judgment call, stop and consult me with what you found -- don't silently route around it.

## Code Style

- Prefer simple, readable code over clever abstractions.
- Don't add comments for self-evident logic.
- Don't add docstrings, type annotations, or error handling beyond what's asked.
- Avoid special unicode symbols (e.g., `→`) in favor of things I can type (e.g., `->`).

## Running Commands

- For commands that are slow (more than a few seconds) or produce large output (tests, builds, installs, long scripts), redirect to a temp file instead of piping through `head`/`tail`: `cmd > /tmp/claude-<desc>.log 2>&1; echo exit=$?`. Then grep or Read the file for the slices you need.
  - This preserves the real exit code (a pipeline's exit status is the last command, so `| tail` masks failures), keeps the full output available to inspect multiple ways without re-running, and keeps my context small.
  - Never blind-truncate test or build output. The real error is often at the top, not the tail.
- For cheap, small, one-look commands (`git status`, `ls`, reading a short file), just run them inline. Don't redirect.
- Use the temp file under system `/tmp`, never a scratch dir in the repo. Keep the working tree clean.
- Prefer purpose-built tools over truncation: `rg -m`/`-C`, `Read` with offsets, `git log -n`, `pytest -q`.
- The Bash tool runs in the login shell (zsh on macOS, not bash). Write portable POSIX-compatible syntax, quote variables, and avoid bash-only or zsh-only constructs unless the shell is confirmed. Watch zsh differences: no word-splitting of unquoted `$(...)`, 1-based arrays, errors on no-match globs.

## Testing

- For features and bugs, add tests. Ensure tests hit a reasonable level of coverage.
  - No fake tests. A test must actually exercise the behavior it claims to test: real assertions on real outputs, not just "function ran without throwing" or "the mock I set up was called." If the only way to test something is to mock the thing under test, don't write the test -- say so.
  - Automated tests are preferred. If not possible or too much effort, manual tests are fine, e.g., a temporary bash script to show the before and after. Include manual steps in PR descriptions to aid reviewers.
- Run relevant existing tests before declaring a code change done.
- If you can't run tests (no command, no env), say so explicitly rather than claiming success.

## Workflow

- Prefix branches with `michaelfromyeg--`
- When creating GitHub PRs, always assign to me (`--assignee @me`).
- PR titles must be formatted as `[TASK-XXXXX] Description` where XXXXX is the task ID. If unknown, ask.
- PR descriptions should be concise with minimal Markdown formatting.
- When editing dotfiles: edit in the repo, remind me to run `dotfiles env` to sync.
- Use conventional commits (feat:, fix:, chore:, etc.).
- If it's a PR stack, use Graphite (`gt`). Otherwise, vanilla git is fine. Don't mix the two -- e.g., don't `git rebase` a Graphite-managed stack or `gt submit` a vanilla branch. When in doubt, run `gt ls`.

# Software Design Principles

Derived from Ousterhout's _A Philosophy of Software Design_. Central goal: manage
complexity, which shows up as change amplification, cognitive load, and unknown unknowns.

- Make modules deep: simple interface, rich functionality hidden. If an interface is as
  complex as its implementation, the module isn't pulling its weight.
- Hide design decisions behind interfaces; expose as little as possible. The same knowledge
  living in two places (information leakage) is a red flag -- merge or extract it.
- Define errors out of existence: design so the error can't arise, rather than surfacing
  exceptions for every caller to handle.
- Prefer fewer, more powerful methods over many narrow ones. Keep related logic together;
  don't split for length alone -- only when it yields an independently useful abstraction.
- Comment the why, not the what: intent, invariants, edge cases. Don't restate the code.
- Names should create a precise mental image. Avoid vague names (`data`, `handle`,
  `process`); use one name per concept everywhere.
- Invest ~10-20% in improving code you touch. Leave it better than you found it.

Red flags:
- A change needs edits in many places -> change amplification.
- You must read a lot of code to make a small change -> high cognitive load.
- Many params/methods, or exposed internal data -> shallow or leaky abstraction.
- The same information appears in multiple places -> information leakage.
- A general utility has special-case logic for one caller -> wrong abstraction boundary.
