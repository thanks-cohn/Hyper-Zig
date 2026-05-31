#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-ramfs-v0.log"
QEMU_LOG="$LOG_DIR/qemu-ramfs-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-ramfs-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-ramfs-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][RAMFS001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][RAMFS099] RAMFS V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: RAMFS marker/real write-read-append/delete/checksum/capacity/overflow proof missing"
        echo "  inspect next: kernel/fs/ramfs.zig kernel/console/shell.zig docs/RAMFS_V0.md"
    } | tee -a "$SMOKE_LOG" >&2
}
fail() { echo "FAIL $*" | tee -a "$SMOKE_LOG"; fail_note; exit 1; }
require() {
    local marker="$1"
    if LC_ALL=C grep -aFq "$marker" "$TRANSCRIPT"; then
        echo "PASS marker: $marker" | tee -a "$SMOKE_LOG"
    else
        fail "missing marker: $marker"
    fi
}
reject() {
    local marker="$1"
    if LC_ALL=C grep -aFq "$marker" "$TRANSCRIPT"; then
        fail "forbidden fake success claim: $marker"
    fi
    echo "PASS forbidden absent: $marker" | tee -a "$SMOKE_LOG"
}

log "running build"
if ! "$ROOT/scripts/build.sh" >>"$SMOKE_LOG" 2>&1; then
    fail_note
    exit 1
fi

[[ -f "$ELF" ]] || fail "missing kernel ELF: $ELF"
command -v qemu-system-riscv64 >/dev/null 2>&1 || fail "qemu-system-riscv64 not found"

QEMU_CMD=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
printf '[%s][ZIGN01D][INFO][QEMU][RAMFS001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching RAMFS V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os
import selectors
import subprocess
import sys
import time

transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = [
    "help",
    "ramfs",
    "ramfs stats",
    "ramfs list",
    "ramfs create /ram/hello.txt",
    "ramfs create /ram/hello.txt",
    "ramfs write /ram/hello.txt \"hello from zign01d ramfs\"",
    "ramfs cat /ram/hello.txt",
    "ramfs append /ram/hello.txt \" appended\"",
    "ramfs cat /ram/hello.txt",
    "ramfs stat /ram/hello.txt",
    "ramfs checksum /ram/hello.txt",
    "ramfs list",
    "ramfs delete /ram/hello.txt",
    "ramfs cat /ram/hello.txt",
    "ramfs missing-test",
    "ramfs capacity-test",
    "ramfs overflow-test",
    "ramfs stats",
    "shutdown",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel = selectors.DefaultSelector()
sel.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray()
ready = False
status = 124
deadline = time.monotonic() + 30.0
with open(transcript, "wb") as out:
    try:
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                status = proc.returncode
                break
            for key, _ in sel.select(timeout=0.05):
                chunk = key.fileobj.read()
                if chunk:
                    out.write(chunk)
                    out.flush()
                    seen.extend(chunk)
            if not ready and b"zign01d> " in seen:
                ready = True
                for item in commands:
                    proc.stdin.write((item + "\n").encode())
                    proc.stdin.flush()
                    time.sleep(0.1)
            if ready and proc.poll() is not None:
                status = proc.returncode
                break
        else:
            status = 124
    finally:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=2)
            except subprocess.TimeoutExpired:
                proc.kill()
        while True:
            try:
                chunk = proc.stdout.read()
            except Exception:
                chunk = b""
            if not chunk:
                break
            out.write(chunk)
        if not ready and status == 0:
            status = 125
sys.exit(status)
PYSMOKE
QEMU_STATUS=$?
set -e

cat "$TRANSCRIPT" >> "$QEMU_LOG"
cp "$TRANSCRIPT" "$TRANSCRIPT_COPY"

[[ $QEMU_STATUS -eq 0 ]] || fail "qemu exited with status $QEMU_STATUS"
[[ -s "$TRANSCRIPT" ]] || fail "boot transcript missing or empty"

