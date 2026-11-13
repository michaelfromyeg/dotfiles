---
name: architecture
description: Apply Andy's architecture and code-design principles when designing, implementing, refactoring, or reviewing application code. Covers readability, deep modules, semantic ownership, dependency wiring, explicit orchestration, valid domain representations, relational invariants, complexity justification, errors, Temporal, and Rowspace code conventions. Supplies design criteria within the requested scope, not a mandate to redesign code.
---

# Architecture

Optimize for ease of understanding. Readable code lets a reader predict what happens next without simulating the program in their head: it minimizes the context they must hold at once and makes intent, behavior, and important consequences obvious. Readers judge complexity, not writers. Every rule below serves this goal; when following one would make the code harder to understand, the goal wins.

Each important concept should have one module that hides its complexity from callers, so a change requires understanding less unrelated code.

Apply the relevant principles within the user's scope; a review or design question does not authorize implementation. [Refactor](../refactor/SKILL.md) owns the change workflow and approval rules, [Testing](../testing/SKILL.md) owns test design, and [Diagram](../diagram/SKILL.md) creates architecture visuals only on explicit request.

This skill is the canonical home for Andy's design and code-level preferences. When he corrects a design or code choice, sharpen the matching rule here (or add one) instead of recording the incident elsewhere; skip one-off decisions that only apply to a single PR.

## Write for the reader

- **Boring control flow.** The happy path is visible at a glance. A top-level function reads like a table of contents of meaningful steps; the reader descends into a step only when they need its details. Avoid deep nesting, callbacks, and state that one phase builds and a later phase patches.
- **Extract to name a meaning, not to shorten.** Extract a block when its name states something the reader would otherwise have to derive by reading it: a domain rule or a step of the operation. Do not extract to reduce length, line count, or a complexity score. Inline a single-use helper whose name only restates its body, or whose callers cannot be understood without opening it.
- **Encode conclusions.** When a condition is a business concept, name it (`can_access_manifold(user)`) instead of making every reader reconstruct it from the evidence (`user.active and any(role.name in ALLOWED_ROLES ...)`).
- **Domain vocabulary.** Names come from how we discuss the system: `sync.is_incremental and source.supports_cdc`, not `config.mode == "incremental" and adapter.has_feature(...)`. Precise domain terms (CDC, watermark, applied revision, idempotency key) are fine; do not replace them with generic words such as `data`, `config`, `handler`, `process`, or `run_job`. Readable does not mean requiring no domain knowledge.
- **Local reasoning.** A reader should understand a function without opening many files. Every layer is another concept to hold in working memory: `connection.client` beats `registry.get_provider(...).resolve(...).build_client(...)` unless those layers hide substantial complexity.
- **Abstractions compress knowledge, not syntax.** `is_rowspace_user(user)` compresses a rule; an `IdentityPolicyEvaluatorFactory` adds concepts without hiding more than it costs. Duplication is cheaper than the wrong abstraction.
- **Visible consequences.** A function's name, signature, or docstring lets the reader predict its mutation, I/O, transactions, retries, locks, concurrency, caching, global state, scheduled follow-up work, and expensive operations. Do not leave them for the reader to discover three calls down.
- **Consistency.** Similar code looks and behaves similarly: sibling helpers return the same shape, and equivalent identifiers are built the same way.
- **Density.** Aim for roughly one idea per chunk of code: neither a block mixing several ideas nor one idea spread across many tiny functions.

Short functions, DRY, self-documenting code, more abstraction, and low complexity scores are proxies, not definitions of readability. When a proxy conflicts with the questions below, follow the questions.

Before handing off code, run `cccc` (in `~/.local/bin`) on the changed source files, excluding tests and generated code: `cccc --table --max-cyclomatic 40 <files>`. It lists every function's cognitive and cyclomatic complexity and exits non-zero when any function exceeds cyclomatic 40; split a function over that limit before handing off. Below the limit, treat a new or grown function near the top as a prompt to reapply these principles, and report the hotspots you left in place. The score is a signal, not a target.

| Property | Question |
| --- | --- |
| Intent | Can I tell what this code is trying to accomplish? |
| Control flow | Can I follow the happy path immediately? |
| Locality | Can I understand this without opening many other files? |
| Vocabulary | Do names correspond to actual domain concepts? |
| Abstraction | Does each abstraction hide meaningful complexity? |
| Explicitness | Are important side effects and constraints visible? |
| Consistency | Does similar code look and behave similarly? |
| Density | Is there roughly one idea per chunk of code? |

