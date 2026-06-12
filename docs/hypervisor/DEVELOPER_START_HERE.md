# Hyper-Zig Developer Start Here

Hyper-Zig is the hypervisor-first line of the ZIGN01D RISC-V teaching kernel. It is a proof-driven Zig 0.14.x repository for growing from an observable kernel toward real hypervisor subsystems without pretending that future work already exists.

Current proven hypervisor milestones are **HV0**, **HV1**, **HV2**, **HV3**, **HV4**, **HV5**, **HV6**, **HV7**, **HV8**, and **HV9** when validation passes:

- **HV0** proves the honest hypervisor status surface.
- **HV1** proves safe capability reporting and keeps the RISC-V H-extension status `unknown` because there is no smoke-proven safe detection yet.
- **HV2** proves initialized VM/vCPU data-model objects.
- **HV3** proves boot vCPU lifecycle state transitions without guest execution.
- **HV4** proves a real PMM-backed guest-memory ownership object for VM 0 without guest execution.
- **HV5** proves metadata-only guest physical address lookup and rejection behavior without guest execution.
- **HV6** proves tiny `tiny-flat-v0` guest payload loading into HV4 memory through HV5 metadata, plus readback verification, without guest execution.
- **HV7** proves guest-entry preparation metadata: PC from the HV6 entry point, SP inside configured guest memory, a register frame, and attachment to VM 0 / vCPU 0, without guest execution.
- **HV8** proves guest trap/exit metadata and classification for simulated exits without guest execution.
- **HV9** proves a controlled guest-entry attempt safety gate that checks HV4-HV8 prerequisites and arms no-execute metadata while refusing real execution.

The next milestone is **HV10: first hardware-gated guest execution research**. HV9 remains separate from guest execution and does not claim Linux guest support, second-stage translation, or H-extension support.

## 1. Clone and select Zig 0.14.x

Use a Zig 0.14.x compiler. Hyper-Zig does not accept Zig 0.15, Zig 0.16, or newer APIs as compatibility proof.

```sh
git clone git@github.com:thanks-cohn/Hyper-Zig.git
cd Hyper-Zig
export ZIG=/path/to/zig-0.14.x/zig
```

If your shell `zig` is already a 0.14.x compiler, `export ZIG=...` is still useful when running scripts because it makes the intended toolchain explicit.

## 2. First build

Plain `zig build` builds the RISC-V kernel and prints the short Hyper-Zig status guide.

```sh
zig build
```

You can print the same concise repo-state guide directly without running full validation:

```sh
zig build hyperzig-status
```

The build output is not a guest-execution proof. It only proves that the kernel and build graph compile with the selected Zig toolchain.

## 3. First validation

Run the build-graph validation step:

```sh
zig build validate-hyperzig
```

Run the canonical script directly when you want the exact command used by maintainers and CI-like local validation:

```sh
./scripts/validate-hyperzig.sh
```

Inspect the final Minimus-Log summary:

```sh
tail -n 200 logs/latest/validate-hyperzig.log
```

The final summary is designed to stay dense enough for the last 200 to 500 lines while still showing branch, commit, Zig version, smoke status, transcript paths, current milestone, next target, and blockers.

## 4. Inspect smoke transcripts

Use transcript evidence as ground truth. The current validated facts include the older boot/platform facts plus hypervisor milestone smoke evidence when validation passes:

- OpenSBI v1.7 boots.
- The platform is `riscv-virtio,qemu`.
- Runtime SBI Version is 3.0.
- Domain0 Next Mode is S-mode.
- Boot HART Base ISA is `rv64imafdch`.
- Boot HART ISA Extensions include `sstc`, `zicntr`, `zihpm`, `zicboz`, `zicbom`, `sdtrig`, and `svadu`.
- H-extension status remains unknown.
- HV0 status smoke passes.
- HV1 capability smoke passes.
- HV2 VM/vCPU smoke passes.
- HV3 vCPU lifecycle smoke passes.
- HV4 guest-memory smoke passes.
- HV5 guest-address-space smoke passes.
- HV6 guest-image loader smoke passes.
- HV7 guest-entry preparation smoke passes.
- Minimus-Log validation passes.

Commands:

```sh
cat smoke/transcripts/latest-hv-status-v0.txt
cat smoke/transcripts/latest-hv-capability-v0.txt
cat smoke/transcripts/latest-hv-vm-vcpu-v0.txt
cat smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt
cat smoke/transcripts/latest-hv-guest-memory-v0.txt
cat smoke/transcripts/latest-hv-address-space-v0.txt
cat smoke/transcripts/latest-hv-guest-image-v0.txt
```

Do not treat OpenSBI presence as H-extension proof. Do not treat S-mode boot as hypervisor-mode proof.