for marker in \
    'zign01d>' \
    '[ZIGN01D][INFO][RAMFS][RAMFS000] initialized root=/ram capacity_files=8 max_file_bytes=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS001] stats requested root=/ram' \
    '[ZIGN01D][INFO][RAMFS][RAMFS002] list requested root=/ram file_count=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS003] create success path=/ram/hello.txt file_count=' \
    '[ZIGN01D][WARN][RAMFS][RAMFS010] duplicate create rejected path=/ram/hello.txt reason=already-exists' \
    '[ZIGN01D][INFO][RAMFS][RAMFS004] write success path=/ram/hello.txt bytes=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS005] read success path=/ram/hello.txt bytes=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS006] append success path=/ram/hello.txt append_bytes=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS007] stat success path=/ram/hello.txt bytes=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS008] checksum success path=/ram/hello.txt checksum=' \
    '[ZIGN01D][INFO][RAMFS][RAMFS009] delete success path=/ram/hello.txt file_count=' \
    '[ZIGN01D][WARN][RAMFS][RAMFS010] missing path rejected path=/ram/hello.txt reason=not-found' \
    '[ZIGN01D][WARN][RAMFS][RAMFS011] capacity rejected reason=capacity-full' \
    '[ZIGN01D][WARN][RAMFS][RAMFS012] overflow rejected reason=file-too-large' \
    'commands:' \
    'ramfs stats' \
    'ramfs list' \
    'ramfs create' \
    'ramfs write' \
    'ramfs cat' \
    'ramfs append' \
    'ramfs stat' \
    'ramfs checksum' \
    'ramfs delete' \
    'ramfs missing-test' \
    'ramfs capacity-test' \
    'ramfs overflow-test' \
    'ramfs_interface=present' \
    'ramfs_kind=volatile-memory-v0' \
    'ramfs_root=/ram' \
    'ramfs_capacity_files=8' \
    'ramfs_max_file_bytes=' \
    'ramfs_file_count=' \
    'ramfs_total_bytes=' \
    'ramfs_readonly=no' \
    'ramfs_persistent=no' \
    'ramfs_backing=kernel-memory' \
    'ramfs_create_count=' \
    'ramfs_write_count=' \
    'ramfs_append_count=' \
    'ramfs_read_count=' \
    'ramfs_delete_count=' \
    'ramfs_missing_count=' \
    'ramfs_capacity_reject_count=' \
    'ramfs_overflow_reject_count=' \
    'ramfs_last_error=' \
    'ramfs_duplicate_create=rejects-already-exists' \
    'ramfs_duplicate_create_rejected=yes' \
    'ramfs_last_error=already-exists' \
    'ramfs_create_ok=yes' \
    'ramfs_write_ok=yes' \
    'ramfs_cat_ok=yes' \
    'ramfs_append_ok=yes' \
    'ramfs_stat_ok=yes' \
    'ramfs_checksum_ok=yes' \
    'ramfs_delete_ok=yes' \
    'ramfs_missing_rejected=yes' \
    'ramfs_capacity_rejected=yes' \
    'ramfs_overflow_rejected=yes' \
    'ramfs_cat_path=/ram/hello.txt' \
    'ramfs_cat_bytes=' \
    'hello from zign01d ramfs' \
    'hello from zign01d ramfs appended' \
    'ramfs_stat_path=/ram/hello.txt' \
    'ramfs_stat_size=' \
    'ramfs_stat_checksum=' \
    'ramfs_checksum_path=/ram/hello.txt' \
    'ramfs_checksum=' \
    'ramfs_last_error=not-found' \
    'attempted_path=/ram/hello.txt' \
    'ramfs_last_error=capacity-full' \
    'ramfs_last_error=file-too-large' \
    'persistent_storage=not-implemented' \
    'block_device_fs=not-implemented' \
    'vfs=not-implemented' \
    'journaling=not-implemented' \
    'permissions=not-implemented' \
    'directories=limited-or-not-implemented' \
    'executable_apps=not-implemented' \
    'wasm_loader=not-implemented' \
    'userspace_loader=not-implemented' \
    'production_filesystem=not-implemented'
