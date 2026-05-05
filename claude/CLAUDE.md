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

## Code Style

- Prefer simple, readable code over clever abstractions.
- Don't add comments for self-evident logic.
- Don't add docstrings, type annotations, or error handling beyond what's asked.
- Avoid special unicode symbols (e.g., `→`) in favor of things I can type (e.g., `->`).

## Testing

- For features and bugs, add tests. Ensure tests hit a reasonable level of coverage.
  - No fake tests. A test must actually exercise the behavior it claims to test: real assertions on real outputs, not just "function ran without throwing" or "the mock I set up was called." If the only way to test something is to mock the thing under test, don't write the test — say so.
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
- If it's a PR stack, use Graphite (`gt`). Otherwise, vanilla git is fine. Don't mix the two — e.g., don't `git rebase` a Graphite-managed stack or `gt submit` a vanilla branch. When in doubt, run `gt ls`.

# Software Design Principles

Derived from John Ousterhout's _A Philosophy of Software Design_.

## Core Goal

- The central problem of software design is managing complexity. Every decision should be evaluated by whether it increases or decreases the complexity of the system.
- Complexity manifests as: (1) change amplification — one change requires many edits, (2) cognitive load — you need to hold a lot of context to make a change, (3) unknown unknowns — you don't know what you need to know. Minimize all three.

## Module Design

- Make modules deep: simple interface, rich functionality hidden behind it. A good module does a lot for its callers without exposing how.
- Avoid shallow modules: if a class or function's interface is as complex as its implementation, it's not pulling its weight.
- When creating an abstraction, ask: does this actually simplify things for the caller, or just move complexity around?

## Information Hiding

- Each module should encapsulate design decisions (data structures, algorithms, low-level details) and expose as little as possible through its interface.
- Information leakage — the same knowledge duplicated or assumed across multiple modules — is a red flag. If two modules both need to know about a format, protocol, or invariant, consider merging them or extracting the shared knowledge into one place.

## Interface Design

- Design interfaces that are somewhat general-purpose: broad enough to serve multiple use cases, but don't build speculative features. The interface should be general; the implementation can be specific to current needs.
- Define errors out of existence. Instead of surfacing exceptions for callers to handle, design the interface so the error condition can't arise or is handled internally. Every exception in an interface adds complexity for every caller.
- Fewer, more powerful methods are better than many narrow ones. Combine related operations when they share context.

## Decomposition

- Don't split methods or classes purely for length. Split only when it produces independently useful, deep abstractions.
- Aggressive decomposition into tiny units often increases complexity by scattering related logic. Keep related logic together.
- Each method should do one thing cleanly — but "one thing" can be a substantial, coherent operation, not just a few lines.

## Comments and Documentation

- Write comments that explain what is not obvious from the code: the intent behind a decision, the meaning of an abstraction, invariants, edge cases, and the "why."
- Do not write comments that restate what the code mechanically does.
- Write interface comments (what a module/function does and its contract) before or alongside writing the implementation — treat documentation as part of design.

## Naming

- Names should create a precise mental image of what the entity represents. Avoid vague names (`data`, `info`, `handle`, `process`) and unnecessarily verbose names.
- Consistency in naming conventions across the codebase matters more than cleverness in any single name. Use the same name for the same concept everywhere.

## Strategic Mindset

- Invest roughly 10–20% of effort in improving the design of code you're touching, even when the immediate task doesn't require it.
- Tactical "just make it work" programming creates complexity debt that compounds. A small upfront investment in cleaner design pays off quickly.
- When modifying existing code, leave it better than you found it.

## Red Flags

- A change requires edits in many places -> likely a design problem (change amplification).
- You need to read a lot of code to understand a small change -> high cognitive load.
- An interface has many parameters, many methods, or exposes internal data structures -> shallow or leaky abstraction.
- The same information appears in multiple places -> information leakage.
- A general-purpose utility has special-case logic for one caller -> abstraction boundary is wrong.
