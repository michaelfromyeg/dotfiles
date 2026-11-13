---
name: testing
description: Apply Andy's testing principles when writing, reviewing, or refactoring tests. Covers decision ownership, semantic dependency outcomes, fakes, explicit named scenarios, builders with relevant inputs, test scope, database and integration coverage, consolidation, and focused validation. Use for $testing, test design, or test cleanup.
---

# Testing

Make each test's initial state, operation, and expected result clear, and test each meaningful distinction at its primary owner.

## Composition and scope

Use these principles for new tests, reviews, and test cleanup within the requested scope. [Architecture](../architecture/SKILL.md) owns design principles and domain representations. [Refactor](../refactor/SKILL.md) coordinates changes to existing production code and uses this skill for its test plan.

For test-only work, inspect the current production behavior and proceed within that scope. Heavy setup can reveal a production boundary problem; explain it instead of masking it with a larger fixture framework. Test work does not authorize production redesign.

This skill is the canonical home for Andy's testing preferences. When he corrects a test choice, sharpen the matching rule here (or add one) instead of recording the incident elsewhere. Repository rules in `tests/AGENTS.md` and `frontend/test/AGENTS.md` also apply.

## Decide whether a test is worth writing

Prioritize meaningful contracts, likely failure modes, and regressions. Weigh the confidence a test adds against its setup and maintenance cost; fewer tests is an acceptable outcome. Before assembling dependencies, state in one sentence the unique behavior the test proves.

Do not write tests for:

- **Glue:** scripts, entrypoints and wiring helpers, config and constants, `infra/`, and routers. Test the service or pure function they call. A script gets a `--dry-run` mode instead of unit tests; do not move one-off script logic into `rowspace/` only to test it.
- **Router exception mapping:** a mocked service raising a domain error and an assertion on the HTTP status proves nothing about whether the real service raises it.
- **Type-checker guarantees:** Pydantic defaults, required fields, `Optional` accepting `None`, `Literal`/enum membership, plain round-trips, TypeScript prop types, generated API types. Custom validators and `Field` constraints that encode a business rule are worth testing.
- **Incidental shape:** constructing a model and asserting every field, the full serialized object, identity, or hash. Adding an unrelated field must not break a test. For privacy checks, assert that specific private fields are absent instead of enumerating allowed fields.
- **Logs and metrics:** never assert log text, fields, levels, emission counts, or metric calls, in unit or integration tests.
- **Migrations:** never import a migration and call `upgrade` or `downgrade`.
- **Dependencies:** no tests that prove a third-party package or SDK works. Verify its use through application behavior.
- **Control-flow trivia:** no call-count assertions to prove an `async with` block runs once; a comment is enough.

A test-removal request includes removing support code left unused by the removal: mock modules, factories, helpers, and stale references.

## Map decisions to test owners

Before changing tests, identify the behavior under test, its dependencies, the distinctions each function owns, and the affected callers.

| Owner | Cases to protect |
| --- | --- |
| Pure function | Its meaningful input partitions, truth table, boundary values, validation, reconciliation, and state transitions. |
| Database capability | Real SQL semantics, atomicity, locking, concurrency, ordering, idempotency, conditional updates, recursive queries, and persistence invariants. |
| Caller | Each distinct result of a dependency that the caller branches on, plus decisions or composition the caller adds. |
| Workflow/integration boundary | Representative real composition, critical user-visible paths, and historically fragile integration points. |

For an email-domain classifier, test accepted domains, unrelated domains, and deceptive suffixes at the classifier. If its caller only branches on internal/external, test those two outcomes there. Likewise, test 99/100/101 at the owner of a `<= 100` rule; its caller needs allowed and rejected.

Do not replay a dependency's full input matrix through every caller. Keep separate caller cases when it uses raw values or payloads in a new way. If a dependency gained five internal cases without changing its output contract, the caller needs no new tests.

When Architecture removes invalid model combinations, test runtime parsing, decisions, and transitions at their owners. Do not recreate impossible states through bypasses to preserve an old matrix.

## Choose real code, fakes, or mocks