## Identify responsibility and ownership

| Kind of logic | Where its complexity belongs |
| --- | --- |
| Pure decisions | Named functions over values: validation, classification, planning, reconciliation, mapping, and state transitions. No repositories, sessions, network clients, blob stores, or global context; pass time explicitly when needed. |
| Relational/database logic | A cohesive persistence capability: joins, recursive traversal, bulk operations, uniqueness, ordering, idempotency, locking, and atomic transitions. |
| Orchestration | Explicit sequencing of loading, observation, decisions, and effects. Substantial filtering, grouping, validation, conversion, or SQL construction inside it indicates a concept to extract. |

Group behavior by the invariant it maintains, the state it operates on, and its reason to change. Look for concrete “does X AND Y” concerns; several methods alone do not prove a boundary violation.

Place pure code by what it decides, not by the fact that it is pure:

- Domain representations, domain errors, and pure interpretation of them belong with the models (`core/models/...`).
- Application policy, such as execution eligibility, stays in the owning service module even when it is a pure function.
- Services are not a dumping ground for pure helpers, and models are not a home for application policy.

## Choose a deep boundary

- Organize around capabilities, not database entities. Repository interfaces need not map one-to-one to tables; a concept can span several tables.
- Prefer a small semantic API such as `store.apply_run_results(...)` over making callers load tables, bindings, and schemas and reconstruct the operation themselves. The caller should not need storage layout, query counts, locks, or intermediate persistence objects.
- Give writes clear semantic ownership. Other modules call the owning capability instead of mutating its state representation.
- A service is a cohesive domain boundary, not one class per operation. Put start/promote/read/create operations on the service that owns the domain. Consolidate action-sized services (`ManifoldDbtPromotionStartService`, a generic `cloned_table.py`) instead of extending the pattern. The same applies to stores: extend the owning store instead of adding an operation-specific one such as `IClonedTableCreationStore`.
- Introduce a class only for cohesive behavior, meaningful state, or an actual resource lifetime. Otherwise use named module-level functions. Do not create one Service, Manager, Repository, Coordinator, Helper, or Handler per method.
- Existing cohesive Services and Repositories are valid. Evaluate actual contracts instead of renaming everything to the vocabulary below.
- Name collaborators for the capability the caller relies on. `database` for an adapter that inspects relation schemas and drops scratch tables hides what it does; distinguish inspection from mutation. Do not defend a name by pointing at one subset of what it grants (`read_only_access` for a policy that also writes artifacts).

A useful test of depth: could the implementation become substantially more sophisticated while the caller stays unchanged?

### Protocols and adapters

- Use concrete classes by default. A Protocol needs a real implementation boundary, typically an external system (SDK, warehouse, dbt, blob store, Temporal) whose callers need a fake to test their own behavior.
- Put the Protocol and the types that cross it (results, evidence, errors) in `core`, so consumers and their tests do not import the adapter package.
- Do not split a Protocol because one caller uses one method; add the method to the existing protocol.
- Implementations and fakes inherit the Protocol explicitly, so the contract is statically checked. Fakes honor the relevant semantics (scoped reads, conditional updates), not only the method names.
- Audit the whole public adapter boundary when introducing one, including context-managed methods.

## Wire dependencies explicitly

