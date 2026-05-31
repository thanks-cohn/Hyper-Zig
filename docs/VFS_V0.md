# ZIGN01D VFS V0

VFS V0 is the first virtual filesystem routing layer in ZIGN01D. It does not store bytes itself. It sits above the existing TARFS V0 and RAMFS V0 filesystems and dispatches shell file operations to one of them by mount path.

## What VFS V0 implements

- A small, inspectable mount table with two mounts:
  - `/` -> `tarfs-readonly-v0`, read-only embedded TARFS records.
  - `/ram` -> `ramfs-volatile-memory-v0`, writable volatile RAMFS records.
- Longest-prefix routing, so `/ram/hello.txt` is routed to RAMFS before the root `/` TARFS fallback is considered.
- One `vfs` shell interface for routed operations:
  - `vfs mounts`
  - `vfs route <path>`
  - `vfs list <path>`
  - `vfs stat <path>`
  - `vfs cat <path>`
  - `vfs checksum <path>`
  - `vfs create <path>`
  - `vfs write <path> <bytes>`
  - `vfs append <path> <bytes>`
  - `vfs delete <path>`
- Stable breadcrumbs and counters for route, list, stat, read, checksum, create, write, append, delete, missing-path, read-only, and invalid/no-mount outcomes.
- Honest rejection of writes routed to the read-only TARFS mount.
- Honest rejection of missing files and invalid/no-mount routes.

## What VFS V0 does not implement

VFS V0 is not a production filesystem. It intentionally reports these non-claims:

- `persistent_storage=not-implemented`
- `block_device_fs=not-implemented`
- `journaling=not-implemented`
- `permissions=not-implemented`
- `symlinks=not-implemented`
- `hardlinks=not-implemented`
- `userspace_loader=not-implemented`
- `executable_apps=not-implemented`
- `wasm_loader=not-implemented`
- `production_filesystem=not-implemented`

The router does not add persistence, a block device, path permissions, users, app execution, a WASM loader, or a mature directory model.

## How VFS differs from TARFS and RAMFS

TARFS V0 owns the embedded read-only file records under `/`, including `/hello.txt`. RAMFS V0 owns volatile writable files under `/ram`. VFS V0 owns neither storage backing. Its job is choosing the correct lower filesystem and preserving the lower filesystem's semantics:

- TARFS files can be read, listed, statted, and checksummed through VFS.
- RAMFS files can be created, written, appended, read, statted, checksummed, and deleted through VFS.
- TARFS write attempts through VFS are rejected with `VFS012` and `vfs_last_error=read-only`.

## Why VFS is needed next

A phone-oriented, WASM-native system eventually needs package staging, logs-as-files, app ABI discovery, WASM hosting, and user programs. Those features should not need to know whether a path is backed by embedded boot files, volatile RAM, future logs, future package staging, or a future block filesystem. VFS V0 is the small routing seam that makes those later layers possible without pretending those later layers already exist.

## Mount table behavior

`vfs mounts` prints the current table:

```text
vfs_mount_count=2
vfs_mount path=/ fs=tarfs-readonly-v0 readonly=yes
vfs_mount path=/ram fs=ramfs-volatile-memory-v0 readonly=no
```

The mount table is static in VFS V0. There is no mount or unmount command and no dynamic device-backed filesystem.

## Longest-prefix routing behavior

Routing uses longest-prefix matching. `/ram` and `/ram/...` route to RAMFS because `/ram` is more specific than `/`. Other absolute root paths route to TARFS unless VFS identifies them as an invalid/no-mount namespace for the VFS V0 proof path.

Expected route proof examples:

```text
vfs route /hello.txt
vfs_route_fs=tarfs-readonly-v0

vfs route /ram/hello.txt
vfs_route_fs=ramfs-volatile-memory-v0
```

## Breadcrumbs and error codes

VFS V0 emits stable logs:

- `VFS000` initialization and mount count.
- `VFS001` mount table requested.
- `VFS002` route success.
- `VFS003` list routed.
- `VFS004` stat routed.
- `VFS005` read routed.
- `VFS006` checksum routed.
- `VFS007` create routed.
- `VFS008` write routed.
- `VFS009` append routed.
- `VFS010` delete routed.
- `VFS011` missing path rejected.
- `VFS012` read-only write rejected.
- `VFS013` invalid/no mount rejected.

`VFS011` means routing succeeded but the selected filesystem could not find the requested file. `VFS012` means routing selected a read-only filesystem and a mutating operation was refused. `VFS013` means VFS could not honestly route the path to a mounted namespace for this V0 interface.

## Smoke test

Run the VFS proof directly:

```sh
./smoke/smoke-vfs-v0.sh
```

Run the full proof ladder, which executes VFS V0 after RAMFS V0:

```sh
./smoke/smoke-all.sh
```

The VFS smoke boots QEMU, drives the shell, proves `/hello.txt` routes to TARFS, proves `/ram/hello.txt` routes to RAMFS, verifies exact file contents, independently recomputes FNV-1a checksums, proves delete behavior, proves missing-path and read-only rejection, proves invalid/no-mount rejection, and rejects fake success claims.
