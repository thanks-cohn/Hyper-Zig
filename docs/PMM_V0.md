# PMM V0 Physical Page Manager

PMM V0 is a small, inspectable physical page manager milestone for the RISC-V QEMU `virt` kernel. It exists to prove real physical-page ownership accounting before ZIGN01D grows paging, userspace, filesystems, fork, an app ABI, WASM hosting, or phone hardware drivers.

PMM V0 is deliberately modest: it is a proof-first kernel subsystem with visible counters and failure breadcrumbs. It is not a production physical memory manager.

## What PMM V0 implements

- A `kernel/memory/pmm.zig` subsystem initialized during boot.
- A fixed 4096-byte physical page size.
- A known PMM-managed physical memory region from the QEMU `virt` board RAM profile.
- `bitmap-v0` accounting with separate reserved and used bitmaps.
- Kernel/unavailable page reservation from RAM base through aligned linker `__kernel_end`.
- Real single-page allocation from the managed free pool.
- Real freeing of an address that was previously allocated by PMM.
- Rejection of invalid frees outside the managed region or not aligned to 4096 bytes.
- Rejection of double frees.
- Rejection of allocation after a bounded tiny test-PMM pool is exhausted, without mutating the live PMM free/used page counts.
- Shell-visible state:
  - `pmm_total_pages=`
  - `pmm_free_pages=`
  - `pmm_used_pages=`
  - `pmm_reserved_pages=`
  - `pmm_alloc_count=`
  - `pmm_free_count=`
  - `pmm_invalid_free_count=`
  - `pmm_double_free_count=`
  - `pmm_exhaustion_count=`
  - `pmm_last_error=`
- Breadcrumb logs with stable PMM codes:
  - `PMM000`: initialization path reached.
  - `PMM001`: managed region, page size, and starting counters.
  - `PMM010`: allocation success, including page address and counters.
  - `PMM011`: free success, including page address and counters.
  - `PMM012`: invalid free rejected, including attempted address and reason.
  - `PMM013`: double free rejected, including attempted address and reason.
  - `PMM014`: bounded test-pool exhaustion rejected, including counters and reason.

## Shell commands

Run these commands from the serial shell:

```text
pmm
pmm stats
pmm alloc-test
pmm free-test
pmm invalid-free-test
pmm double-free-test
pmm exhaustion-test
```

The required interface markers include:

```text
pmm_interface=present
pmm_kind=bitmap-v0
pmm_page_size=4096
pmm_managed_region_start=
pmm_managed_region_end=
pmm_total_pages=
pmm_free_pages=
pmm_used_pages=
pmm_reserved_pages=
pmm_alloc_count=
pmm_free_count=
pmm_invalid_free_count=
pmm_double_free_count=
pmm_exhaustion_count=
pmm_last_error=
pmm_alloc_test=pass
pmm_alloc_page_ok=yes
pmm_alloc_page_addr=
pmm_free_test=pass
pmm_free_page_ok=yes
pmm_invalid_free_rejected=yes
pmm_double_free_rejected=yes
pmm_exhaustion_rejected=yes
```

## PMM V0 versus HEAP V0

HEAP V0 is a kernel allocator for byte-sized kernel allocations. It proves a bump-reset allocation model, reset behavior, overflow rejection, and honest non-claims around individual frees.

PMM V0 is lower-level. It accounts for physical 4096-byte pages. Future paging and userspace work need physical page ownership before byte allocators, app loaders, file caches, or WASM hosts can safely grow. PMM answers questions such as: which physical pages are reserved, which are free, which were allocated, and did a bad free get rejected?

## What PMM V0 does not implement

PMM V0 intentionally prints these honest non-claims:

```text
paging=not-implemented
virtual_memory=not-implemented
userspace_memory=not-implemented
swap=not-implemented
numa=not-implemented
production_pmm=not-implemented
memory_hotplug=not-implemented
page_cache=not-implemented
```

It does not implement virtual address translation, page tables, copy-on-write, userspace mappings, swap, NUMA policy, memory zones, DMA constraints, high-memory policy, concurrency safety, memory hotplug, a page cache, or a production allocator API.

## Why PMM V0 comes before later milestones

Paging cannot safely map pages until the kernel can prove who owns physical pages. Userspace cannot receive memory until allocation and free paths reject bad ownership transitions. Filesystems and page cache work need page accounting before caching blocks in RAM. `fork` needs trustworthy page ownership before copy-on-write or process address spaces. The app ABI and WASM hosting need a kernel memory substrate that can allocate, free, and diagnose physical page state. Phone hardware work will eventually need DMA-aware and device-aware memory policy; PMM V0 is not that policy, but it is the first proof layer beneath it.

## Running the smoke test

```sh
./smoke/smoke-pmm-v0.sh
```

The PMM smoke test builds the kernel, boots QEMU, waits for the `zign01d>` prompt, runs every PMM command, checks required markers, rejects forbidden fake-success claims, and validates arithmetic rather than just looking for strings. In particular, it proves:

- `alloc-test` decreases free pages, increases used pages, returns a 4096-byte-aligned address, and increments `pmm_alloc_count`.
- `free-test` frees the exact allocated page and returns free/used counters toward their prior values while incrementing `pmm_free_count`.
- `invalid-free-test` rejects an outside-region address, sets `pmm_last_error=invalid-free`, and increments `pmm_invalid_free_count`.
- `double-free-test` rejects the second free, sets `pmm_last_error=double-free`, and increments `pmm_double_free_count`.
- `exhaustion-test` fills a deliberately tiny bounded test-PMM pool, proves the next allocation is rejected, sets `pmm_last_error=out-of-pages`, increments `pmm_exhaustion_count`, and shows the live PMM free/used counters were not corrupted.

A passing run prints exactly:

```text
PASS ZIGN01D PMM V0 smoke
```

PMM V0 is also part of the full smoke ladder after HEAP V0:

```sh
./smoke/smoke-all.sh
```

## Reading failure logs

If the smoke test fails, inspect:

- `logs/latest/build.log` for build failures.
- `logs/latest/qemu-pmm-v0.log` for the QEMU command and full serial transcript.
- `logs/latest/smoke-pmm-v0.log` for the failing marker or arithmetic check.
- `smoke/transcripts/latest-pmm-v0.txt` for raw shell output.

PMM breadcrumbs are designed to identify the failure path quickly. `PMM012` points at invalid-free rejection, `PMM013` points at double-free rejection, and `PMM014` points at bounded test-pool exhaustion rejection. Counter fields near those logs show whether the state transition happened or was correctly refused.
