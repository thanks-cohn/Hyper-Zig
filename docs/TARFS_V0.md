# ZIGN01D TARFS V0 / INITRD V0

TARFS V0 is the first tiny read-only file world embedded directly in the ZIGN01D kernel image. It exists so the kernel can list, inspect, read, and checksum real byte contents before the project grows an application ABI, WASM loader, boot image format, or phone shell file workflows.

This milestone is deliberately small and inspectable. It is not a production filesystem. It is a proof stone: the shell walks a real in-kernel file table, returns bytes from that table, reports sizes and checksums derived from those bytes, and rejects unsupported operations with stable breadcrumbs.

## What TARFS V0 implements

- A static read-only archive table in `kernel/fs/tarfs.zig`.
- Four embedded files with real byte contents:
  - `/hello.txt`
  - `/readme.txt`
  - `/apps/hello.app`
  - `/etc/zign01d-release`
- Shell commands:
  - `fs`
  - `fs list`
  - `fs stat /hello.txt`
  - `fs cat /hello.txt`
  - `fs checksum /hello.txt`
  - `fs cat /readme.txt`
  - `fs stat /missing.txt`
  - `fs cat /missing.txt`
  - `fs write-test`
- FNV-1a 32-bit checksums computed from embedded file bytes.
- Stable FS breadcrumbs:
  - `FS000` archive initialized
  - `FS001` file list requested
  - `FS002` file stat success
  - `FS003` file read success
  - `FS004` checksum success
  - `FS005` missing file rejected
  - `FS006` write rejected because read-only

## What TARFS V0 does not implement

TARFS V0 intentionally emits honest non-claims:

- `fs_write=not-implemented`
- `vfs_layer=implemented-mount-router-v0` (VFS now sits above TARFS; TARFS itself remains a read-only archive)
- `block_device_fs=not-implemented`
- `persistent_storage=not-implemented`
- `executable_apps=not-implemented`
- `wasm_loader=not-implemented`
- `userspace_loader=not-implemented`
- `permissions=not-implemented`
- `production_filesystem=not-implemented`

The `/apps/hello.app` record is manifest-like data only. It is not executable, not loaded as userspace, and not interpreted as WASM.

## Why this comes before apps, WASM, and phone shell work

A phone-oriented OS needs files before it can responsibly grow app manifests, boot images, recovery bundles, configuration, WASM modules, logs, and user-facing shell workflows. TARFS V0 is the smallest safe step: immutable bytes compiled into the kernel, no block driver dependency, no allocator dependency for file data, no persistence claims, and no permission model claims.

That ordering lets later milestones reuse proven concepts:

1. path lookup,
2. byte reads,
3. size reporting,
4. checksums,
5. missing-file rejection,
6. read-only write rejection,
7. stable diagnostic markers.

## How embedded files are defined

The archive is defined in `kernel/fs/tarfs.zig` as an array of file records. Each record contains:

- `path`
- `data`
- `checksum`

The shell does not hardcode `fs list`, `fs stat`, `fs cat`, or `fs checksum` output. It calls TARFS functions that walk the file table, find a matching path, and print values derived from the selected record.

## How to run the smoke test

Run only this milestone:

```sh
./smoke/smoke-tarfs-v0.sh
```

Run the full ladder, including TARFS V0 after PMM V0:

```sh
./smoke/smoke-all.sh
```

The TARFS smoke test builds the kernel, boots QEMU, waits for the shell prompt, runs the required `fs` commands, validates all required markers, independently computes the expected FNV-1a checksum for `/hello.txt`, proves the exact content `hello from zign01d tarfs`, rejects forbidden fake-success claims, and prints exactly:

```text
PASS ZIGN01D TARFS V0 smoke
```

## Missing-file and write rejection breadcrumbs

A missing file must not be silently accepted. For `/missing.txt`, TARFS emits:

```text
[ZIGN01D][WARN][FS][FS005] missing file rejected path=/missing.txt reason=not-found
fs_missing_rejected=yes
fs_last_error=not-found
attempted_path=/missing.txt
```

A write attempt must not be presented as supported. `fs write-test` emits:

```text
[ZIGN01D][WARN][FS][FS006] write rejected path=/hello.txt reason=read-only
fs_write_rejected=yes
fs_last_error=read-only
fs_write=not-implemented
```

These breadcrumbs are part of the proof contract: failure paths must identify what was attempted, why it failed, and which stable error code points to the code path.
