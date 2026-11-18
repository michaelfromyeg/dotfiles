"""Mutation rules for the test-quality review, independent of files, git and processes.

`run_mutant.py` applies one temporary source change, runs a test command and
restores the file. This module decides what the change is, what the test
command's exit code means, which paths may be mutated, and what happens to a backup left by an
interrupted run.
"""

import hashlib
import json
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path


class Outcome(StrEnum):
    KILLED = "killed"
    SURVIVED = "survived"
    TIMEOUT = "timeout"
    # The test command could not start, or exited with a code that does not
    # mean "tests ran and some failed" (a usage error, a collection error).
    ERROR = "error"
    INTERRUPTED = "interrupted"


class LeftoverAction(StrEnum):
    RESTORE = "restore"
    ALREADY_RESTORED = "already-restored"
    # The file differs from both the original and the mutant: someone edited it
    # after the interrupted run, and writing the backup would discard that edit.
    CHANGED_SINCE_MUTATION = "changed-since-mutation"
    OUTSIDE_REPOSITORY = "outside-repository"
    MISSING = "missing"


class MutationError(ValueError):
    pass


@dataclass(frozen=True)
class Backup:
    """A mutated file's original bytes.

    In a stored record `path` is relative to the repository root, so a record
    survives the checkout being moved; recovery resolves it against the current
    root before calling `leftover_action`.
    """

    path: Path
    original: bytes
    mutant_sha256: str

    def to_json(self) -> str:
        return json.dumps(
            {
                "path": str(self.path),
                "original_hex": self.original.hex(),
                "mutant_sha256": self.mutant_sha256,
            }
        )

    @classmethod
    def from_json(cls, text: str) -> "Backup":
        """Raises ValueError for any record that is not a complete backup."""
        try:
            record = json.loads(text)
            return cls(
                path=Path(record["path"]),
                original=bytes.fromhex(record["original_hex"]),
                mutant_sha256=str(record["mutant_sha256"]),
            )
        except (KeyError, TypeError, AttributeError) as error:
            raise ValueError(f"incomplete backup record: {error}") from error


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def replace_snippet(source: str, old: str, new: str) -> str:
    """Replace `old` with `new`, requiring exactly one literal match."""
    count = source.count(old) if old else 0
    if count != 1:
        raise MutationError(f"the snippet must match exactly once; it matched {count} times")
    mutated = source.replace(old, new)
    if mutated == source:
        raise MutationError("the replacement leaves the file identical")
    return mutated


def classify_exit(exit_code: int, killed_exit_codes: frozenset[int]) -> Outcome:
    if exit_code == 0:
        return Outcome.SURVIVED
    if exit_code in killed_exit_codes:
        return Outcome.KILLED
    return Outcome.ERROR


class RecordDisposition(StrEnum):
    DELETE = "delete"
    # The record no longer matches the file, so it must stop blocking new runs,
    # but it holds the only copy of the original bytes: keep it under a name
    # that new runs ignore, for manual recovery.
    SET_ASIDE = "set-aside"


def is_inside(path: Path, root: Path) -> bool:
    """Lexical containment by path components; `path` must already be resolved."""
    return ".." not in path.parts and path.is_relative_to(root)


def log_path_refusal(path: Path, repo_root: Path, temp_dirs: list[Path]) -> str | None:
    """Why `--log` may not be written to `path`, or None when it may.

    Opening the log truncates it, so it must be a scratch location: inside a
    temporary directory and outside the repository (which can itself sit under
    /tmp). All paths must already be resolved.
    """
    if not any(is_inside(path, directory) for directory in temp_dirs):
        return f"must be inside a temporary directory ({', '.join(map(str, temp_dirs))})"
    if is_inside(path, repo_root):
        return "must be outside the repository"
    return None


def encode_run_deadline(now: float, run_seconds: float, cleanup_seconds: float) -> bytes:
    """The time by which a run starting at `now` will have restored its file."""
    return str(now + run_seconds + cleanup_seconds).encode()


