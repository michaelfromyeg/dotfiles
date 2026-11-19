"""Apply one temporary source change, run a test command, and restore the file.

Invoked as `just test-quality::mutant`. Step 5 of
`.agents/skills/test-quality/SKILL.md` documents the arguments, the JSON line
it prints, and its exit statuses.

One run or recovery at a time holds the checkout lock. Before the change is
written, a backup record is written in full to the checkout's git directory,
so it lives as long as the checkout.
`--restore-leftovers` writes a record back only when the file still holds the
recorded mutant, so edits made after a crash survive.
"""

import argparse
import contextlib
import fcntl
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from enum import StrEnum
from pathlib import Path
from typing import NoReturn

from tools.test_quality.mutation import (
    Backup,
    LeftoverAction,
    MutationError,
    Outcome,
    RecordDisposition,
    RunCleanup,
    classify_exit,
    decode_run_deadline,
    encode_run_deadline,
    is_inside,
    is_repository_metadata,
    is_temporary_of,
    leftover_action,
    log_path_refusal,
    record_disposition,
    replace_snippet,
    run_cleanup,
    sha256,
    temporary_name,
    trusted_outcome,
)

SET_ASIDE_SUFFIX = ".kept"
# Not *.json, so a leftover is never mistaken for a pending backup record.
TEST_GROUP_FILE = "test-group.pid"
# Signals that would otherwise end the run without its restore (SIGINT already
# raises KeyboardInterrupt): kill, a closed terminal, a dropped SSH session.
INTERRUPTING_SIGNALS = (signal.SIGTERM, signal.SIGHUP, signal.SIGQUIT)
# Time a run keeps the source mutated after its test command's --timeout:
# stopping the process group and restoring the file.
CLEANUP_MARGIN_SECONDS = 30
# Upper bound on a run's work before its test command starts: the dev-stack
# query (30 s timeout), git show for --from-ref, and writing the backup.
PRE_TEST_SECONDS = 120


def emit(payload: dict) -> None:
    print(json.dumps(payload))


def fail(message: str) -> NoReturn:
    emit({"outcome": Outcome.ERROR, "error": message})
    sys.exit(2)


def git(*args: str) -> str:
    try:
        out = subprocess.run(["git", *args], capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError) as error:
        fail(f"git {' '.join(args)} failed: {error}")
    return out.stdout.strip()


def repo_root() -> Path:
    return Path(git("rev-parse", "--show-toplevel")).resolve()


def git_dir() -> Path:
    return Path(git("rev-parse", "--absolute-git-dir")).resolve()


def backup_dir() -> Path:
    # Under the checkout's own git directory (per worktree), so the records
    # survive as long as the files they protect and never mix with another
    # checkout's.
    directory = git_dir() / "test-quality"
    try:
        directory.mkdir(mode=0o700, exist_ok=True)
        stat = directory.lstat()
    except OSError as error:
        fail(f"cannot use {directory}: {error}")
    if directory.is_symlink() or stat.st_uid != os.getuid() or stat.st_mode & 0o077:
        fail(f"{directory} is not a private directory owned by this user")
    return directory


def record_path_for(target: Path) -> Path:
    return backup_dir() / f"{sha256(str(target).encode())[:16]}.json"


def content_at_ref(target: Path, ref: str) -> bytes:
    resolved = subprocess.run(
        ["git", "rev-parse", "--verify", "--quiet", f"{ref}^{{commit}}"],
        capture_output=True,
        text=True,
    )
    if resolved.returncode != 0:
        raise MutationError(f"--from-ref {ref} does not resolve to a commit")
    spec = f"{resolved.stdout.strip()}:{target.relative_to(repo_root())}"
    # A file that did not exist at the ref is treated as empty, so new code
    # disappears and tests that import it fail.
    if subprocess.run(["git", "cat-file", "-e", spec], capture_output=True).returncode != 0:
        return b""
    shown = subprocess.run(["git", "show", spec], capture_output=True)
    if shown.returncode != 0:
        raise MutationError(f"git show {spec} failed: {shown.stderr.decode().strip()}")
    return shown.stdout