- Constructor dependencies are required. Never `X | None = None` with a no-op fallback, and never optional because some callers do not pass it yet: wiring every caller is part of the work. Tests pass explicit collaborators.
- Inject the concrete collaborator instead of a switch that selects it internally. `SqlFileSystemRepository(scope="user" | "manifold")` choosing its own tables and connection was rejected; the entrypoint selects and passes them.
- Create long-lived clients (Temporal, SDK sessions) in async application wiring and pass the instance. Do not add per-adapter factories, cached getters, or initialization locks; use the SDK's own connection-lifetime handling.
- Inject the service itself, not a no-argument factory that reconstructs it per request. A service may cache stable identity internally (a deployment's project ID), never mutable state.
- Read configuration at the boundary and pass values in. For Pulumi, read `pulumi.Config()` in the `*_args_from_config()` functions, not inside components.
- Routers in `rowspace/app/routers/` and entrypoints are wiring: parse the request, call the owning service, serialize the response. No queries, backend construction, or orchestration inline.

## Keep orchestration explicit

A reader should see the operation's ordering, decisions, side effects, and ownership in one top-to-bottom method:

```python
state = await store.load_publication_state(...)
observations = await inspector.inspect(state.outputs)
changes = reconcile_outputs(state=state, observations=observations)
await store.record_observations(changes)
```

- Read inputs through concrete collaborators, decide with pure functions or value objects, then perform explicit writes or execution. Not every operation needs every phase.
- Adapters return data or prepared resources; they do not call back into application services. Backend callbacks (`before_execute`, `approval.validate`) need a concrete justification because they hide control flow.
- Nested functions and closures, especially with `nonlocal`, are a strong smell. Use module-level helpers, methods for genuinely owned state, or direct statements. SDK-required callbacks stay at the adapter boundary with explicit instance state. (Test builders returned by fixtures are the accepted exception; see Testing.)
- Keep mapping helpers, naming policy, and prompt construction out of activities and orchestration methods; put them in named functions or a dedicated module.
- Shared progress or checkpoint bookkeeping must not decide what executes next. Do not build a generic stage dispatcher with stage-dependent return types.
- Keep resource ownership behind ordinary `async with` boundaries. Do not scatter `partial` wrappers or manual context-manager entry/exit through orchestration.
- Keep the validated resource the same one that executes.

Separate interpretation from effects when it simplifies ownership; do not move relational work into Python for architectural purity.

## Keep relational correctness in the database

Use the database for structural integrity and atomicity; keep business policy in application code.

- Constraints cover keys, referential integrity, uniqueness, nullability, and scalar shape. Lifecycle transitions, permissions, review policy, and conditional workflow rules stay in services. Transactions and locks may make those decisions atomic; they do not define them. No constraint triggers or database functions for business rules.
- The capability performing one logical operation owns its transaction. When partial persistence is invalid, keep the related writes and completion update atomic instead of asking callers to recreate that guarantee.
- Name the scope of atomicity: an external effect and a database write are not one transaction. A Publisher can orchestrate publication while a Store implements its database transaction.
- Joins, CTEs, recursive SQL, UPSERTs, bulk writes, and locks are appropriate behind a cohesive API. Push filtering, sorting, and pagination into SQL instead of doing it in Python.
- If an ordinary current-state read needs history reconstruction (lateral joins across runs and results), keep the current state or reference on the owning entity instead.
- Persist an explicitly mapped stored contract. Do not serialize a public API model wholesale into durable JSON, because its changes would silently change retained records.

### Concurrency needs a named second actor

Before adding locking, conditional updates, or race handling, name the concrete second actor: the request, workflow, or worker that can run at the same time against the same rows. A queue processed by one Temporal workflow at a time has no second publisher. Without a named actor, an ordinary transaction is sufficient; do not add locks or race tests for hypothetical overlap.

When a second actor exists, a `load → compare → write` sequence needs database protection. Prefer a capability such as `store.apply_if_newer(...)` implemented with a conditional update. Prefer `ON CONFLICT` against existing uniqueness constraints over explicit lock choreography.

### Migrations and indexes

- Prefer one transactional migration for new tables, backfills, and indexes when the write-lock cost is acceptable. A table added by an unmerged parent PR is not a populated production table.
- Use concurrent indexing only for a populated, actively written table. Then audit every autocommit boundary: earlier DDL can commit before the revision is stamped, and an interrupted build leaves an INVALID index that `IF NOT EXISTS` does not repair. Make revision progress and index state retry-safe without defaulting to drop-and-rebuild.
- Index ordered pagination: a cursor query on `(project_id, created_at, id)` needs that index, or each page still scans and sorts history. Verify first-page and cursor-page query plans.
- Keep queries ordinary (`queue.c.state == "pending"`) unless measured performance requires otherwise.

## Make illegal states unrepresentable

Ask what invalid combinations a model lets callers construct. Inspect correlated nullable fields, mutually exclusive booleans, status-dependent payloads, and dictionaries that defer required structure to callers.

- Prefer variants carrying their required data over a status flag beside many optional fields. `Ping(time, id) | None` expresses the relationship better than independently optional time and ID fields.
- Return explicit results instead of overloading `None`. An executor that returns `None` to mean “nothing to run” should return an explicit no-op result.
- Do not add fields before a caller gives them meaning. A `Literal` with one value that every record shares is a placeholder, not a discriminator.
- Preserve all legitimate states, including meaningful absence and failure.
- Parse external or weakly structured input into domain values at a boundary, and return the checked value so downstream functions can require it. Define how parsing treats duplicates or conflicting input instead of silently discarding information. Keep validation and normalization as separate named steps.

These techniques follow [Make Illegal States Unrepresentable](https://functional-architecture.org/make_illegal_states_unrepresentable/). Apply them where they remove concrete ambiguity or repeated checks, not as a reason to wrap every primitive or build a class hierarchy.

### Distinguish what each guarantee proves

- Annotations and unions support static checking; they do not validate external data at runtime. Use Pydantic models or checked constructors at boundaries, and keep checked values immutable when later mutation would invalidate them. Recorded evidence is immutable fact, not mutable workflow state.
- A structurally valid value does not prove that a referenced row exists, belongs to the right owner, remains live, or has not changed concurrently. Keep those checks at the database or external-system boundary. For example, a typed revision ID passed to a pointer update does not prove the revision row exists in that project; the conditional update must check it.
- An admission snapshot proves what was admitted, not what is true forever.

## Start with the simplest design

When designing, propose the simplest design that handles the cases that exist today, and stop there. Add a mechanism only when a concrete failure case appears: a real input, run, or user flow that the current design breaks. Until then, name the uncovered case as a known limitation instead of building for it.

- Present the minimal design first. List possible additions separately as deferred, each with the failure that would justify it.
- When a failure arrives, extend the existing design for that case. Do not replace it with a general framework.
- Build on the existing system and native tools (dbt, Temporal, PostgreSQL) before adding layers around them.

## Justify complexity with a concrete producer

Every layer, recovery path, and abstraction must solve a current, demonstrated problem. Ask what produces the situation it handles.

- Prefer supported SDK and library APIs over custom serialization, protocol handling, executors, or frameworks. For synchronous SDK calls from async code, use `asyncio.to_thread`.
- Do not add recovery for a failure without a real producer. Unexplained ID collisions roll back and reject. Malformed typed results are programming errors. Cancellation or restart scenarios with no identified caller do not need handling. Identify the producer and its impact before proposing recovery.
- Never turn an unpublished iteration into a compatibility contract. Earlier drafts or commits in an unmerged PR are not released formats: no legacy readers, missing-version defaults, migration fallbacks, patch markers, or comments implying shipped history. Verify a format shipped before claiming compatibility.
- Remove an error contract with its last producer: exception class, router mapping, response variant, docs, and tests together, then regenerate the API client.
- Two similar implementations do not justify an abstraction. Name the invariant, drift risk, or maintenance cost it removes; prefer local duplication when callers have different reasons to change.
- `AsyncExitStack` is a complexity warning. Use direct `async with` for a fixed set of resources; a stack needs dynamic acquisition that exists now.
- Unsupported input can be rejected with a stated limitation (in a code comment) instead of building repair or partial-recovery machinery. Keep safety and resource bounds.
- Future composition and test convenience do not justify a production lifecycle abstraction.

## Errors and cancellation

- Expose named domain errors and handle the relevant outcomes explicitly. Do not walk exception causes to extract string codes or wrap them in a generic error.
- Check native library error types before classifying message strings. Preserve native diagnostics instead of remapping them with strings or regexes into an invented taxonomy.
- Translate SDK and Temporal serialization wrappers at the adapter boundary; domain callers do not interpret them.
- Let cancellation propagate. Do not swallow it or spread shielding and retry bookkeeping across layers. A retained catch needs an explicit resource-safety reason, must re-raise, and must not delay shutdown indefinitely.
- Keep cancellation review proportionate: no exhaustive cancellation handling or test matrices without a concrete, material consequence.

### Temporal

- Activities return typed results; carry IDs (such as a Tensor session ID) on activity outputs and failures. Do not signal the workflow mid-activity through `activity.client()` for progress.
- A payload that does not satisfy the typed activity contract is a retryable protocol failure, not domain progress. Do not add domain handling for it.
- Workflow cancellation belongs to Temporal. Do not catch it to mark stages cancelled or launch final checkpoint activities. Persisted progress is the last recorded checkpoint, not a copy of Temporal's execution status.
- A failed result that is only returned still completes the workflow successfully; raise after recording when the workflow must fail.

## Code conventions

- **Imports:** import specific names at module top level (`from rowspace.constants import SANDBOX_BACKEND`), never inside functions. Import moved types from their defining module and update callers; never preserve old paths with re-exports such as `from module import Error as Error`. Resolve import cycles by restructuring, not `TYPE_CHECKING` guards.
- **Regular expressions:** extract each into a named constant with matching and non-matching examples beside it.
- **Named constants:** name filenames, suffix sets, limits, and timeouts; keep feature-wide bounds in one configuration module.
- **Comments:** comments supply what the code cannot: why, rejected alternatives, invariants, contracts, and non-obvious consequences (“We deliberately don't retry 409s: a conflicting sync owns the destination lock.”). Do not narrate mechanics; if the mechanics need prose, simplify the code. Comments and docstrings must stand alone for repository readers. Explain enduring behavior or constraints with actual code and domain names. Never include agent process notes, workstream labels (“B1”), or temporary coordination context. Explain opaque operations (bit masks, platform flags) and state incomplete safety work as explicit TODOs.
- **HTTP APIs:** design around resources and method semantics, not service commands disguised as endpoints. New endpoints return HTTP 200 to match the generated client convention.
- **Module layout:** group provider interfaces under `core/interfaces/integrations/<provider>/`. Group new feature adapters in a package (`adapters/temporal/manifold/`) instead of adding flat `manifold_*` modules. Put new Just commands in the existing module namespace (`just sandbox::...`), not the root.

## Rowspace vocabulary

A starting vocabulary for proposed boundaries. These are semantic signals, not mandatory suffixes or a mandate to rename existing modules. Domain names come first; a role suffix earns its place only when it tells the reader something about the contract, such as a Recorder enforcing lifecycle ordering.

| Name | Owns | Typical methods | Should be allowed to |
| --- | --- | --- | --- |
| **Recorder** | Durable lifecycle/history of an event or run | `admit`, `record`, `finish` | Enforce idempotency, ordering, and lifecycle invariants. |
| **Publisher** | Applying an external or physical result to application state | `publish` | Inspect state, compute changes, and atomically persist them. |
| **Store** | Deep persistence capability for a concept | `load_state`, `apply_results`, `record_observations` | Join multiple tables and use transactions, locks, and optimized SQL. |
| **Catalog** | Descriptive/discoverable metadata | `get`, `update_metadata` | Own metadata representation and lookup. |
| **Graph** | Relationships and traversal | `upstream`, `downstream`, `affected_by` | Use recursive SQL, graph traversal, and dependency calculations. |
| **Queue** | Work eligibility and claiming | `enqueue`, `claim`, `complete`, `fail` | Own locking, concurrency, ordering, and retries. |
| **Registry** | Available implementations/resources keyed by identity | `find`, `resolve`, `registered` | Map identifiers to implementations/resources. |
| **Inspector** | Observation of external/current reality without owning it | `inspect` | Query Postgres, system catalogs, and external systems. |
| **Resolver** | Turning an abstract reference into a concrete resource | `resolve` | Perform lookup/selection, but generally not mutate. |
| **Planner** | Conversion of desired state/input into actions | `plan` | Contain pure or mostly pure decision logic. |
| **Reconciler** | Comparison of desired/observed/current state and calculation of changes | `reconcile` | Remain pure. |
| **Validator** | Checks for a coherent set of invariants | `validate`, `require_valid` | Perform pure validation where possible. |
| **Reader** | A query/read model optimized for consumers | `get`, `list`, `read` | Perform purpose-built reads spanning multiple entities. |

Distinguish the close pairs:

- **Reconciler vs Publisher:** a Reconciler computes changes; a Publisher applies them.
- **Inspector vs Catalog:** an Inspector observes reality it does not own; a Catalog owns stored metadata.
- **Reader vs Store:** a Reader serves consumer-shaped reads; a Store protects a concept's write invariants.
- **Planner vs Reconciler:** a Planner turns desired input into actions; a Reconciler compares desired and observed state.

The repository also uses some terms more broadly (event publishers, metrics recorders, effectful reconcilers). Assess their actual contracts.