- **Pure dependencies:** call the real function. Pick one input per outcome the caller distinguishes.
- **Effectful collaborators** (repositories, SDK clients, blob stores, Temporal clients): use small explicit fakes with meaningful state, implementing the production Protocol. Reuse existing fakes and `InMemory*` repositories. Fakes must honor the semantics the caller relies on, such as scoped reads and conditional updates.
- **Mocks:** only for narrow interaction or failure injection. Do not replace autospec mocks with an equally opaque configurable fake framework.
- Heavy mocking is first a signal: the behavior may already be covered elsewhere, or the production boundary may be wrong. Remove redundant coverage or fix the boundary before building more machinery.
- **Temporal:** test workflows with fake activities and collaborators. Test executor and service behavior by calling them directly, not through a Temporal worker. Keep native dbt and PostgreSQL tests separate. Do not add long-wait cancellation tests.

## Write explicit scenarios

Write plain test functions, not test classes. Prefer separate tests with descriptive, potentially long names stating the condition and expected behavior over `pytest.mark.parametrize`, even when bodies are similar. Keep the distinguishing input, operation, and expectation together. Repeating a few lines is acceptable; repetition alone does not justify a shared abstraction.

```python
def test_accepts_user_with_rowspace_ai_email_domain():
    user = make_user(email="a@rowspace.ai")

    assert is_rowspace_user(user)


def test_rejects_domain_that_only_contains_rowspace_as_a_prefix():
    user = make_user(email="a@rowspace.ai.example.com")

    assert not is_rowspace_user(user)
```

Do not replace parameterization with loops, scenario switches, or helpers that hide the tested operation. Use parameterization on explicit request, or when every case follows identical control flow and dependency behavior and only a value and its expected status differ (for example, several terminal failure statuses that must all be rejected the same way). Never parameterize fixtures: every consuming test silently runs in modes not visible at the call site.

## Builders hide irrelevant construction

Expose the fields that explain the behavior and default everything else. `make_user(email="foo@bar.com")` supplies valid defaults for name and birthday. Use the `polyfactory` factories in `tests/factories/models/`. When construction needs fixture dependencies (a database session, a store), a fixture may return a builder function; this is the accepted exception to the nested-function rule in Architecture.

Avoid `make_special_internal_user()` when its hidden email is the reason the test passes. Avoid fixtures that return unlabeled tuples which the test then mutates into the scenario:

```python
# Avoid: the reader cannot see which value matters.
admitted, current, run = publication_setup
current.connection.database = "ARCHIVE"
```

Name the relevant values by their roles instead:

```python
publication = make_publication(
    admitted_database="FINANCE",
    publication_database="ARCHIVE",
)

with pytest.raises(ConnectionConfigurationChangedError):
    validate_publication(publication)
```

Keep irrelevant service construction, registry wiring, identifier bookkeeping, and coherent defaults inside builders. Do not expand parameterization into pages of copied infrastructure; split a large test by the decisions it protects before copying it.

## Name test helpers by what they do

Name helpers called from a test body `verb_noun`. The verb states the helper's effect. The noun names the role the value plays in the scenario, not only its type: `seed_applied_revision`, not `seed_revision`, when being applied is why the test passes. No helper verb performs the operation under test.

| Verb | Does | Effects | Example |
| --- | --- | --- | --- |
| `make_` | Builds an in-memory object or composed service with valid defaults, exposing only the inputs that matter | None; synchronous | `make_bundle_store()`, `make_graph(nodes)` |
| `seed_` | Arranges stored state directly through a store, repository, or table, bypassing application logic | Writes | `seed_applied_revision(bundles)`, `seed_stored_graph(bundles, revision)` |
| `create_` | Produces prerequisite state through another owner's real public operation | Runs real code | `create_source_table(tables)` |
| `stub_` | Scripts a mocked or patched dependency's outcome | Patches | `stub_snapshot(mocker, rows)` |
| `start_` | Starts a long-running resource that needs teardown, as a context manager | Owns a lifetime | `start_dbt_worker(env)` |
| `read_` | Reads stored state back for an assertion | Read-only | `read_target_rows(engine, schema)` |
| `assert_` | Checks one named condition that takes several steps | Raises on failure | `assert_no_tables_built(engine, schema)` |
| `wait_for_` | Synchronizes on an event with a timeout | Waits | `wait_for_runner_entered(runner)` |

