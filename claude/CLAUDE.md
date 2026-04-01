# Personal Preferences

## Communication

- Be concise. Skip preamble.
- Use plain text unless formatting genuinely helps.

## Code Style

- Prefer simple, readable code over clever abstractions.
- Don't add comments for self-evident logic.
- Don't add docstrings, type annotations, or error handling beyond what's asked.

## Tools

- Use ripgrep (rg) and fd over grep and find.
- Use the fastest tool available for the job.

## Workflow

- Prefix branches with `michaelfromyeg--`
- When creating GitHub PRs, always assign to me (`--assignee @me`).
- When editing dotfiles: edit in the repo, remind me to run `dotfiles env` to sync.
- Use conventional commits (feat:, fix:, chore:, etc.).

# Software Design Principles

Derived from John Ousterhout's *A Philosophy of Software Design*.

## Core Goal

- The central problem of software design is managing complexity. Every decision should be evaluated by whether it increases or decreases the complexity of the system.
- Complexity manifests as: (1) change amplification — one change requires many edits, (2) cognitive load — you need to hold a lot of context to make a change, (3) unknown unknowns — you don't know what you need to know. Minimize all three.

## Module Design

- Make modules **deep**: simple interface, rich functionality hidden behind it. A good module does a lot for its callers without exposing how.
- Avoid **shallow modules**: if a class or function's interface is as complex as its implementation, it's not pulling its weight.
- When creating an abstraction, ask: does this actually simplify things for the caller, or just move complexity around?

## Information Hiding

- Each module should encapsulate design decisions (data structures, algorithms, low-level details) and expose as little as possible through its interface.
- **Information leakage** — the same knowledge duplicated or assumed across multiple modules — is a red flag. If two modules both need to know about a format, protocol, or invariant, consider merging them or extracting the shared knowledge into one place.

## Interface Design

- Design interfaces that are **somewhat general-purpose**: broad enough to serve multiple use cases, but don't build speculative features. The interface should be general; the implementation can be specific to current needs.
- **Define errors out of existence.** Instead of surfacing exceptions for callers to handle, design the interface so the error condition can't arise or is handled internally. Every exception in an interface adds complexity for every caller.
- Fewer, more powerful methods are better than many narrow ones. Combine related operations when they share context.

## Decomposition

- Don't split methods or classes purely for length. Split only when it produces independently useful, deep abstractions.
- Aggressive decomposition into tiny units often **increases** complexity by scattering related logic. Keep related logic together.
- Each method should do one thing cleanly — but "one thing" can be a substantial, coherent operation, not just a few lines.

## Comments and Documentation

- Write comments that explain **what is not obvious from the code**: the intent behind a decision, the meaning of an abstraction, invariants, edge cases, and the "why."
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

- A change requires edits in many places → likely a design problem (change amplification).
- You need to read a lot of code to understand a small change → high cognitive load.
- An interface has many parameters, many methods, or exposes internal data structures → shallow or leaky abstraction.
- The same information appears in multiple places → information leakage.
- A general-purpose utility has special-case logic for one caller → abstraction boundary is wrong.

