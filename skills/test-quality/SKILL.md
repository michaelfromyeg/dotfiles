---
name: test-quality
description: Measure whether new or changed tests would catch real regressions. Runs diff-scoped mutation testing, changed-line coverage, a revert check (do the new tests fail against the old code?), and a flakiness rerun, then reviews the tests against the repository's testing rules and unit-testing literature. Reports findings; does not edit tests. Use when the user asks for a test-quality review or asks "are these tests any good?"; it temporarily rewrites source files, so do not start it on your own.
---

# Test quality

You judge whether a set of tests earns its keep. The repository's static test review (`.agents/skills/review-squad/dimensions/testing.md`) reads tests. You also run them: you change the code under test and observe whether the tests notice. Evidence from running beats opinion from reading; when they disagree, report the evidence.

You report. You do not fix tests, add tests, or change production code. The only file changes you make are the temporary ones the bundled runner applies and reverts. Never edit repository files with an editor or shell redirection; logs go in the review's temporary directory. Before you finish, confirm `git status --short` matches what it was when you started.

## Runner

This copy of the skill bundles its mutation runner in `runner/` beside this file. Wherever this skill says `<runner>`, run, from the repository root:

```bash
PYTHONPATH=<skill dir>/runner python3 -P -m tools.test_quality.run_mutant
```

`<skill dir>` is `$HOME/.claude/skills/test-quality` in Claude Code and `$HOME/.agents/skills/test-quality` in Codex. `-P` keeps the repository's own `tools` package off the import path, so the bundled runner is always the one that runs. Pass arguments after it exactly as shown below; `--` separates the test command.

## 1. Establish the brief

The caller should tell you:

- **What changed**: a base ref (for example `origin/main`) or a list of files.
- **Behavior under test**: one or two sentences on what the tests are meant to protect. If it is a bug fix, what the bug was.
- **Test files** and, when non-standard, the command that runs them.
- **Customer env** for backend tests, when the tests need one: the `<name>` for `just exec --customer <name> --` (see "Running `just` from non-interactive shells" in the root `AGENTS.md`).

When something is missing, derive it rather than stopping: `git diff --merge-base origin/main --stat` and the untracked files from `git status --short` give the change set; test names and the production diff give the intent. State what you inferred in the report so the caller can correct it.

Split the change set into **production files** (code that behaves) and **test files** (tests, fixtures, factories, `conftest.py`). If there are no production changes, the subject is the existing code the tests target.

**No-diff mode.** When asked to review existing tests with no base ref, the whole module is the subject: report whole-file coverage in step 4, aim mutants at decision logic, treat every test as new in step 7, and skip step 6.

## 2. Load the testing rules

Read, in order, and treat them as canonical over anything below:

1. `AGENTS.md` at the repository root and the nearest `AGENTS.md` above each test file (`tests/AGENTS.md`, `frontend/test/AGENTS.md`).
2. `.agents/skills/review-squad/dimensions/testing.md`, the static checklist.
3. A `testing` skill, if one is available to you.

When they conflict, the earlier document wins. Step 8 repeats only the lenses these documents do not cover; do not re-derive their rules.

## 3. Baseline

Create one log directory for this review with `mktemp -d /tmp/claude-test-quality.XXXXXX` and write every log into it, so concurrent reviews on one host do not overwrite each other's evidence. Shell variables do not persist between commands, so reuse the literal path it prints; below it is `<logs>`. Remove the directory when the report is done.

Run only the targeted test files, never the whole suite. Write output to a file and keep the real exit code:

```bash
just be-test <test files> -q -p no:cacheprovider > <logs>/baseline.log 2>&1; echo exit=$?
```

Run tests through the `just` recipes, which own test invocation: `just be-test` for unit tests, `just be-test-int` for integration tests (it starts the services they need; running them without it fails on env, which would score as a kill), and `just fe-test <test files> > <logs>/baseline.log 2>&1; echo exit=$?` for frontend tests (it runs Jest from `frontend/` itself). Use the same recipe as the test command for every mutant and revert check. When this worktree's Compose stack is running, `just be-test-int` runs pytest inside the backend container, where the runner cannot stop it: a `timeout` or `interrupted` result there leaves those tests running against the restored source. Give such mutants a `--timeout` well above the baseline duration, and if one still ends in `timeout` or `interrupted`, stop and tell the caller before running anything else.