Distinguish the close pairs:

- **`seed_` vs `create_`:** `seed_` writes the state directly; `create_` obtains it from the code that normally produces it. Use `create_` only when the test needs that real behavior to produce the state.
- **`make_` vs factories:** `<Model>Factory.build(...)` builds one model. Add a `make_` helper only when it composes several objects or keeps related values consistent.

Related rules:

- Fixtures are nouns named for their role (`applied_revision`, `bundle_store`), because they provide values rather than perform actions.
- Test doubles: `Fake<Protocol>` scripts outcomes; `InMemory<Protocol>` is a working in-memory implementation.
- Helpers in a test module have no leading underscore; nothing imports them. Put helpers shared across modules in `tests/fixtures/`.
- Avoid `setup_`, `sample_`, `mock_`, `get_`, `check_`, `do_`, and bare-noun function names. They hide the helper's effect, and `get_` reads like application code.
- Apply these names to new and changed tests. Do not rename existing helpers only for this convention.

## Keep the tested operation visible

Helpers construct state. They do not secretly execute the behavior whose result the test asserts.

- When testing admission and completion, call `recorder.admit(...)` and `recorder.finish(...)` visibly instead of hiding them in `create_finished_run(recorder)`.
- When testing a decision made in a later lifecycle stage, construct the state that stage receives and call it directly. To test which executor publication selects, build an already-admitted run and call publication; do not replay creation, dispatch, admission, and retry first. Cover admission at its own owner.

If testing one rule still requires many unrelated repositories, a blob store, an inspector, a queue, and a clock, revisit ownership using Architecture rather than building a generic fixture framework.

## Database, filesystem, and concurrency tests

- Tests that need PostgreSQL, containers, real external tools such as dbt, network I/O, or files outside a test-owned temporary directory are integration tests and live under `tests/integration/`. A test that uses `tmp_path`, or whose code under test creates a temporary directory, stays in `tests/unit/` when it is otherwise fast and in-process.
- Persistence and concurrency behavior needs real PostgreSQL. A good concurrency test keeps repository setup visible, constructs the competing requests explicitly with distinct IDs, runs them with `asyncio.gather`, and asserts the shared returned identity and the persisted state.
- Flag slow tests: subprocesses (git, docker, bash, uv, node), containers, real network I/O, many components assembled for one check, or roughly over 1 s (unit) / 30 s (integration). Prefer the in-process equivalent. If indispensable, mark `@pytest.mark.slow`, keep it in `tests/integration`, and give it an explicit timeout.

## Consolidate without losing coverage

A moved test is a new test: justify its setup at its new location. If it needs real infrastructure only for an assertion that another owner already proves, drop that assertion and the infrastructure.

For each test considered for removal, identify the unique decision or invariant it protects and where that coverage will live. Repeating a lower-level distinction makes a test a removal candidate, not automatically redundant. Keep coverage that catches critical wiring, user-visible behavior, historical regressions, or failures not expressed by lower-level contracts. Do not prune from coverage percentages or impose a quota of integration tests.

## Validate focused

- Run targeted tests only: explicit files, test IDs, or narrow directories. A cross-cutting change or desire for reassurance does not justify a full suite; leave broad coverage to CI. Run relevant static checks, and do not rerun an unchanged check that passed.
- Include focused PostgreSQL-backed integration tests when persistence or concurrency changed; do not limit validation to edited files.
- From a non-interactive shell, run recipes through `just exec --customer <name> -- just <recipe>`.
- Before calling a failure pre-existing or unrelated, install the worktree's own locked dependencies (`pnpm install --frozen-lockfile`, `uv sync`). A borrowed `node_modules` or editable environment from another checkout can load different versions.

Before finishing, verify that relevant inputs and the tested operation are visible, callers do not inherit dependency matrices, and each removed case has an ownership rationale. Report what the focused validation establishes and any remaining coverage gaps. Never report a raw test count.