def decode_run_deadline(raw: bytes, now: float, cleanup_seconds: float) -> float:
    """Read a deadline written by `encode_run_deadline`.

    A recovery holds the lock without writing one, and a run killed while
    writing leaves a partial value; both are short-lived, so wait one cleanup
    period from `now`.
    """
    try:
        return float(raw.decode())
    except (UnicodeDecodeError, ValueError):
        return now + cleanup_seconds


class RunCleanup(StrEnum):
    # The mutant never reached the file; the record is not needed.
    DISCARD_RECORD = "discard-record"
    # The file holds neither version: someone else's edit. Keep the original.
    SET_ASIDE = "set-aside"
    RESTORE = "restore"


def run_cleanup(
    current: bytes | None,
    original: bytes,
    mutant: bytes,
    *,
    mutant_write_failed: bool,
    test_started: bool,
) -> RunCleanup:
    """What a run does with the source and its backup when it ends.

    Only skip the restore when the mutant provably never landed: no test ran,
    and either the file still holds the original or the write raised and the
    file is not the mutant. Any other state may follow a mutant that did land.
    """
    # A failed write is only evidence when the file exists and is not the
    # mutant: an error raised after the atomic rename still leaves the mutant
    # in place, and a deleted file's backup is the only copy of its original.
    write_never_landed = mutant_write_failed and current is not None and current != mutant
    if not test_started and (current == original or write_never_landed):
        return RunCleanup.DISCARD_RECORD
    if current not in (mutant, original):
        return RunCleanup.SET_ASIDE
    return RunCleanup.RESTORE


def trusted_outcome(outcome: Outcome, file_after_test: bytes | None, mutant: bytes) -> Outcome:
    """Downgrade a verdict the test run cannot support.

    Killed or survived only means something if the mutant was still in the file
    when the tests finished; if the test command rewrote it (back to the
    original, say), the tests may never have seen the mutant.
    """
    if outcome in (Outcome.KILLED, Outcome.SURVIVED) and file_after_test != mutant:
        return Outcome.ERROR
    return outcome


def record_disposition(action: LeftoverAction) -> RecordDisposition:
    match action:
        case LeftoverAction.RESTORE | LeftoverAction.ALREADY_RESTORED:
            return RecordDisposition.DELETE
        case (
            LeftoverAction.CHANGED_SINCE_MUTATION
            | LeftoverAction.MISSING
            # Paths are stored relative to the repository, so only a malformed
            # or hand-written record can point outside it. Keep its bytes.
            | LeftoverAction.OUTSIDE_REPOSITORY
        ):
            return RecordDisposition.SET_ASIDE


def is_repository_metadata(path: Path, root: Path, git_dir: Path) -> bool:
    """A file git itself reads (config, hooks, a worktree's `.git` pointer).

    A mutant left there on an interrupted run would act on later git commands
    rather than on tests. All paths must already be resolved.
    """
    return is_inside(path, git_dir) or (
        is_inside(path, root) and ".git" in path.relative_to(root).parts
    )


TEMPORARY_SUFFIX = ".test-quality"


def temporary_name(target_name: str, pid: int) -> str:
    """Name of the sibling file replace_contents writes before renaming it over the target."""
    return f".{target_name}.{pid}{TEMPORARY_SUFFIX}"


def is_temporary_of(name: str, target_name: str) -> bool:
    """Whether `name` is a temporary_name of `target_name`, and not of a sibling such as `<target_name>.bak`."""
    prefix = f".{target_name}."
    if not (name.startswith(prefix) and name.endswith(TEMPORARY_SUFFIX)):
        return False
    return name[len(prefix) : -len(TEMPORARY_SUFFIX)].isdigit()


def leftover_action(backup: Backup, current: bytes | None, repo_root: Path) -> LeftoverAction:
    """Decide whether a backup from an interrupted run may overwrite `current`.

    `backup.path` must already be resolved (symlinks followed).
    """
    if not is_inside(backup.path, repo_root):
        return LeftoverAction.OUTSIDE_REPOSITORY
    if current is None:
        return LeftoverAction.MISSING
    if current == backup.original:
        return LeftoverAction.ALREADY_RESTORED
    if sha256(current) == backup.mutant_sha256:
        return LeftoverAction.RESTORE
    return LeftoverAction.CHANGED_SINCE_MUTATION