Agent shells are non-interactive, so the worktree env is not loaded. When the backend tests need it, put `just exec --customer <name> --` in front of the test command itself (the baseline, coverage, and the words after `--` for mutants and revert checks), and use exactly the form that made the baseline pass: a missing env makes tests fail with exit 1, which would be scored as a kill. Never wrap `<runner>` itself in `just exec`: that recipe re-splits its arguments, so a quoted `--old` or `--new` snippet with spaces arrives broken. Write it as `<runner> --file <f> --old '<snippet>' --new '<replacement>' --log <logs>/mutant-1.log -- just exec --customer <name> -- just be-test <test files>`. If the baseline fails for any other reason, stop and report the failure: every later step assumes a green baseline. Record the baseline duration; it sets the mutant budget.

## 4. Changed-line coverage

Measure coverage of the production files by the targeted tests, with branch coverage:

```bash
just be-test <test files> -q -p no:cacheprovider --cov=<dotted.module> --cov-branch --cov-report=term-missing > <logs>/coverage.log 2>&1
```

Frontend: `just fe-test <test files> --coverage --collectCoverageFrom=<src path> --coverageReporters=text`. (`just be-test-cov` covers the whole suite and takes no file arguments, so it does not fit here.)

Intersect the missing lines and partial branches with the changed hunks (`git diff -U0 --merge-base <base> -- <file>`). Report changed-line coverage, not file totals: a file at 60% is fine when the uncovered 40% predates the change. For each uncovered changed line, say whether it matters (a decision, a boundary, an error path) or is arid (logging, metrics, re-raises, type-only code). Coverage only shows what executed. Mutation testing shows what is checked, so do not stop here.

## 5. Mutation testing (the core check)

Hand-pick mutants on the changed production lines, apply each with the bundled runner, and see whether the targeted tests fail. This follows Google's diff-based practice (Petrovic et al., "Practical Mutation Testing at Scale", 2021). Mutate only changed lines, at most one or two mutants per line, and skip arid lines. It also follows Meta's ACH work (2025): choose mutants that model a plausible real fault rather than every syntactic operator.

**Choosing mutants.** Prioritize lines that make a decision. Good operators:

- Boundary: `<` to `<=`, `>= 100` to `> 100`, off-by-one in slices and ranges.
- Logic: `and` to `or`, drop a negation, invert a condition, delete one clause of a compound condition.
- Return and value: return `None`, an empty collection, the input unchanged, `True` for `False`; swap two arguments of the same type.
- Statement deletion: remove a guard, a filter, an `await`ed write, a validation `raise`, a cache invalidation.
- Exception path: swallow the exception, raise a different type, skip the rollback.
- Frontend: render the wrong branch of a conditional, drop a dependency from a hook's deps array, skip `preventDefault`, invert a disabled state.

Skip: logging and metrics calls, comments and docstrings, type annotations, constants whose only test would restate them, and code the repository says not to unit test. Budget about 10 to 20 mutants. If the baseline takes more than 30 seconds, cut to the 5 to 8 most consequential and say so.

**Running one mutant.** `--old` is matched literally, including leading whitespace, and must match exactly once; include surrounding text to make it unique. Pass the test command as separate words after `--`, not as one quoted string.

```bash
<runner> \
  --file rowspace/lib/currency/currency.py \
  --old 'or len(code) != 3' --new 'and len(code) != 3' \
  --log <logs>/mutant-1.log \
  -- just be-test tests/unit/lib/test_currency.py -q -x -p no:cacheprovider
```

`--file` must be a source file inside the repository (not git metadata and not a gitignored file), and `--log` must be inside a temporary directory. It prints one JSON line whose `outcome` is one of:

- `killed`: the command exited with a code in `--killed-exit-codes` (default `1`, which pytest and Jest use for failing tests).
- `survived`: the command exited 0.
- `timeout`: the command ran past `--timeout` seconds and was stopped.
- `error`: the command could not start, exited with another code (such as pytest's 2, a collection error, or 4, a usage error), or changed the file under test so the tests may not have seen the mutant (a formatter or `git checkout` in the command). The `error` field says which. Fix the command and rerun; never count it as a kill.
- `interrupted`: the run received SIGINT or SIGTERM.

The process exits 0 when the file was restored. It exits 2 when the change could not be applied: nothing was modified, and `error` says why (the snippet did not match exactly once, the ref does not resolve, a backup is pending, or the file changed before the mutant was written). It exits 3 in two cases, told apart by the `state` field: `edited-kept` means the file was edited or deleted during the run, so it is left as found and its original is set aside (the error names the kept file); `restore-failed` means the file may still hold the mutant and the backup record is kept. Run `<runner> --restore-leftovers` first, then stop and tell the caller.

While mutants run, the checkout holds a mutated source file for each test run, for up to `--timeout` seconds at a time: do not commit, run other tests, or let anyone else use this checkout until the review ends and `git status --short` matches the start. The runner refuses (exit 2) while a dev stack is running from this checkout, either the Docker Compose stack or a host dev server (`just run`, `just be-dev`) listening on any port, because they reload changed source and would execute the mutant against the local database. It also refuses when `docker ps` or `lsof` cannot answer, and the error names which one. Do not stop them yourself: tell the caller, who can stop them (`just down`, or quit `just run`) or, when integration tests need the stack, ask you to pass `--allow-running-stack`. Run mutants one at a time, never in parallel: a second run in the same checkout is refused, because one run's mutant changes what every other test sees. If you are interrupted or see a pending-backup error, run `<runner> --restore-leftovers` before anything else. It waits until a run that is still going has passed its `--timeout` and restored its own file, then restores a file only when the file still holds the recorded mutant. When a file was edited or deleted since, it leaves the file alone and sets the record aside (`original_kept_in` names it) so new runs are not blocked. If recovery reports `orphaned_tests` with `not-verified-left-running`, a crashed run's test processes may still be running in that process group: tell the caller the pgid before running anything else. New runs stay refused while `.git/test-quality/test-group.pid` exists; recovery removes it once no process in that group is left, and the caller may delete it after confirming the group is gone. Every recovery also lists all set-aside records under `kept`; tell the caller where they are, and delete one only after the caller confirms they no longer need its original bytes. A record that could not be restored is reported as `failed` and recovery exits 3: stop and tell the caller, because that file may still hold a mutant. Finish with `git status --short` and `git diff --stat` and confirm they match what you saw at the start.

**Reading a killed mutant.** Open its log. A mutant killed only by an `ImportError`, a syntax error or a type error caught at import time says nothing about assertions. With pytest these usually exit 2 and come back as `error`, but Jest reports a suite that fails to load with exit 1. Count any such kill as `killed (crash)` and do not credit the tests with it.

**Reading a survivor.** Decide which case applies:

1. **Equivalent mutant**: the change cannot alter observable behavior (for example `>=` to `>` where equality is impossible, or a later fallback path produces the same result). Not a finding; note it and the reason. Do not classify a boundary mutant as equivalent by reasoning alone: call the function from a short `uv run python -c` script with real inputs and look for one that lands exactly on the boundary. That probe often turns a "probably equivalent" mutant into a concrete gap.
2. **Behavior the repository says not to test** (glue, config, type-checker territory). Not a finding.
3. **A real gap**: a plausible fault that ships green. This is a finding. Name the smallest test that would kill it, with its input and expected output.

The survivors in group 3 are the most useful output of the whole review.

## 6. Revert check

Tests written for a change should fail without it. For each production file in the change, swap in its content at the base ref and run the new or changed tests:

```bash
<runner> \
  --file <production file> --from-ref <base ref> \
  --log <logs>/revert.log \
  -- just be-test <new test ids> -q -p no:cacheprovider
```

`survived` means the new tests pass against the old code. For a bug fix that is a high-severity finding: the test does not reproduce the bug. For a refactor that is expected, and it is evidence that the tests are structure-insensitive. If the old code cannot import the new test's dependencies, pytest exits 2 on the collection failure and the result is `error`; for Jest, a suite that fails to load exits 1, so count it as `killed (crash)`. Either way it proves nothing; say so. A production file that did not exist at the base ref is replaced by an empty file, so its check is vacuous: report it as skipped (no base-ref content). Skip this step when there is no base ref.

## 7. Determinism

Run the new tests three more times, and once under `-n auto` for pytest or `--runInBand` and default parallelism for Jest. Run any test that touches module-level state (a cache, a registry, a singleton) on its own as well, by test ID, to catch order dependence. Any difference across runs is a flaky test; find the cause, typically wall-clock time, random values, ordering, shared state between tests, or real sleeps. The repository's rules on clocks and slow tests (`tests/AGENTS.md`) say what to flag while reading.

## 8. Read the tests

Apply the repository's rules from step 2; review-squad's testing charter already covers tests that cannot fail and testing each distinction at its owner. Then apply these lenses, which those documents do not cover. Cite a lens only when it explains a concrete defect.

- **Four pillars** (Khorikov, *Unit Testing Principles, Practices, and Patterns*): protection against regressions, resistance to refactoring, fast feedback, maintainability. Resistance to refactoring is the one most often lost. A test that asserts on private helpers, call order or intermediate structure breaks when correct code is restructured.
- **Observable behavior over implementation details**: assert outputs and resulting state. Use mocks only where the interaction itself is the contract, typically an unmanaged out-of-process dependency. A test whose only assertion is that a mock was called proves nothing about the result.
- **Working Effectively with Unit Tests** (Jay Fields): DAMP over DRY, so each test reads alone; literal expected values rather than values computed the way the code computes them; one behavior per test, asserted last; builders with defaults rather than shared fixture objects.
- **Test smells** (Meszaros, *xUnit Test Patterns*): mystery guest (inputs in a hidden fixture or file), eager test (several behaviors in one test), assertion roulette, conditional test logic (`if` or loops in a test body), obscure test, test logic in production code, a general fixture that every test only partly uses.
- **Test Desiderata** (Kent Beck): isolated, deterministic, fast, readable, behavioral, structure-insensitive, specific (a failure points at the cause), predictive (passing means the code works).
- **Input partitions**: for a pure function, check that the tests cover each meaningful partition and boundary rather than several values from one partition. When the input space is wide and an invariant is easy to state (a round-trip, an idempotent operation, an ordering), suggest a property-based test. Only suggest a new dependency if the project already uses one.
## 9. Report

Return this to the caller. Keep it plain; the caller relays it.

```
Verdict: strong | adequate | weak, with one sentence why.
Scope: base ref, production files, test files, anything you inferred.

Mutation: K killed (C by crash), S survived (E equivalent, X out of scope, G gaps), T timeout, R error (rerun or dropped), of N.
Changed-line coverage: covered/total changed lines (whole-file percentage in no-diff mode); uncovered lines that matter.
Revert check: failed as expected | passed against old code | skipped (why).
Determinism: stable across 4 runs and parallel | flaky (which test, cause).

Findings, most severe first, one block each:
  label: mutation-gap | revert | coverage | flaky | smell | rule | out-of-scope | slow
  confidence: high | medium | low
  location: <file:line>
  problem: <what is wrong; for a survivor, the exact mutant>
  why: <the regression that would ship, or the maintenance cost>
  fix: <the smallest concrete test or change: input, expected value, where it goes>

Mutants: a table of location, change, outcome, and for survivors the classification.
Not checked: anything skipped and why (budget, no base ref, env missing).
```

The finding block matches review-squad's finding shape so the two reports can be merged. Do not report a raw test count as a quality signal, and do not pad the findings: "no findings" is a valid result when the mutants die and the tests read well.
