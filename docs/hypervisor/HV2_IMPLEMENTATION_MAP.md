# HV2 Implementation Map: VM/vCPU Data Model

HV2 is the next Hyper-Zig hypervisor milestone. It should add a real, inspectable VM/vCPU data model. HV2 must remain a data-model milestone only: it must not enter a guest, load Linux, allocate guest memory, install second-stage translation, or claim H-extension support.

## Current boundary

Implemented and proven today:

- HV0 status smoke passes.
- HV1 capability smoke passes.
- H-extension status is `unknown reason=no-safe-detection-yet`.
- `guest_execution=not-supported-yet` remains true.
- `linux_guest=not-supported-yet` remains true.
- `vm_object=MISSING` and `vcpu_object=MISSING` remain true until HV2 code and smoke proof land.

## Files to create

Required future source files:

- `kernel/hypervisor/vm.zig`
- `kernel/hypervisor/vcpu.zig`

Required future smoke/doc files:

- `smoke/smoke-hv-vm-vcpu-v0.sh`
- `docs/hypervisor/HV2_VM_VCPU_MODEL.md`

Expected integration files to update:

- `kernel/hypervisor/hv.zig`
- `kernel/console/shell.zig`
- `docs/COMMAND_REFERENCE.md`
- `docs/MILESTONE_INDEX.md`
- `scripts/validate-hyperzig.sh`

## Structs to add

### `kernel/hypervisor/vm.zig`

Add a real initialized VM object. Minimum required shape:

```zig
pub const VmState = enum {
    defined,
};

pub const Vm = struct {
    id: u32,
    generation: u32,
    state: VmState,
    guest_memory: GuestMemoryState,
    vcpu_count: u32,
    entry_configured: bool,
};

pub const GuestMemoryState = enum {
    not_configured,
};
```

Required fields:

- `id`: deterministic VM identifier for the built-in inspection object.
- `generation`: deterministic model generation, starting at `0` or `1` and documented.
- `state`: must show the VM object is defined but not runnable.
- `guest_memory`: must be `not_configured` for HV2.
- `vcpu_count`: must match the static vCPU object count.
- `entry_configured`: must be `false` for HV2.

Required functions:

- deterministic initializer such as `pub fn initStatic() Vm`
- printer or formatter used by the shell inspection command
- no heap dependency unless a real allocation policy and smoke proof are added

### `kernel/hypervisor/vcpu.zig`

Add a real initialized vCPU object. Minimum required shape:

```zig
pub const VcpuState = enum {
    defined,
};

pub const Vcpu = struct {
    id: u32,
    vm_id: u32,
    state: VcpuState,
    hart_binding: HartBinding,
    entry_configured: bool,
    run_count: u64,
};

pub const HartBinding = enum {
    unbound,
};
```

Required fields:

- `id`: deterministic vCPU identifier.
- `vm_id`: deterministic parent VM identifier.
- `state`: must show the vCPU object is defined but not runnable.
- `hart_binding`: must be `unbound` for HV2.
- `entry_configured`: must be `false` for HV2.
- `run_count`: must be `0`; do not fake runtime counters.

Required functions:

- deterministic initializer such as `pub fn initStatic(vm_id: u32) Vcpu`
- printer or formatter used by the shell inspection command
- no guest register switching and no trap return path

## Commands to add

Required future shell commands:

- `hv vm`
- `hv vcpu`
- `hv inspect`
- `hv-objects`

Expected command behavior:

- `hv vm` prints the VM fields only.
- `hv vcpu` prints the vCPU fields only.
- `hv inspect` prints both objects and the non-claim boundary.
- `hv-objects` is a flat alias for smoke-friendly inspection.

## Required smoke markers

The HV2 smoke test must positively match deterministic object fields. Required markers:

```text
hv: vm_object=implemented
hv: vm.id=0
hv: vm.state=defined
hv: vm.guest_memory=not-configured
hv: vm.entry_configured=false
hv: vcpu_object=implemented
hv: vcpu.id=0
hv: vcpu.vm_id=0
hv: vcpu.state=defined
hv: vcpu.hart_binding=unbound
hv: vcpu.entry_configured=false
hv: vcpu.run_count=0
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
```

## Forbidden markers

The HV2 smoke test must reject markers that imply unsupported work. Forbidden markers:

```text
hv: guest_execution=implemented
hv: guest_execution=PROVEN
hv: linux_guest=implemented
hv: linux_guest=PROVEN
hv: h_extension=present
hv: guest_memory=implemented
hv: guest_entry=implemented
hv: guest_trap_return=implemented
hv: second_stage_translation=implemented
hv: linux_boot=PROVEN
```

## Validation commands

Minimum HV2 validation sequence:

```sh
export ZIG=/path/to/zig-0.14.x/zig
git status
git branch --show-current
./scripts/check-zig-version.sh
zig build
./smoke/smoke-hv-vm-vcpu-v0.sh
zig build validate-hyperzig
./scripts/validate-hyperzig.sh
tail -n 200 logs/latest/validate-hyperzig.log
cat smoke/transcripts/latest-hv-status-v0.txt
cat smoke/transcripts/latest-hv-capability-v0.txt
```

After HV2 lands, `scripts/validate-hyperzig.sh` should treat `smoke/smoke-hv-vm-vcpu-v0.sh` as a required smoke test.

## What counts as real HV2 data-model code

Real HV2 code has all of these properties:

- new Zig source files define VM and vCPU structs with typed fields, not just emitted strings
- fields are deterministically initialized by code
- shell inspection prints values from initialized structs
- smoke tests prove those values from a QEMU transcript
- docs explain exactly what the fields mean
- validation keeps `guest_execution=not-supported-yet`
- validation keeps `linux_guest=not-supported-yet`
- validation keeps guest memory, guest entry, trap return, and second-stage translation unimplemented unless separate real proof exists

## What counts as placeholder or cardboard code

Cardboard HV2 code includes any of these shortcuts:

- empty structs
- command handlers that only print strings without backing data objects
- fake counters that imply a vCPU has run
- claims that a VM exists without a smoke-proven initialized object
- claims that guest memory exists without an ownership model
- claims that Linux can boot or run
- changing `guest_execution=not-supported-yet`
- claiming H-extension presence from OpenSBI output or S-mode boot alone

## HV2 non-claims

Even when HV2 is complete, these statements must remain true until later milestones prove otherwise:

- VM/vCPU object implemented does not mean guest execution.
- VM/vCPU object implemented does not mean Linux support.
- VM/vCPU object implemented does not mean guest memory exists.
- VM/vCPU object implemented does not mean H-extension support is proven.
- VM/vCPU object implemented does not mean second-stage translation exists.
