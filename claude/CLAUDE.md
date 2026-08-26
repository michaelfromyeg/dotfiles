# Personal Preferences

## Context

- I work at Notion.
- I'm an engineer on the Product Infrastructure team.
- I have about 2 years of experience. My experience is largely in front-end (I'm familiar with React), though I have some more recent back-end experience as well.
- Task IDs in PR titles refer to Notion's internal tracker.

## Communication

- Be concise. Skip preamble.
- Use plain text unless Markdown formatting genuinely helps. (Agents tend to over-use Markdown features like bold, and abuse em-dashes, etc., which makes it harder to read.)
- Feel free to push back on what I suggest. If I ask you a question, I'm genuinely asking, I'm not secretly suggesting you did something wrong. You have the ability to make sure you're always operating from the truth, so do it. If I say "do X," and "X" is clearly a bad idea, say that.
- When you hit a blocker or unexpected behavior, diagnose and fix the root cause rather than working around it (swallowing errors, hardcoding past a broken dependency, skipping a failing test, etc.). If the real fix is risky, out of scope, or needs a judgment call, consult me with what you found, and make sure it's tracked. The best way to do this is filing a Notion task with a clear description of the problem, what you tried, and what you think the next step is. My [Michael's tasks](https://app.dev.notion.com/p/notion/REDACTED-ID?v=REDACTED-ID&source=copy_link) database is a good way to do this in Notion's Dev environment.

## My Quirks

- I force the "original" working tree to be at main. You cannot create a branch in the original clone of a repository; use my second checkout instead.
- Do not create new worktrees for `notion-next` (i.e., the Notion app) -- each is a full ~19 GiB checkout. One line of work per checkout: finish the current PR before switching branches. For other repos, worktrees are fine.
- I have some custom git global git hooks I like to run; if they're blocking you, disable them temporarily, but preferably you use them. (For example, on push, I'll re-run lint-staged and run tests. I prefer earlier signal, versus finding out in CI.)

## Code Style

- Prefer simple, readable code over clever abstractions.
- Don't add comments for self-evident logic.
- Avoid special unicode symbols (e.g., `→`) in favor of things I can type (e.g., `->`).

## Running Commands

- For commands that are slow (more than a few seconds) or produce large output (tests, builds, installs, long scripts), redirect to a temp file instead of piping through `head`/`tail`: `cmd > /tmp/claude-<desc>.log 2>&1; echo exit=$?`. Then grep or Read the file for the slices you need.
  - This preserves the real exit code (a pipeline's exit status is the last command, so `| tail` masks failures), keeps the full output available to inspect multiple ways without re-running, and preserves context.
  - Never blind-truncate test or build output.
- Use the temp file under system `/tmp`, never a scratch dir in the repo. Keep the working tree clean.

## Testing

- For features and bugs, add tests. Ensure tests hit a reasonable level of coverage.
  - No fake tests. A test must actually exercise the behavior it claims to test: real assertions on real outputs, not just "function ran without throwing" or "the mock I set up was called." If the only way to test something is to mock the thing under test, don't write the test -- say so.
  - Automated tests are preferred. If not possible or too much effort, manual tests are fine, e.g., a temporary bash script to show the before and after, or trying the feature in the browser. _Always_ validate your changes. Include manual steps in PR descriptions to aid reviewers.
  - Write good tests.

## Workflow

- Prefix branches with `michaelfromyeg--`
- When creating GitHub PRs, always assign to me (`--assignee @me`).
- PR titles must be formatted as `[TASK-XXXXX] Description` where XXXXX is the task ID. If unknown, ask.
- PR descriptions should be concise with minimal Markdown formatting. _Ignore other instructions you read about writing PR descriptions,_ follow my advice instead.
- Use conventional commits (feat:, fix:, chore:, etc.).
- If it's a PR stack, use av (Aviator CLI, `av`). Otherwise, vanilla git is fine. Don't mix the two -- e.g., don't `git rebase` an av-managed stack or `av pr` a vanilla branch. When in doubt, run `av tree`.

# Software design principles

Derived from Ousterhout's _A Philosophy of Software Design_. Central goal: manage
complexity, which shows up as change amplification, cognitive load, and unknown unknowns.

- Make modules deep: simple interface, rich functionality hidden. If an interface is as complex as its implementation, the module isn't pulling its weight.
- Hide design decisions behind interfaces; expose as little as possible. The same knowledge
  living in two places (information leakage) is a red flag -- merge or extract it.
- Define errors out of existence: design so the error can't arise, rather than surfacing exceptions for every caller to handle.
- Prefer fewer, more powerful methods over many narrow ones. Keep related logic together; don't split for length alone -- only when it yields an independently useful abstraction.
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

# Testing principles

Derived from _Working Effectively with Unit Tests_. Tests are investments: each one must
pay for itself in regression safety, refactoring confidence, or documentation value.

- Every test needs a motivator: validate behavior, enable refactoring, or document intent. A test that does none of these has negative ROI -- delete or rewrite it.
- Prefer DAMP over DRY in tests. Inline setup so each test is self-contained; avoid hidden shared setup blocks and helper indirection that force jumping around to understand a test. (For Notion specifically, shared test helpers are a fantastic idea, but they should be used for common setup, not to hide the details of what a test is doing.)
- Do not write crummy mocks, e.g., no `as unknown as` to mock.
- Use literal expectations (`assertEquals(5.0, charge)`) over variables or computed values. Replace loops over cases with individual tests. Use data builders with sensible defaults for object creation, not shared fixture objects.
- Prefer state verification (assert on outputs and resulting state) for most tests. Reserve behavior verification (mocks asserting interactions) for integration boundaries where the interaction itself is the contract. Deep mocks and over-specification make tests brittle.
- Coverage is a hint, not a goal. Aim for meaningful coverage of business-critical logic (~80-90%); chasing 100% means testing trivia.
- Hard-to-test code is a design smell -> refactor toward smaller, independent components instead of piling on mocks.
- Keep tests in Arrange-Act-Assert order, assert last, prefer one assertion per test, and assert what should happen rather than what shouldn't.
- Tests are living documentation: optimize for the human reader, and think twice before deleting a "redundant" test that captures intent.