def read_if_present(target: Path) -> bytes | None:
    return target.read_bytes() if target.is_file() else None


class ConcurrentEditError(OSError):
    pass


def replace_contents(target: Path, data: bytes, *, expected: bytes) -> None:
    """Atomically replace `target`'s contents, keeping its permission bits.

    Refuses (ConcurrentEditError) unless `target` still holds `expected`.

    A plain write truncates first, so an interrupt or a full disk midway would
    leave content that is neither the original nor the mutant, which both
    restore paths refuse to overwrite. A rename leaves one or the other. The
    temporary file sits beside the target because a rename cannot cross
    filesystems; `.gitignore` hides one that a killed run leaves behind.
    """
    temporary = target.with_name(temporary_name(target.name, os.getpid()))
    try:
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
        with os.fdopen(fd, "wb") as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(temporary, target.stat().st_mode & 0o7777)
        # Checked as late as possible so an edit saved meanwhile is not
        # overwritten (a save in the instant before the rename still could be).
        if read_if_present(target) != expected:
            raise ConcurrentEditError(f"{target} changed before it could be replaced")
        os.replace(temporary, target)
    finally:
        # Never raise from here: after the rename succeeded, an error would read
        # as a failed write while the new content is already in place.
        try:
            temporary.unlink(missing_ok=True)
        except OSError as error:
            print(f"warning: could not remove {temporary}: {error}", file=sys.stderr)


def remove_cached_bytecode(target: Path) -> None:
    # CPython validates a .pyc by source mtime (whole seconds) and size, so a
    # same-size mutant written within the same second as an earlier one could
    # run stale bytecode. Test commands on this host never read this cache
    # (they get their own PYTHONPYCACHEPREFIX); this protects test processes
    # elsewhere that share the checkout, such as a dev container, so a failure
    # (a root-owned __pycache__) is only a warning.
    try:
        for cached in (target.parent / "__pycache__").glob(f"{target.stem}.*.pyc"):
            cached.unlink(missing_ok=True)
    except OSError as error:
        print(f"warning: could not clear cached bytecode for {target}: {error}", file=sys.stderr)


def stop_process_group(process: subprocess.Popen) -> None:
    # Test commands are often wrappers (pnpm, uv) that spawn runners and
    # workers; killing only the direct child would leave those running
    # against the restored source. Never raises: the caller restores the
    # source file next, and a cleanup failure must not prevent that.
    try:
        os.killpg(process.pid, signal.SIGKILL)
        process.wait(timeout=10)
    except (OSError, subprocess.TimeoutExpired) as error:
        print(f"warning: could not stop the test process group: {error}", file=sys.stderr)


def raise_keyboard_interrupt(_signum, _frame):
    raise KeyboardInterrupt


def try_lock(fd: int) -> bool:
    try:
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        return False
    return True


