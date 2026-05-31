#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-tarfs-v0.log"
QEMU_LOG="$LOG_DIR/qemu-tarfs-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-tarfs-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-tarfs-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][FS001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][FS099] TARFS V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: FS000 marker/fs command/table walk/checksum/rejection missing or fake maturity claim present"
        echo "  inspect next: kernel/fs/tarfs.zig kernel/console/shell.zig docs/TARFS_V0.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][FS001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching TARFS V0 controlled qemu session and waiting for shell readiness"
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
    "status",
    "fs",
    "fs list",
    "fs stat /hello.txt",
    "fs cat /hello.txt",
    "fs checksum /hello.txt",
    "fs cat /readme.txt",
    "fs stat /missing.txt",
    "fs cat /missing.txt",
    "fs write-test",
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
    '[ZIGN01D][INFO][FS][FS000] tarfs initialized file_count=4 total_bytes=' \
    '[ZIGN01D][INFO][FS][FS001] file list requested root=/ file_count=4' \
    '[ZIGN01D][INFO][FS][FS002] stat success path=/hello.txt bytes=' \
    '[ZIGN01D][INFO][FS][FS003] read success path=/hello.txt bytes=' \
    '[ZIGN01D][INFO][FS][FS004] checksum success path=/hello.txt checksum=' \
    '[ZIGN01D][WARN][FS][FS005] missing file rejected path=/missing.txt reason=not-found' \
    '[ZIGN01D][WARN][FS][FS006] write rejected path=/hello.txt reason=read-only' \
    'commands:' \
    'fs list' \
    'fs stat' \
    'fs cat' \
    'fs checksum' \
    'fs write-test' \
    'fs_interface=present' \
    'fs_kind=tarfs-readonly-v0' \
    'fs_file_count=4' \
    'fs_total_bytes=' \
    'fs_readonly=yes' \
    'fs_write=not-implemented' \
    'fs_mount_count=1' \
    'fs_root=/' \
    'fs_file path=/hello.txt' \
    'fs_file path=/readme.txt' \
    'fs_file path=/apps/hello.app' \
    'fs_file path=/etc/zign01d-release' \
    'fs_list_ok=yes' \
    'fs_stat_ok=yes' \
    'fs_stat_path=/hello.txt' \
    'fs_stat_size=' \
    'fs_stat_checksum=' \
    'fs_cat_ok=yes' \
    'fs_cat_path=/hello.txt' \
    'fs_cat_bytes=' \
    'hello from zign01d tarfs' \
    'ZIGN01D TARFS V0' \
    'fs_checksum_ok=yes' \
    'fs_checksum_path=/hello.txt' \
    'fs_checksum=' \
    'fs_missing_rejected=yes' \
    'fs_last_error=not-found' \
    'attempted_path=/missing.txt' \
    'fs_write_rejected=yes' \
    'fs_last_error=read-only' \
    'vfs_layer=implemented-mount-router-v0' \
    'block_device_fs=not-implemented' \
    'persistent_storage=not-implemented' \
    'executable_apps=not-implemented' \
    'wasm_loader=not-implemented' \
    'userspace_loader=not-implemented' \
    'permissions=not-implemented' \
    'production_filesystem=not-implemented'
do
    require "$marker"
done

log "validating exact hello size and checksum with independent FNV-1a computation"
set +e
python3 - "$TRANSCRIPT" <<'PYCHECK'
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(errors="replace")
hello = b"hello from zign01d tarfs"
expected_size = len(hello)
h = 2166136261
for b in hello:
    h ^= b
    h = (h * 16777619) & 0xffffffff
expected_checksum = h

if "\nhello from zign01d tarfs\r\n" not in text and "\nhello from zign01d tarfs\n" not in text:
    print("exact hello content line missing")
    sys.exit(1)

size_match = re.search(r"fs_stat_path=/hello\.txt\s+fs_stat_size=(\d+)", text)
if not size_match:
    print("fs_stat_size for /hello.txt missing")
    sys.exit(1)
actual_size = int(size_match.group(1))
if actual_size <= 0 or actual_size != expected_size:
    print(f"unexpected stat size: actual={actual_size} expected={expected_size}")
    sys.exit(1)

cat_match = re.search(r"fs_cat_path=/hello\.txt\s+fs_cat_bytes=(\d+)", text)
if not cat_match:
    print("fs_cat_bytes for /hello.txt missing")
    sys.exit(1)
actual_cat_bytes = int(cat_match.group(1))
if actual_cat_bytes != expected_size:
    print(f"unexpected cat bytes: actual={actual_cat_bytes} expected={expected_size}")
    sys.exit(1)

checksum_matches = re.findall(r"fs_checksum_path=/hello\.txt\s+fs_checksum=(\d+)", text)
if not checksum_matches:
    print("fs_checksum for /hello.txt missing")
    sys.exit(1)
actual_checksum = int(checksum_matches[-1])
if actual_checksum != expected_checksum:
    print(f"checksum mismatch: actual={actual_checksum} expected={expected_checksum}")
    sys.exit(1)

stat_checksum = re.search(r"fs_stat_path=/hello\.txt\s+fs_stat_size=\d+\s+fs_stat_checksum=(\d+)", text)
if not stat_checksum or int(stat_checksum.group(1)) != expected_checksum:
    print("stat checksum missing or mismatched")
    sys.exit(1)

if text.count("fs_missing_rejected=yes") < 2:
    print("expected both stat and cat missing-file rejections")
    sys.exit(1)
print(f"PASS checksum proof path=/hello.txt size={expected_size} checksum={expected_checksum}")
PYCHECK
CHECK_STATUS=$?
set -e
[[ $CHECK_STATUS -eq 0 ]] || fail "independent content/checksum proof failed"

for marker in \
    'fs_write=implemented' \
    'block_device_fs=implemented' \
    'persistent_storage=implemented' \
    'executable_apps=implemented' \
    'wasm_loader=implemented' \
    'userspace_loader=implemented' \
    'permissions=implemented' \
    'production_filesystem=implemented' \
    'fake_fs_success' \
    'fs_placeholder_only' \
    'missing_file_accepted' \
    'write_accepted'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D TARFS V0 smoke"