## 5. Where the hypervisor code lives

Current hypervisor code is intentionally small:

- `kernel/hypervisor/hv.zig` prints the HV0 status surface, delegates HV1 capability reporting, and exposes HV2/HV3/HV4/HV5 object, lifecycle, guest-memory, address-space, and guest-image commands.
- `kernel/hypervisor/guest_memory.zig` implements the HV4 PMM-backed guest-memory ownership object and metadata-only rejection tests.
- `kernel/hypervisor/guest_address_space.zig` implements the HV5 guest physical address-space metadata object and lookup/rejection tests.
- `kernel/hypervisor/guest_image.zig` implements the HV6 tiny flat guest image loader and readback verifier.
- `kernel/hypervisor/guest_entry.zig` implements the HV7 guest-entry preparation object and register-frame derivation.
- `kernel/hypervisor/capability.zig` implements the HV1 safe capability status data and prints the current `unknown` H-extension result.
- `kernel/console/shell.zig` wires shell commands such as `hv`, `hv status`, `hv-status`, `hv capability`, `hv-capability`, and the `hv guest-memory` and `hv address-space` families.
- `smoke/smoke-hv-status-v0.sh` proves the HV0 status command transcript.
- `smoke/smoke-hv-capability-v0.sh` proves the HV1 capability command transcript.
- `smoke/smoke-hv-guest-memory-v0.sh` proves the HV4 guest-memory command transcript.
- `smoke/smoke-hv-address-space-v0.sh` proves the HV5 guest-address-space command transcript.
- `smoke/smoke-hv-guest-image-v0.sh` proves the HV6 guest-image command transcript.
- `smoke/smoke-hv-guest-entry-v0.sh` proves the HV7 guest-entry preparation transcript.
- `docs/hypervisor/HV2_IMPLEMENTATION_MAP.md` remains historical design context for the VM/vCPU model.

## 6. What HV0 through HV5 prove

HV0 proves that the repository can boot the kernel under QEMU and report an honest hypervisor status boundary. Its markers keep Linux guest support, guest execution, VM objects, vCPU objects, guest memory, guest entry, trap return, second-stage translation, virtual devices, and SBI mediation missing or not supported.

HV1 proves a safe capability-reporting surface. It reports `capability_detection=implemented` and `h_extension=unknown reason=no-safe-detection-yet`. That is deliberate: the current kernel does not have a smoke-proven safe H-extension detection path.

HV2 proves initialized VM/vCPU objects. HV3 proves typed vCPU lifecycle transitions: created, initialized, runnable, halted, and reset back to created. HV4 proves a PMM-backed guest-memory ownership object with metadata-only bounds, double-free, and overflow rejection. HV5 proves metadata-only guest physical address lookup for configured HV4 pages plus bounds and alignment rejection. None of these milestones proves guest execution, Linux support, second-stage translation, guest entry, or H-extension support.

## 7. What HV4 implements

HV4 implements a real PMM-backed guest memory object and inspection surface after the HV3 lifecycle proof:

- `GuestMemory` metadata for VM 0 ownership, state, base, page count, byte size, backing, counters, and last error
- shell commands for allocation, free, reset, bounds rejection, double-free rejection, and overflow rejection
- `smoke/smoke-hv-guest-memory-v0.sh` to prove state movement and rejection behavior through QEMU shell command blocks
- explicit non-claims that guest execution, Linux support, guest entry, and second-stage translation remain missing

HV4 guest memory is an ownership object only. It must not be treated as guest execution, Linux support, guest entry, or second-stage translation.

## 8. How Minimus-Log works

`./scripts/validate-hyperzig.sh` creates a timestamped validation directory under `logs/validation/` and refreshes symlinks under `logs/latest/`.

Important paths:

- `logs/latest/validate-hyperzig.log` is the full command log.
- `logs/latest/validate-hyperzig-minimus-log-summary.txt` is the extracted final summary.
- `smoke/transcripts/latest-hv-status-v0.txt` is the current HV0 transcript.
- `smoke/transcripts/latest-hv-capability-v0.txt` is the current HV1 transcript.
- `smoke/transcripts/latest-hv-vm-vcpu-v0.txt` is the current HV2 transcript.
- `smoke/transcripts/latest-hv-vcpu-lifecycle-v0.txt` is the current HV3 transcript.
- `smoke/transcripts/latest-hv-guest-memory-v0.txt` is the current HV4 transcript.

## 9. How not to lie about progress

A claim is implemented only when source code, smoke proof, and transcript evidence all agree. Documentation alone is not implementation.

Forbidden shortcuts:

- Do not claim Linux guest support.
- Do not claim guest execution.
- Do not fake H-extension support.
- Do not treat OpenSBI as H-extension proof.
- Do not treat S-mode boot as hypervisor mode.
- Do not replace `guest_execution=not-supported-yet` until real guest execution exists and is smoke-proven; HV7 guest-entry preparation is metadata only.
- Do not mark VM/vCPU objects implemented until real initialized data-model objects are inspected by smoke.
- Do not mark vCPU lifecycle implemented until transition behavior and failed-transition counters are smoke-proven.
- Do not treat HV4 guest memory metadata as executable guest memory.

The honest next edit for hypervisor developers is HV10 first hardware-gated guest execution research, after reviewing HV9 run-attempt implementation and validation transcript.

## HV5 Guest Address Space current scope

HV5 is the guest physical address metadata milestone. Start with `kernel/hypervisor/guest_address_space.zig`, which owns typed GPA/HPA wrappers, one VM 0 address-space object, one guest region, lookup results, error states, and lookup/rejection counters. It derives metadata only from the HV4 PMM-backed `GuestMemory` object; it does not install second-stage page tables and does not execute guest code.

Use these commands while developing HV5:

```bash
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
export PATH=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1:$PATH
zig build
./smoke/smoke-hv-address-space-v0.sh
./scripts/validate-hyperzig.sh
```

The HV5 smoke must inspect command blocks in `smoke/transcripts/latest-hv-address-space-v0.txt` and prove state movement from `not-configured` to `configured`, successful GPA `0x0` and `0x1000` lookups, rejected bounds and alignment tests, and continued non-support for guest execution, Linux guests, guest entry, and second-stage translation.


## HV6 current scope

HV6 loads the static `tiny-flat-v0` byte payload into GPA `0x0` using HV5 address-space lookups and the PMM-backed HV4 guest-memory pages. The loader records the image size, loaded byte count, entry point metadata at GPA `0x0`, deterministic checksum, load/verify/failure counters, and bounds rejection count. The verifier reads bytes back from guest memory and checks the payload bytes, byte count, and checksum.

HV6 does **not** execute the guest. HV6 does **not** load Linux. HV6 does **not** implement guest entry. HV6 does **not** implement second-stage translation or prove RISC-V H-extension support.

Exact HV6 validation command:

```sh
./smoke/smoke-hv-guest-image-v0.sh
```


## HV7 current scope

HV7 creates `kernel/hypervisor/guest_entry.zig`. It prepares metadata only: `GuestEntry`, `GuestEntryState`, `GuestRegisterFrame`, `GuestEntryError`, `GuestEntryPrepareResult`, and `GuestEntryResetResult`. Preparation requires a loaded HV6 image, uses HV4/HV5 guest-memory/address-space metadata, derives `pc` from the HV6 image entry point, derives a stack pointer within configured guest memory, and attaches the frame to VM 0 / vCPU 0.

HV7 does **not** execute the guest. HV7 does **not** load Linux. HV7 does **not** implement second-stage translation. HV7 does **not** prove H-extension support.

Exact HV7 validation command:

```bash
./smoke/smoke-hv-guest-entry-v0.sh
```

## HV8 Guest Trap / Exit Metadata current scope

HV8 is implemented when validation passes. It adds `kernel/hypervisor/guest_exit.zig`, wires `hv guest-exit` commands, and proves that simulated guest exits are rejected without an HV7 prepared frame and recorded after HV7 preparation. The recorded exit frame copies PC/SP from the HV7 guest-entry frame and stores cause, trap value, instruction bits, owner IDs, counters, and last error.

HV8 commands for development:

```bash
export ZIG=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1/zig
export PATH=/home/big-bro/dev/zig-zag/.tools/zig-x86_64-linux-0.14.1:$PATH
zig build
./smoke/smoke-hv-guest-exit-v0.sh
./scripts/validate-hyperzig.sh
```

HV8 does not execute the guest, does not mark the vCPU running, does not increment `vcpu.run_count`, does not boot Linux, does not implement second-stage translation, and does not prove H-extension support.

## HV9 Controlled Guest-Entry Attempt current scope

HV9 is implemented when validation passes. It adds `kernel/hypervisor/guest_run_attempt.zig`, wires `hv guest-run` commands, and proves that a future guest-entry attempt checks HV4 guest memory, HV5 address-space metadata, HV6 image loading, HV7 entry preparation, and HV8 exit readiness before arming no-execute metadata.

HV9 commands for development:

```sh
hv guest-run
hv-run
hv guest-run check
hv guest-run arm-no-execute
hv guest-run reset
hv guest-run require-entry-test
hv guest-run require-exit-test
```

HV9 does not execute the guest, does not mark the vCPU running, does not increment `vcpu.run_count`, does not boot Linux, does not implement second-stage translation, and does not prove H-extension support. The next milestone after HV9 is HV10 first hardware-gated guest execution research.
