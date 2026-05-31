# PMM V0 Physical Page Manager

PMM V0 is a small, inspectable physical page accounting milestone for the RISC-V QEMU `virt` kernel. It is intentionally a visibility and proof milestone, not a production memory manager.

## What PMM V0 implements

- A `kernel/memory/pmm.zig` subsystem initialized during boot.
- A 4096-byte page size.
- Bitmap-style state for the known QEMU `virt` RAM range from the board profile.
- Honest reservation of kernel-owned/unavailable pages from RAM base through the aligned linker `__kernel_end` address.
- Shell-visible counters:
  - `pmm_total_pages=`
  - `pmm_free_pages=`
  - `pmm_used_pages=`
  - `pmm_reserved_pages=`
  - `pmm_alloc_count=`
  - `pmm_free_count=`
  - `pmm_last_error=`
- Single-page allocation from PMM-managed free pages.
- Freeing a page that was previously allocated by PMM.
- Rejection of invalid frees.
- Rejection of double frees.
- Rejection of allocation after managed free pages are exhausted.
- Boot and shell breadcrumbs with stable PMM markers (`PMM000`, `PMM001`) so a failing transcript points at the PMM subsystem.

## Shell commands

Run these from the serial shell:

```text
pmm
pmm stats
pmm alloc-test
pmm free-test
pmm invalid-free-test
pmm double-free-test
pmm exhaustion-test
```

The smoke test proves these required markers:

```text
pmm_interface=present
pmm_kind=bitmap-or-stack-v0
pmm_page_size=4096
pmm_total_pages=
pmm_free_pages=
pmm_used_pages=
pmm_reserved_pages=
pmm_alloc_count=
pmm_free_count=
pmm_last_error=
pmm_alloc_test=pass
pmm_alloc_page_ok=yes
pmm_free_test=pass
pmm_free_page_ok=yes
pmm_invalid_free_rejected=yes
pmm_double_free_rejected=yes
pmm_exhaustion_rejected=yes
```

## What PMM V0 does not implement

PMM V0 must keep these non-claims visible:

```text
virtual_memory=not-implemented
paging=not-implemented
userspace_memory=not-implemented
swap=not-implemented
numa=not-implemented
production_pmm=not-implemented
```

It does not implement virtual address translation, page tables, copy-on-write, userspace mappings, swap, NUMA policy, zones, DMA constraints, high-memory policy, concurrency safety, or a production allocator API.

## How to run the smoke test

```sh
./smoke/smoke-pmm-v0.sh
```

The PMM smoke test builds the kernel, boots QEMU, waits for the `zign01d>` shell prompt, runs the PMM commands, checks required markers, rejects forbidden fake-success claims, and prints:

```text
PASS ZIGN01D PMM V0 smoke
```

PMM V0 is also part of the full smoke ladder after HEAP V0:

```sh
./smoke/smoke-all.sh
```

## Why PMM V0 comes before later milestones

Paging, userspace, filesystems, `fork`, and real program loading all need trustworthy physical page ownership. Before those systems exist, the kernel must be able to answer basic questions: which physical pages are unavailable, which pages are free, which pages were allocated, and whether bad frees are rejected.

PMM V0 provides that proof layer. It gives future paging and loader work a visible accounting base instead of hidden assumptions. If a later memory milestone corrupts page ownership, PMM counters, error markers, and smoke transcripts should narrow the bug hunt quickly.
