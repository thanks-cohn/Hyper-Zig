# RAMFS V0

RAMFS V0 is ZIGN01D's first tiny writable filesystem-shaped store. It is a bounded, volatile, kernel-memory-backed file table rooted at `/ram`.

## What RAMFS V0 implements

RAMFS V0 implements real in-memory file behavior inside the kernel:

- bounded file table capacity: 8 files;
- bounded file size: exposed as `ramfs_max_file_bytes=`;
- paths under `/ram`;
- create, write, read/cat, append, list, stat, checksum, and delete;
- missing-path rejection for reads, stats, deletes, and invalid creates;
- capacity-full rejection when the file table has no free slot;
- file-too-large rejection when a write or append would exceed the maximum file size;
- operation counters and `ramfs_last_error=` breadcrumbs;
- stable RAMFS logs `RAMFS000` through `RAMFS012`.

Duplicate creates are intentionally rejected with `ramfs_duplicate_create_rejected=yes` and `ramfs_last_error=already-exists`, and the RAMFS V0 smoke test proves that a second create for `/ram/hello.txt` is rejected before writes continue against the original file. RAMFS V0 does not silently overwrite existing files because accidental overwrite would hide a class of early filesystem bugs.

## What RAMFS V0 does not implement

RAMFS V0 is intentionally honest about its limits:

- `persistent_storage=not-implemented`
- `block_device_fs=not-implemented`
- `vfs=not-implemented`
- `journaling=not-implemented`
- `permissions=not-implemented`
- `directories=limited-or-not-implemented`
- `executable_apps=not-implemented`
- `wasm_loader=not-implemented`
- `userspace_loader=not-implemented`
- `production_filesystem=not-implemented`

The data lives only in kernel memory. Rebooting the kernel loses RAMFS contents. RAMFS V0 is not a block-device filesystem, is not persistent storage, and is not a production filesystem.

## RAMFS versus TARFS

TARFS V0 is read-only embedded file data. It proves that the kernel can expose real boot-time files and reject writes honestly.

RAMFS V0 is writable volatile memory. It proves that the kernel can mutate file contents at runtime and keep observable state: exact byte writes, exact byte appends, updated sizes, updated checksums, deletion, and bounded failure behavior.

TARFS answers: "Can the kernel expose trusted embedded bytes?"

RAMFS answers: "Can the kernel safely hold small runtime-created bytes and prove mutation semantics?"

## Why volatile writable files matter

RAMFS V0 is a small step, but it unlocks important future shape without pretending those future layers exist today:

- **Before VFS:** RAMFS gives the shell and tests a writable filesystem target before a routing layer exists.
- **App staging:** future loaders can stage package or app bytes in a volatile area before execution exists.
- **Logs-as-files:** diagnostics can eventually be copied into inspectable file-like records instead of only serial output.
- **Package unpacking:** archive extraction needs a writable destination before persistent storage is ready.
- **User programs:** early userspace will need temporary files, scratch buffers, and inspectable handoff points.

## Shell commands

Expected RAMFS V0 command path:

```text
ramfs
ramfs stats
ramfs list
ramfs create /ram/hello.txt
ramfs write /ram/hello.txt "hello from zign01d ramfs"
ramfs cat /ram/hello.txt
ramfs append /ram/hello.txt " appended"
ramfs stat /ram/hello.txt
ramfs checksum /ram/hello.txt
ramfs delete /ram/hello.txt
ramfs cat /ram/hello.txt
ramfs missing-test
ramfs capacity-test
ramfs overflow-test
```

## Smoke test

Run RAMFS V0 directly:

```sh
./smoke/smoke-ramfs-v0.sh
```

Run the full ladder, with RAMFS V0 after TARFS V0:

```sh
./smoke/smoke-all.sh
```

The RAMFS smoke test builds the kernel, boots QEMU, waits for the shell prompt, runs real RAMFS commands, verifies exact write and append content, independently computes the FNV-1a checksum for `hello from zign01d ramfs appended`, proves delete causes a later read to fail, proves capacity rejection, proves file-size rejection, and rejects forbidden fake-success claims.

## Breadcrumbs and rejection logs

RAMFS V0 emits stable breadcrumb logs:

- `RAMFS000`: RAMFS initialized with root, capacity, max file size, backing, and persistence markers.
- `RAMFS001`: stats requested.
- `RAMFS002`: list requested.
- `RAMFS003`: create success.
- `RAMFS004`: write success.
- `RAMFS005`: read success.
- `RAMFS006`: append success.
- `RAMFS007`: stat success.
- `RAMFS008`: checksum success.
- `RAMFS009`: delete success.
- `RAMFS010`: missing path rejected. `ramfs_last_error=not-found` means an operation targeted a path that is not currently present, such as reading `/ram/hello.txt` after deletion.
- `RAMFS011`: capacity full rejected. `ramfs_last_error=capacity-full` means no free file table slot was available for an additional create.
- `RAMFS012`: file too large rejected. `ramfs_last_error=file-too-large` means a write or append would exceed `ramfs_max_file_bytes=`.

These logs are intended to make early filesystem failures visible in serial transcripts and smoke logs instead of silently disappearing.