def process_start_time(pid: int) -> str | None:
    try:
        out = subprocess.run(
            ["ps", "-o", "lstart=", "-p", str(pid)],
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    return " ".join(out.stdout.split()) or None


def record_test_group(pgid: int, start: str | None) -> bool:
    """Note the test command's process group so recovery can stop it after a hard kill.

    The group runs in its own session, so nothing else stops it if this
    process dies. The leader's start time guards against a recycled pid.
    Written to a temporary name and renamed, so a reader never sees a partial
    record. Returns whether the record was written.
    """
    path = backup_dir() / TEST_GROUP_FILE
    temporary = path.with_name(f"{TEST_GROUP_FILE}.{os.getpid()}.tmp")
    record = json.dumps({"pgid": pgid, "start": start}).encode()
    try:
        temporary.unlink(missing_ok=True)
        write_new_file(temporary, record)
        os.replace(temporary, path)
    except OSError as error:
        temporary.unlink(missing_ok=True)
        print(f"warning: could not record the test process group: {error}", file=sys.stderr)
        return False
    return True


def process_group_exists(pgid: int) -> bool:
    try:
        os.killpg(pgid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    return True


def stop_orphaned_test_group(directory: Path) -> dict | None:
    """Stop a dead run's test process group, if it is still the same group."""
    path = directory / TEST_GROUP_FILE
    try:
        group = json.loads(path.read_text())
        pgid, start = int(group["pgid"]), group["start"]
    except (OSError, ValueError, KeyError, TypeError):
        path.unlink(missing_ok=True)
        return None
    if not process_group_exists(pgid):
        # Nothing left running in that group: the record has done its job.
        path.unlink(missing_ok=True)
        return None
    if start is None or process_start_time(pgid) != start:
        # The leader has exited or the pid was reused: killing by pgid could hit
        # an unrelated group, so only report it. The record stays, and keeps
        # new runs from starting, until no process in the group is left.
        return {"pgid": pgid, "action": "not-verified-left-running", "record": str(path)}
    # Stop the group first: the record keeps new runs out until it is gone.
    try:
        os.killpg(pgid, signal.SIGKILL)
    except ProcessLookupError:
        path.unlink(missing_ok=True)
        return None
    except PermissionError:
        return {"pgid": pgid, "action": "not-verified-left-running", "record": str(path)}
    path.unlink(missing_ok=True)
    return {"pgid": pgid, "action": "stopped"}


def restore_leftovers() -> None:
    # Restoring rewrites source files, which would change what a live run's
    # tests see. A live run restores its own file when it ends, so wait for it.
    hold_checkout_lock()
    root = repo_root()
    directory = backup_dir()
    # A hard-killed run's tests may still be running against the mutant; stop
    # them before restoring, or they would keep scoring against a changing tree.
    orphaned_tests = stop_orphaned_test_group(directory)
    # Caches of runs that were killed before their own cleanup; with the
    # checkout lock held, none of this checkout's caches is in use.
    for cache in Path(tempfile.gettempdir()).glob(f"{bytecode_dir_prefix(root)}*"):
        shutil.rmtree(cache, ignore_errors=True)
    results = []
    for record_path in sorted(directory.glob("*.json")):
        try:
            results.append(restore_record(record_path, root))
        except OSError as error:
            # One unrestorable record must not stop recovery of the others.
            results.append({"record": str(record_path), "action": "failed", "error": str(error)})
    # Set-aside records hold original bytes nobody has recovered yet; list them
    # every time so they are not forgotten. Deleting one is the caller's call.
    kept = sorted(str(path) for path in directory.glob(f"*{SET_ASIDE_SUFFIX}"))
    payload: dict = {"leftovers": results, "kept": kept}
    if orphaned_tests:
        payload["orphaned_tests"] = orphaned_tests
    emit(payload)
    if any(result["action"] == "failed" for result in results):
        sys.exit(3)


def restore_record(record_path: Path, root: Path) -> dict:
    """Recover one record. The caller holds the checkout lock, so its run is dead."""
    try:
        backup = Backup.from_json(record_path.read_bytes().decode())
    except ValueError:
        # The record is fully written before the mutant is, so an unreadable
        # record belongs to a run that died before changing the source file.
        record_path.unlink(missing_ok=True)
        return {"record": str(record_path), "action": "discarded-invalid-record"}
    # Stored relative to the repository, so a checkout that has moved since
    # the crash restores the file at its new location.
    target = (root / backup.path).resolve()
    current = read_if_present(target)
    action = leftover_action(Backup(target, backup.original, backup.mutant_sha256), current, root)
    if (
        action == LeftoverAction.RESTORE
        and current is not None
        and not restore_source(target, backup.original, current)
    ):
        # Edited since it was read: keep that edit and treat it as changed.
        action = LeftoverAction.CHANGED_SINCE_MUTATION
    if action != LeftoverAction.OUTSIDE_REPOSITORY and target.parent.is_dir():
        # With the checkout lock held no run is live, so any temporary copy
        # beside the target is orphaned.
        for orphan in target.parent.iterdir():
            if is_temporary_of(orphan.name, target.name):
                orphan.unlink(missing_ok=True)
    result = {"path": str(target), "action": action, "record": str(record_path)}
    match record_disposition(action):
        case RecordDisposition.DELETE:
            record_path.unlink(missing_ok=True)
        case RecordDisposition.SET_ASIDE:
            result["original_kept_in"] = str(set_aside(record_path))
    return result


def restore_source(target: Path, original: bytes, expected: bytes) -> bool:
    """Put `original` back if `target` still holds `expected`; False if it was edited.

    The one restore used by a run's cleanup and by recovery. Raises OSError
    when the write itself fails.
    """
    try:
        replace_contents(target, original, expected=expected)
    except ConcurrentEditError:
        return False
    remove_cached_bytecode(target)
    return True


def set_aside(record_path: Path) -> Path:
    # A set-aside record may hold the only copy of a file's original bytes, so
    # it must never replace an earlier one: link (which refuses an existing
    # name) instead of rename (which silently overwrites).
    attempt = 0
    while True:
        kept = record_path.with_name(
            f"{record_path.name}.{time.time_ns()}.{attempt}{SET_ASIDE_SUFFIX}"
        )
        try:
            os.link(record_path, kept)
        except FileExistsError:
            attempt += 1
            continue
        except OSError:
            # No hard links on this filesystem: copy under the kept name
            # instead (O_EXCL, so still never over an earlier one).
            try:
                write_new_file(kept, record_path.read_bytes())
            except FileExistsError:
                attempt += 1
                continue
            except OSError as error:
                # Keep the record where it is: it still holds the original and
                # goes on blocking runs until recovery, the safe direction.
                print(f"warning: could not set aside {record_path}: {error}", file=sys.stderr)
                return record_path
        record_path.unlink(missing_ok=True)
        return kept


def write_new_file(path: Path, data: bytes) -> None:
    """Create `path` with `data`, durably; never over an existing file or symlink.

    Exclusive creation keeps an earlier backup (possibly a file's only copy of
    its original) from being replaced. A partial file is removed on failure.
    """
    with open(path, "xb") as handle:
        try:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        except OSError:
            path.unlink(missing_ok=True)
            raise
    os.chmod(path, 0o600)


def create_record(record_path: Path, backup: Backup) -> None:
    """Write the backup in full before the source file is touched.

    A crash mid-write leaves an unreadable record, which recovery discards
    because the source was never changed.
    """
    write_new_file(record_path, backup.to_json().encode())


def compute_mutant(args: argparse.Namespace, target: Path, original: bytes) -> bytes:
    if args.from_ref:
        mutant = content_at_ref(target, args.from_ref)
        if mutant == original:
            raise MutationError("the file is identical at that ref")
        return mutant
    return replace_snippet(original.decode(), args.old, args.new).encode()


def write_run_deadline(lock_fd: int, run_seconds: float) -> None:
    """Record, in the held lock file, when this process will have restored its file."""
    os.ftruncate(lock_fd, 0)
    os.pwrite(lock_fd, encode_run_deadline(time.time(), run_seconds, CLEANUP_MARGIN_SECONDS), 0)


def hold_checkout_lock(*, run_seconds: float | None = None) -> int:
    """Allow one mutation run or recovery per checkout.

    A mutant in one file changes what every test in the checkout sees, so a
    second run on a different file would score its mutants against the first
    run's. The lock is released when this process exits, however it exits.

    A run (`run_seconds` given) refuses immediately when the lock is held and
    writes the time by which it will have restored its file. Recovery waits
    until that time, because the live run restores its own file.
    """
    path = backup_dir() / "run.lock"
    try:
        fd = os.open(path, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    except OSError as error:
        fail(f"cannot open {path}: {error}")
    wait_until: float | None = None
    while not try_lock(fd):
        if run_seconds is not None:
            fail("another mutation run or recovery is in progress in this checkout")
        # Read once: the fallback for a lock file without a deadline is
        # relative to now, so re-reading it would push the wait out forever.
        if wait_until is None:
            wait_until = decode_run_deadline(
                os.pread(fd, 64, 0), time.time(), CLEANUP_MARGIN_SECONDS
            )
        if time.time() >= wait_until:
            fail("another mutation run or recovery is in progress in this checkout")
        time.sleep(0.5)
    # Always replace the previous holder's deadline: a recovery writes a short
    # one, so a waiter never reads a finished run's stale value.
    write_run_deadline(fd, run_seconds if run_seconds is not None else 0)
    # Deliberately never closed: closing would release the lock.
    return fd


def bytecode_dir_prefix(root: Path) -> str:
    """Prefix of this checkout's per-run bytecode caches, so recovery can find them."""
    return f"test-quality-pycache-{sha256(str(root).encode())[:12]}-"


def compose_app_stack_running(root: Path) -> bool | None:
    """Whether this checkout's app dev stack is running; None if it cannot be told.

    The app stack (docker/local) bind-mounts the checkout and reloads changed
    source, so it would load the mutant. Compose labels every container with
    its project's working directory, so a running container whose working
    directory is this checkout's docker/local means that stack is up. Project
    names are not used, because worktrees can resolve another checkout's name.
    Other Compose stacks (such as Temporal for ingestion) do not reload app
    source and are ignored. The caller checks that the stack definition exists.
    """
    app_stack = root / "docker" / "local"
    try:
        listed = subprocess.run(
            ["docker", "ps", "--format", '{{.Label "com.docker.compose.project.working_dir"}}'],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except FileNotFoundError:
        return False  # No Docker CLI: no stack can be running.
    except (OSError, subprocess.TimeoutExpired):
        return None
    if listed.returncode != 0:
        return None
    return any(
        Path(line).resolve() == app_stack.resolve()
        for line in listed.stdout.splitlines()
        if line.strip()
    )


def host_dev_server_running(root: Path) -> bool | None:
    """Whether a host dev server from this checkout is listening; None if it cannot be told.

    Host dev servers (`just run`, `just be-dev`) reload changed source like the
    Compose stack does. They accept any port (`just be-dev --port 8002`), so
    every TCP listener counts when its working directory is inside this
    checkout. A server from another worktree does not block runs here.
    """
    try:
        listeners = subprocess.run(
            ["lsof", "-w", "-nP", "-iTCP", "-sTCP:LISTEN", "-t"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        # lsof exits 1 both when nothing listens and when it fails; -w silences
        # warnings, so anything on stderr means it could not look.
        if listeners.returncode not in (0, 1) or listeners.stderr.strip():
            return None
        pids = sorted(set(listeners.stdout.split()))
        if not pids:
            return False
        cwds = subprocess.run(
            ["lsof", "-w", "-a", "-p", ",".join(pids), "-d", "cwd", "-Fn"],
            capture_output=True,
            text=True,
            timeout=30,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    directories = [line[1:] for line in cwds.stdout.splitlines() if line.startswith("n")]
    if cwds.returncode != 0 and not directories:
        return None
    return any(is_inside(Path(directory).resolve(), root) for directory in directories)


def dev_stack_refusal(root: Path) -> str | None:
    """Why a run must not start while this checkout's dev stack could reload the mutant.

    The Compose app stack and host dev servers both reload changed source and
    would run the mutant against the local database. Each probe that cannot
    answer is named, so the caller fixes that probe instead of guessing.
    Repositories without the app stack definition have neither, so get None.
    """
    if not (root / "docker" / "local" / "docker-compose.yml").is_file():
        return None
    compose = compose_app_stack_running(root)
    host = host_dev_server_running(root)
    if compose or host:
        return (
            "a dev stack or dev server is running from this checkout, and it reloads source "
            "files, so it would run the mutant; stop it or pass --allow-running-stack"
        )
    unanswered = []
    if compose is None:
        unanswered.append("whether the Docker Compose stack is running (docker ps failed)")
    if host is None:
        unanswered.append("whether a host dev server is listening (lsof failed or is missing)")
    if unanswered:
        return (
            f"could not tell {' or '.join(unanswered)}; fix that check, or pass "
            "--allow-running-stack after confirming no dev stack or dev server runs from "
            "this checkout"
        )
    return None


def open_log(log: str | None) -> int:
    """Open the test log for writing. Opening truncates, so it is limited to temporary directories outside the repository."""
    if log is None:
        return os.open(os.devnull, os.O_WRONLY)
    path = Path(log).resolve()
    temp_dirs = list(dict.fromkeys([Path(tempfile.gettempdir()).resolve(), Path("/tmp").resolve()]))
    refusal = log_path_refusal(path, repo_root(), temp_dirs)
    if refusal:
        fail(f"--log {path} {refusal}")
    try:
        return os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    except OSError as error:
        fail(f"--log {path} cannot be opened: {error}")


class KeptState(StrEnum):
    # The file was left as someone else edited it; its original is set aside.
    EDITED_KEPT = "edited-kept"
    # The restore failed: the file may still hold the mutant.
    RESTORE_FAILED = "restore-failed"


def stop_with_record_kept(state: KeptState, message: str) -> NoReturn:
    emit({"outcome": Outcome.ERROR, "state": state, "error": message})
    sys.exit(3)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Apply one temporary source change, run a test command, and restore the file."
    )
    parser.add_argument("--file", help="Source file to change temporarily")
    parser.add_argument("--old", help="Exact snippet to replace; must occur once")
    parser.add_argument("--new", default="", help="Replacement snippet")
    parser.add_argument("--from-ref", help="Use the file's content at this git ref")
    parser.add_argument(
        "--killed-exit-codes",
        default="1",
        help="Comma-separated exit codes meaning tests ran and failed (pytest and Jest: 1)",
    )
    parser.add_argument(
        "--timeout", type=int, default=300, help="Seconds before the run counts as a timeout"
    )
    parser.add_argument("--log", help="Write the test output here")
    parser.add_argument(
        "--working-dir",
        default=".",
        help="Directory to run the test command in, inside the repository (e.g. frontend)",
    )
    parser.add_argument(
        "--allow-running-stack",
        action="store_true",
        help="Run even though this worktree's dev stack is up (integration tests need it)",
    )
    parser.add_argument("--restore-leftovers", action="store_true")
    parser.add_argument("cmd", nargs=argparse.REMAINDER, help="-- <test command>")
    args = parser.parse_args()

    if args.restore_leftovers:
        restore_leftovers()
        return

    cmd = args.cmd[1:] if args.cmd[:1] == ["--"] else args.cmd
    if not args.file or not cmd or (args.old is None) == (args.from_ref is None):
        fail("pass --file, exactly one of --old or --from-ref, and -- <test command>")
    try:
        killed_exit_codes = frozenset(int(code) for code in args.killed_exit_codes.split(","))
    except ValueError:
        fail(
            f"--killed-exit-codes must be comma-separated integers, got {args.killed_exit_codes!r}"
        )

    target = Path(args.file).resolve()
    root = repo_root()
    if not is_inside(target, root):
        fail(f"{target} is outside this repository")
    if is_repository_metadata(target, root, git_dir()):
        fail(f"{target} is git metadata, not source")
    # A backup copies the whole file into the git directory, so never take one
    # of an ignored file (.env, keys, local state): it is not source anyway.
    ignored = subprocess.run(
        ["git", "check-ignore", "-q", "--", str(target.relative_to(root))], cwd=root
    ).returncode
    if ignored == 0:
        fail(f"{target} is ignored by git, not tracked source")
    if ignored != 1:
        # Fail closed: an unclassified file might be a secret.
        fail(f"git check-ignore failed for {target} (exit {ignored})")
    working_dir = Path(args.working_dir).resolve()
    if not (working_dir.is_dir() and is_inside(working_dir, root)):
        fail(f"--working-dir {working_dir} must be a directory inside the repository")
    # Budget for the work before the test command starts (the dev-stack and
    # git queries); the deadline is rewritten when the command starts.
    lock_fd = hold_checkout_lock(run_seconds=args.timeout + PRE_TEST_SECONDS)
    # With the checkout lock held no other run is live, so any record is a
    # crashed run's mutant still in the tree, which would skew this run.
    pending = sorted(path.name for path in backup_dir().glob("*.json"))
    if pending:
        fail(f"a crashed run left backups {pending}; run --restore-leftovers first")
    # A crashed run's tests may still be running against the tree; they would
    # score this run's mutants too.
    if (backup_dir() / TEST_GROUP_FILE).exists():
        fail("a crashed run's tests may still be running; run --restore-leftovers first")
    refusal = None if args.allow_running_stack else dev_stack_refusal(root)
    if refusal:
        fail(refusal)
    log_fd = open_log(args.log)
    record_path = record_path_for(target)
    started = time.monotonic()
    outcome = Outcome.INTERRUPTED
    exit_code = None
    process = None
    write_error: OSError | None = None
    run_error: str | None = None
    recorded_test_group = False
    starting_test_command = False
    bytecode_dir: str | None = None
    for interrupting in INTERRUPTING_SIGNALS:
        signal.signal(interrupting, raise_keyboard_interrupt)
    try:
        original = target.read_bytes()
        mutant = compute_mutant(args, target, original)
        create_record(record_path, Backup(target.relative_to(root), original, sha256(mutant)))
    except (Exception, KeyboardInterrupt) as error:
        # Nothing has been written to the source file yet, so any failure or
        # interrupt here (a bad snippet or ref, undecodable source, a full disk,
        # Ctrl-C during git show) only needs a partial record removed.
        record_path.unlink(missing_ok=True)
        fail(f"{target}: {str(error) or 'interrupted before the mutant was written'}")
    # Nothing between the record above and the guarded block below: an
    # interrupt in a gap would leave the record without its cleanup.
    # The write is inside the guarded block so that no interrupt, however
    # it lands, can leave the mutant installed without the restore below.
    try:
        try:
            replace_contents(target, mutant, expected=original)
        except OSError as error:
            write_error = error
            raise
        remove_cached_bytecode(target)
        bytecode_dir = tempfile.mkdtemp(prefix=bytecode_dir_prefix(root))
        with os.fdopen(log_fd, "wb") as log:
            write_run_deadline(lock_fd, args.timeout)
            starting_test_command = True
            process = subprocess.Popen(
                cmd,
                stdout=log,
                stderr=subprocess.STDOUT,
                cwd=working_dir,
                env={
                    **os.environ,
                    "PYTHONDONTWRITEBYTECODE": "1",
                    # A cache of its own, so no bytecode in the checkout (stale
                    # or unremovable) can stand in for the mutant.
                    "PYTHONPYCACHEPREFIX": bytecode_dir,
                },
                start_new_session=True,
            )
            # Record the group at once (no start time yet: recovery reports such
            # a group and never kills it), then again once ps has answered, so
            # a kill during the ps call cannot leave the tests unrecorded.
            # Set before the ps call, so an interrupt during it still leaves
            # the run knowing it owns the record. Either write counts.
            recorded_test_group = record_test_group(process.pid, None)
            start = process_start_time(process.pid)
            if start is None:
                print(
                    "warning: could not read the test process start time; after a crash, "
                    "recovery will report the group instead of stopping it",
                    file=sys.stderr,
                )
            second_write = record_test_group(process.pid, start)
            recorded_test_group = recorded_test_group or second_write
            exit_code = process.wait(timeout=args.timeout)
        outcome = classify_exit(exit_code, killed_exit_codes)
        if outcome == Outcome.ERROR:
            run_error = (
                f"the test command exited {exit_code}, which is not a test-failure code "
                f"({', '.join(map(str, sorted(killed_exit_codes)))})"
            )
    except subprocess.TimeoutExpired:
        outcome = Outcome.TIMEOUT
    except (OSError, subprocess.SubprocessError) as error:
        outcome = Outcome.ERROR
        if starting_test_command:
            # The command itself could not start (missing, not executable).
            run_error = f"the test command could not start: {error}"
        else:
            run_error = f"could not prepare the test run (the source is restored): {error}"
    except KeyboardInterrupt:
        outcome = Outcome.INTERRUPTED
    finally:
        # A second interrupt during the restore could leave the file truncated.
        for interrupting in (signal.SIGINT, *INTERRUPTING_SIGNALS):
            signal.signal(interrupting, signal.SIG_IGN)
        if process and exit_code is None:
            stop_process_group(process)
        current = read_if_present(target)
        if process is not None and trusted_outcome(outcome, current, mutant) != outcome:
            outcome = Outcome.ERROR
            run_error = "the test command changed the file, so the tests may not have run against the mutant"
        cleanup = run_cleanup(
            current,
            original,
            mutant,
            mutant_write_failed=write_error is not None,
            test_started=process is not None,
        )
        if cleanup == RunCleanup.DISCARD_RECORD:
            with contextlib.suppress(OSError):
                record_path.unlink(missing_ok=True)
            reason = f"could not write the mutant: {write_error}" if write_error else "interrupted"
            fail(f"{target}: {reason}")
        # Nothing between here and the restore may exit or raise: the
        # mutant is still in the file.
        if recorded_test_group:
            try:
                (record_path.parent / TEST_GROUP_FILE).unlink(missing_ok=True)
            except OSError as error:
                print(f"warning: could not remove the test-group record: {error}", file=sys.stderr)
        if bytecode_dir is not None:
            shutil.rmtree(bytecode_dir, ignore_errors=True)
        if cleanup == RunCleanup.SET_ASIDE:
            # The run held the lock, so the record is dead but holds the only
            # copy of the original; set it aside so later runs are not blocked.
            stop_with_record_kept(
                KeptState.EDITED_KEPT,
                f"{target} was edited or deleted during the run; left as is, "
                f"original kept in {set_aside(record_path)}",
            )
        try:
            # Guard against the bytes run_cleanup just saw, not the mutant: a
            # test command may have rewritten the file back to the original
            # (a formatter, git checkout), which is still a restore, not an edit.
            restored = current is not None and restore_source(target, original, current)
        except OSError as error:
            stop_with_record_kept(
                KeptState.RESTORE_FAILED, f"restore failed ({error}); backup at {record_path}"
            )
        if not restored:
            stop_with_record_kept(
                KeptState.EDITED_KEPT,
                f"{target} was edited while the run ended; left as is, "
                f"original kept in {set_aside(record_path)}",
            )
        try:
            record_path.unlink(missing_ok=True)
        except OSError as error:
            print(f"warning: could not remove {record_path}: {error}", file=sys.stderr)

    result = {
        "outcome": outcome,
        "exit_code": exit_code,
        "seconds": round(time.monotonic() - started, 1),
        "file": str(target),
    }
    if run_error:
        result["error"] = run_error
    emit(result)


if __name__ == "__main__":
    main()
