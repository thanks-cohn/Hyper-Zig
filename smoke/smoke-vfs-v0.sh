#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_DIR="$ROOT/logs/latest"
SMOKE_LOG="$LOG_DIR/smoke-vfs-v0.log"
QEMU_LOG="$LOG_DIR/qemu-vfs-v0.log"
BUILD_LOG="$LOG_DIR/build.log"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-vfs-v0.txt"
TRANSCRIPT_COPY="$LOG_DIR/qemu-smoke-vfs-v0-transcript.txt"
ELF="$ROOT/zig-out/bin/zign01d-v0"

mkdir -p "$LOG_DIR" "$ROOT/smoke/transcripts"
: > "$SMOKE_LOG"
: > "$QEMU_LOG"
: > "$TRANSCRIPT"

stamp() { date -u '+%Y-%m-%dT%H:%M:%SZ'; }
log() { printf '[%s][ZIGN01D][INFO][SMOKE][VFS001] %s\n' "$(stamp)" "$*" | tee -a "$SMOKE_LOG"; }
fail_note() {
    {
        echo "[ZIGN01D][ERROR][SMOKE][VFS099] VFS V0 smoke failure evidence:"
        echo "  build.log: $BUILD_LOG"
        echo "  qemu.log: $QEMU_LOG"
        echo "  smoke.log: $SMOKE_LOG"
        echo "  transcript: $TRANSCRIPT"
        echo "  likely cause: VFS routing/content/checksum/rejection proof missing or fake maturity claim present"
        echo "  inspect next: kernel/fs/vfs.zig kernel/fs/tarfs.zig kernel/fs/ramfs.zig kernel/console/shell.zig docs/VFS_V0.md"
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
printf '[%s][ZIGN01D][INFO][QEMU][VFS001] command:' "$(stamp)" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf ' %q' "${QEMU_CMD[@]}" | tee -a "$QEMU_LOG" "$SMOKE_LOG"
printf '\n' | tee -a "$QEMU_LOG" "$SMOKE_LOG"

log "launching VFS V0 controlled qemu session and waiting for shell readiness"
set +e
python3 - "$TRANSCRIPT" "${QEMU_CMD[@]}" <<'PYSMOKE'
import os, selectors, subprocess, sys, time
transcript = sys.argv[1]
cmd = sys.argv[2:]
commands = [
    "help",
    "vfs",
    "vfs mounts",
    "vfs route /hello.txt",
    "vfs route /ram/hello.txt",
    "vfs list /",
    "vfs list /ram",
    "vfs stat /hello.txt",
    "vfs cat /hello.txt",
    "vfs checksum /hello.txt",
    "vfs create /ram/hello.txt",
    "vfs write /ram/hello.txt \"hello from zign01d vfs ram\"",
    "vfs cat /ram/hello.txt",
    "vfs append /ram/hello.txt \" appended\"",
    "vfs cat /ram/hello.txt",
    "vfs stat /ram/hello.txt",
    "vfs checksum /ram/hello.txt",
    "vfs delete /ram/hello.txt",
    "vfs cat /ram/hello.txt",
    "vfs write /hello.txt \"must fail\"",
    "vfs cat /missing.txt",
    "vfs route /unknown/path",
    "shutdown",
]
proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
os.set_blocking(proc.stdout.fileno(), False)
sel = selectors.DefaultSelector(); sel.register(proc.stdout, selectors.EVENT_READ)
seen = bytearray(); ready = False; status = 124; deadline = time.monotonic() + 30.0
with open(transcript, "wb") as out:
    try:
        while time.monotonic() < deadline:
            if proc.poll() is not None:
                status = proc.returncode; break
            for key, _ in sel.select(timeout=0.05):
                chunk = key.fileobj.read()
                if chunk:
                    out.write(chunk); out.flush(); seen.extend(chunk)
            if not ready and b"zign01d> " in seen:
                ready = True
                for item in commands:
                    proc.stdin.write((item + "\n").encode()); proc.stdin.flush(); time.sleep(0.1)
            if ready and proc.poll() is not None:
                status = proc.returncode; break
        else:
            status = 124
    finally:
        if proc.poll() is None:
            proc.terminate()
            try: proc.wait(timeout=2)
            except subprocess.TimeoutExpired: proc.kill()
        while True:
            try: chunk = proc.stdout.read()
            except Exception: chunk = b""
            if not chunk: break
            out.write(chunk)
        if not ready and status == 0: status = 125
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
    '[ZIGN01D][INFO][VFS][VFS000] initialized mount_count=2 root=/ ram=/ram' \
    '[ZIGN01D][INFO][VFS][VFS001] mount table requested mount_count=2' \
    '[ZIGN01D][INFO][VFS][VFS002] route success path=/hello.txt fs=tarfs-readonly-v0 mount=/' \
    '[ZIGN01D][INFO][VFS][VFS002] route success path=/ram/hello.txt fs=ramfs-volatile-memory-v0 mount=/ram' \
    '[ZIGN01D][INFO][VFS][VFS003] list routed path=/ fs=tarfs-readonly-v0 mount=/' \
    '[ZIGN01D][INFO][VFS][VFS003] list routed path=/ram fs=ramfs-volatile-memory-v0 mount=/ram' \
    '[ZIGN01D][INFO][VFS][VFS004] stat routed path=/hello.txt fs=tarfs-readonly-v0 bytes=' \
    '[ZIGN01D][INFO][VFS][VFS005] read routed path=/hello.txt fs=tarfs-readonly-v0 bytes=' \
    '[ZIGN01D][INFO][VFS][VFS006] checksum routed path=/hello.txt fs=tarfs-readonly-v0 checksum=' \
    '[ZIGN01D][INFO][VFS][VFS007] create routed path=/ram/hello.txt fs=ramfs-volatile-memory-v0' \
    '[ZIGN01D][INFO][VFS][VFS008] write routed path=/ram/hello.txt fs=ramfs-volatile-memory-v0 bytes=' \
    '[ZIGN01D][INFO][VFS][VFS009] append routed path=/ram/hello.txt fs=ramfs-volatile-memory-v0 bytes=' \
    '[ZIGN01D][INFO][VFS][VFS010] delete routed path=/ram/hello.txt fs=ramfs-volatile-memory-v0' \
    '[ZIGN01D][WARN][VFS][VFS011] missing path rejected path=/missing.txt reason=not-found' \
    '[ZIGN01D][WARN][VFS][VFS011] missing path rejected path=/ram/hello.txt reason=not-found' \
    '[ZIGN01D][WARN][VFS][VFS012] read-only write rejected path=/hello.txt fs=tarfs-readonly-v0 reason=read-only' \
    '[ZIGN01D][WARN][VFS][VFS013] invalid/no mount rejected path=/unknown/path reason=no-mount' \
    'commands:' \
    'vfs mounts' \
    'vfs route' \
    'vfs list' \
    'vfs stat' \
    'vfs cat' \
    'vfs checksum' \
    'vfs create' \
    'vfs write' \
    'vfs append' \
    'vfs delete' \
    'vfs_interface=present' \
    'vfs_kind=mount-router-v0' \
    'vfs_mount_count=2' \
    'vfs_mount path=/ fs=tarfs-readonly-v0 readonly=yes' \
    'vfs_mount path=/ram fs=ramfs-volatile-memory-v0 readonly=no' \
    'vfs_longest_prefix_match=yes' \
    'vfs_root=/' \
    'vfs_ram_mount=/ram' \
    'vfs_route_ok=yes' \
    'vfs_route_path=/hello.txt' \
    'vfs_route_fs=tarfs-readonly-v0' \
    'vfs_route_path=/ram/hello.txt' \
    'vfs_route_fs=ramfs-volatile-memory-v0' \
    'vfs_list_ok=yes' \
    'vfs_stat_ok=yes' \
    'vfs_cat_ok=yes' \
    'vfs_checksum_ok=yes' \
    'vfs_create_ok=yes' \
    'vfs_write_ok=yes' \
    'vfs_append_ok=yes' \
    'vfs_delete_ok=yes' \
    'vfs_missing_rejected=yes' \
    'vfs_readonly_write_rejected=yes' \
    'vfs_invalid_mount_rejected=yes' \
    'vfs_last_error=' \
    'attempted_path=/hello.txt' \
    'routed_fs=tarfs-readonly-v0' \
    'attempted_path=/missing.txt' \
    'attempted_path=/unknown/path' \
    'persistent_storage=not-implemented' \
    'block_device_fs=not-implemented' \
    'journaling=not-implemented' \
    'permissions=not-implemented' \
    'symlinks=not-implemented' \
    'hardlinks=not-implemented' \
    'userspace_loader=not-implemented' \
    'executable_apps=not-implemented' \
    'wasm_loader=not-implemented' \
    'production_filesystem=not-implemented' \
    'vfs_route_count=' \
    'vfs_list_count=' \
    'vfs_stat_count=' \
    'vfs_read_count=' \
    'vfs_checksum_count=' \
    'vfs_create_count=' \
    'vfs_write_count=' \
    'vfs_append_count=' \
    'vfs_delete_count=' \
    'vfs_missing_count=' \
    'vfs_readonly_reject_count=' \
    'vfs_invalid_mount_count=' \
    'hello from zign01d tarfs' \
    'hello from zign01d vfs ram' \
    'hello from zign01d vfs ram appended'
do
    require "$marker"
done

log "validating exact routed content, delete, rejection ordering, and independent FNV-1a checksums"
set +e
python3 - "$TRANSCRIPT" <<'PYCHECK'
import re, sys
from pathlib import Path
text = Path(sys.argv[1]).read_text(errors="replace")
tar = b"hello from zign01d tarfs"
initial = b"hello from zign01d vfs ram"
final = b"hello from zign01d vfs ram appended"
def fnv1a(data):
    h = 2166136261
    for b in data:
        h ^= b
        h = (h * 16777619) & 0xffffffff
    return h

def need(cond, msg):
    if not cond:
        print(msg); sys.exit(1)
need("\nhello from zign01d tarfs\r\n" in text or "\nhello from zign01d tarfs\n" in text, "exact TARFS content through VFS missing")
need("\nhello from zign01d vfs ram\r\n" in text or "\nhello from zign01d vfs ram\n" in text, "exact initial RAMFS content through VFS missing")
need("\nhello from zign01d vfs ram appended\r\n" in text or "\nhello from zign01d vfs ram appended\n" in text, "exact appended RAMFS content through VFS missing")
need(re.search(r"vfs_route_path=/hello\.txt\s+vfs_route_fs=tarfs-readonly-v0", text), "TARFS route proof missing")
need(re.search(r"vfs_route_path=/ram/hello\.txt\s+vfs_route_fs=ramfs-volatile-memory-v0", text), "RAMFS route proof missing")
need(re.search(r"vfs_cat_path=/hello\.txt\s+vfs_cat_bytes=%d\s+hello from zign01d tarfs" % len(tar), text), "TARFS cat bytes/content proof mismatch")
ram_cats = re.findall(r"vfs_cat_path=/ram/hello\.txt\s+vfs_cat_bytes=(\d+)\s+([^\r\n]+)", text)
need(len(ram_cats) >= 2, "expected two RAMFS cat proofs through VFS")
need(int(ram_cats[0][0]) == len(initial) and ram_cats[0][1].strip() == initial.decode(), f"initial RAMFS cat mismatch: {ram_cats[0]!r}")
need(int(ram_cats[1][0]) == len(final) and ram_cats[1][1].strip() == final.decode(), f"appended RAMFS cat mismatch: {ram_cats[1]!r}")
tar_sum = fnv1a(tar)
ram_sum = fnv1a(final)
tar_checksum = re.findall(r"vfs_checksum_path=/hello\.txt\s+vfs_checksum=(\d+)", text)
need(tar_checksum and int(tar_checksum[-1]) == tar_sum, f"TARFS checksum mismatch expected={tar_sum} actual={tar_checksum[-1] if tar_checksum else 'missing'}")
ram_checksum = re.findall(r"vfs_checksum_path=/ram/hello\.txt\s+vfs_checksum=(\d+)", text)
need(ram_checksum and int(ram_checksum[-1]) == ram_sum, f"RAMFS checksum mismatch expected={ram_sum} actual={ram_checksum[-1] if ram_checksum else 'missing'}")
ram_stat = re.search(r"vfs_stat_path=/ram/hello\.txt\s+vfs_stat_size=(\d+)\s+vfs_stat_checksum=(\d+)", text)
need(ram_stat and int(ram_stat.group(1)) == len(final) and int(ram_stat.group(2)) == ram_sum, "RAMFS stat checksum/size mismatch")
tar_stat = re.search(r"vfs_stat_path=/hello\.txt\s+vfs_stat_size=(\d+)\s+vfs_stat_checksum=(\d+)", text)
need(tar_stat and int(tar_stat.group(1)) == len(tar) and int(tar_stat.group(2)) == tar_sum, "TARFS stat checksum/size mismatch")
delete_pos = text.find("vfs_delete_ok=yes")
missing_ram_pos = text.find("[ZIGN01D][WARN][VFS][VFS011] missing path rejected path=/ram/hello.txt reason=not-found")
need(delete_pos >= 0 and missing_ram_pos > delete_pos, "delete did not precede missing read rejection for /ram/hello.txt")
readonly_pos = text.find("vfs_readonly_write_rejected=yes")
need(readonly_pos >= 0 and "vfs_last_error=read-only" in text[readonly_pos:readonly_pos+200], "read-only rejection details missing")
missing_pos = text.find("[ZIGN01D][WARN][VFS][VFS011] missing path rejected path=/missing.txt reason=not-found")
need(missing_pos >= 0 and "vfs_last_error=not-found" in text[missing_pos:missing_pos+200], "missing path rejection details missing")
invalid_pos = text.find("[ZIGN01D][WARN][VFS][VFS013] invalid/no mount rejected path=/unknown/path reason=no-mount")
need(invalid_pos >= 0 and "vfs_last_error=no-mount" in text[invalid_pos:invalid_pos+200], "invalid/no mount rejection details missing")
print(f"PASS VFS V0 checksum proof tarfs={tar_sum} ramfs={ram_sum}")
PYCHECK
CHECK_STATUS=$?
set -e
[[ $CHECK_STATUS -eq 0 ]] || fail "independent VFS behavior/checksum proof failed"

for marker in \
    'persistent_storage=implemented' \
    'block_device_fs=implemented' \
    'journaling=implemented' \
    'permissions=implemented' \
    'symlinks=implemented' \
    'hardlinks=implemented' \
    'userspace_loader=implemented' \
    'executable_apps=implemented' \
    'wasm_loader=implemented' \
    'production_filesystem=implemented' \
    'fake_vfs_success' \
    'vfs_placeholder_only' \
    'readonly_write_accepted' \
    'missing_file_accepted' \
    'invalid_mount_accepted'
do
    reject "$marker"
done

log "smoke passed; transcript=$TRANSCRIPT"
echo "PASS ZIGN01D VFS V0 smoke"