do
    require "$marker"
done

log "validating exact write, append, delete, and independent FNV-1a checksum proof"
set +e
python3 - "$TRANSCRIPT" <<'PYCHECK'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
initial = b"hello from zign01d ramfs"
final = b"hello from zign01d ramfs appended"

def fnv1a(data):
    h = 2166136261
    for b in data:
        h ^= b
        h = (h * 16777619) & 0xffffffff
    return h

if "\nhello from zign01d ramfs\r\n" not in text and "\nhello from zign01d ramfs\n" not in text:
    print("exact initial write content line missing")
    sys.exit(1)
if "\nhello from zign01d ramfs appended\r\n" not in text and "\nhello from zign01d ramfs appended\n" not in text:
    print("exact appended content line missing")
    sys.exit(1)

cat_matches = re.findall(r"ramfs_cat_path=/ram/hello\.txt\s+ramfs_cat_bytes=(\d+)\s+([^\r\n]+)", text)
if len(cat_matches) < 2:
    print("expected at least two successful cat proofs for /ram/hello.txt")
    sys.exit(1)
if int(cat_matches[0][0]) != len(initial) or cat_matches[0][1].strip() != initial.decode():
    print(f"initial cat mismatch: {cat_matches[0]!r}")
    sys.exit(1)
if int(cat_matches[1][0]) != len(final) or cat_matches[1][1].strip() != final.decode():
    print(f"appended cat mismatch: {cat_matches[1]!r}")
    sys.exit(1)

expected_checksum = fnv1a(final)
checksum_matches = re.findall(r"ramfs_checksum_path=/ram/hello\.txt\s+ramfs_checksum=(\d+)", text)
if not checksum_matches:
    print("ramfs checksum output missing")
    sys.exit(1)
actual_checksum = int(checksum_matches[-1])
if actual_checksum != expected_checksum:
    print(f"checksum mismatch: actual={actual_checksum} expected={expected_checksum}")
    sys.exit(1)

stat = re.search(r"ramfs_stat_path=/ram/hello\.txt\s+ramfs_stat_size=(\d+)\s+ramfs_stat_checksum=(\d+)", text)
if not stat:
    print("stat proof missing")
    sys.exit(1)
if int(stat.group(1)) != len(final) or int(stat.group(2)) != expected_checksum:
    print(f"stat size/checksum mismatch: size={stat.group(1)} checksum={stat.group(2)} expected_size={len(final)} expected_checksum={expected_checksum}")
    sys.exit(1)

delete_pos = text.find("ramfs_delete_ok=yes")
missing_pos = text.find("[ZIGN01D][WARN][RAMFS][RAMFS010] missing path rejected path=/ram/hello.txt reason=not-found")
if delete_pos < 0 or missing_pos < 0 or missing_pos < delete_pos:
    print("delete did not precede missing read rejection for /ram/hello.txt")
    sys.exit(1)
print(f"PASS RAMFS V0 checksum proof path=/ram/hello.txt size={len(final)} checksum={expected_checksum}")
PYCHECK
CHECK_STATUS=$?
set -e
[[ $CHECK_STATUS -eq 0 ]] || fail "independent RAMFS behavior/checksum proof failed"

for marker in \
    'persistent_storage=implemented' \
    'block_device_fs=implemented' \
    'vfs=implemented' \
    'journaling=implemented' \
    'permissions=implemented' \
    'executable_apps=implemented' \
    'wasm_loader=implemented' \
    'userspace_loader=implemented' \
    'production_filesystem=implemented' \
    'fake_ramfs_success' \
    'ramfs_placeholder_only' \
    'missing_read_accepted' \
    'capacity_overflow_accepted' \
    'file_overflow_accepted'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D RAMFS V0 smoke"
