# Hyper-Zig Developer Start Here

Hyper-Zig is the hypervisor-first line of the ZIGN01D RISC-V teaching kernel. It is a proof-driven Zig 0.14.x repository for growing from an observable kernel toward real hypervisor subsystems without pretending that future work already exists.

Current proven hypervisor milestones are **HV0** and **HV1**:

- **HV0** proves the honest hypervisor status surface.
- **HV1** proves safe capability reporting and keeps the RISC-V H-extension status `unknown` because there is no smoke-proven safe detection yet.

The next milestone is **HV2: VM/vCPU data model**. HV2 should add real initialized VM and vCPU objects plus inspection and smoke proof. HV2 must not claim guest execution, Linux guest support, guest memory ownership, guest entry, trap return, or second-stage translation.

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

Use transcript evidence as ground truth. The current validated facts are:

- OpenSBI v1.7 boots.
- The platform is `riscv-virtio,qemu`.
- Runtime SBI Version is 3.0.
- Domain0 Next Mode is S-mode.
- Boot HART Base ISA is `rv64imafdch`.
- Boot HART ISA Extensions include `sstc`, `zicntr`, `zihpm`, `zicboz`, `zicbom`, `sdtrig`, and `svadu`.
- H-extension status remains unknown.
- HV0 status smoke passes.
- HV1 capability smoke passes.
- Minimus-Log validation passes.

Commands:

```sh
cat smoke/transcripts/latest-hv-status-v0.txt
cat smoke/transcripts/latest-hv-capability-v0.txt
```

Do not treat OpenSBI presence as H-extension proof. Do not treat S-mode boot as hypervisor-mode proof.

## 5. Where the hypervisor code lives

Current hypervisor code is intentionally small:

- `kernel/hypervisor/hv.zig` prints the HV0 status surface and delegates HV1 capability reporting.
- `kernel/hypervisor/capability.zig` implements the HV1 safe capability status data and prints the current `unknown` H-extension result.
- `kernel/console/shell.zig` wires shell commands such as `hv`, `hv status`, `hv-status`, `hv capability`, and `hv-capability`.
- `smoke/smoke-hv-status-v0.sh` proves the HV0 status command transcript.
- `smoke/smoke-hv-capability-v0.sh` proves the HV1 capability command transcript.
- `docs/hypervisor/HV2_IMPLEMENTATION_MAP.md` is the implementation map for the next real hypervisor subsystem.

## 6. What HV0 and HV1 prove

HV0 proves that the repository can boot the kernel under QEMU and report an honest hypervisor status boundary. Its markers keep Linux guest support, guest execution, VM objects, vCPU objects, guest memory, guest entry, trap return, second-stage translation, virtual devices, and SBI mediation missing or not supported.

HV1 proves a safe capability-reporting surface. It reports `capability_detection=implemented` and `h_extension=unknown reason=no-safe-detection-yet`. That is deliberate: the current kernel does not have a smoke-proven safe H-extension detection path.

## 7. What HV2 should implement next

HV2 should implement a real VM/vCPU data model and inspection surface:

- create `kernel/hypervisor/vm.zig`
- create `kernel/hypervisor/vcpu.zig`
- add shell commands `hv vm`, `hv vcpu`, `hv inspect`, and `hv-objects`
- add `smoke/smoke-hv-vm-vcpu-v0.sh`
- add `docs/hypervisor/HV2_VM_VCPU_MODEL.md`

Real HV2 code means deterministic initialized structs with fields a smoke test can inspect. It does not mean guest execution, Linux support, guest memory, guest entry, or second-stage translation.

## 8. How Minimus-Log works

`./scripts/validate-hyperzig.sh` creates a timestamped validation directory under `logs/validation/` and refreshes symlinks under `logs/latest/`.

Important paths:

- `logs/latest/validate-hyperzig.log` is the full command log.
- `logs/latest/validate-hyperzig-minimus-log-summary.txt` is the extracted final summary.
- `smoke/transcripts/latest-hv-status-v0.txt` is the current HV0 transcript.
- `smoke/transcripts/latest-hv-capability-v0.txt` is the current HV1 transcript.

## 9. How not to lie about progress

A claim is implemented only when source code, smoke proof, and transcript evidence all agree. Documentation alone is not implementation.

Forbidden shortcuts:

- Do not claim Linux guest support.
- Do not claim guest execution.
- Do not fake H-extension support.
- Do not treat OpenSBI as H-extension proof.
- Do not treat S-mode boot as hypervisor mode.
- Do not replace `guest_execution=not-supported-yet` until a real guest-entry milestone exists and is smoke-proven.
- Do not mark VM/vCPU objects implemented until real initialized data-model objects are inspected by smoke tests.

The honest next edit for hypervisor developers is `kernel/hypervisor/vm.zig`, after reading `docs/hypervisor/HV2_IMPLEMENTATION_MAP.md`.
