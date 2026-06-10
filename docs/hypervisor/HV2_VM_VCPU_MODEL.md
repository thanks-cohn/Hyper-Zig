# HV2 VM/vCPU Data Model

HV2 moves Hyper-Zig from hypervisor-status scaffolding to an experimental hypervisor candidate by adding real initialized VM and vCPU objects. It still does **not** execute a guest, enter RISC-V hypervisor guest mode, configure second-stage translation, or boot Linux.

## Implemented objects

- `kernel/hypervisor/vm.zig` defines the single boot VM object.
- `kernel/hypervisor/vcpu.zig` defines the single boot vCPU object bound to VM `0`.
- `kernel/hypervisor/hv.zig` initializes both objects during kernel boot through `hv.init()`.

The HV2 object model is deliberately small but real: the objects are typed Zig structs, initialized by code, retained in kernel storage, and exposed through shell inspection commands.

## VM object

The initial VM has these smoke-proven fields:

```text
hv: vm_object=implemented
hv: vm.id=0
hv: vm.state=defined
hv: vm.guest_memory=not-configured
```

`guest_memory=not-configured` is intentional. HV2 does not create guest RAM, guest physical mappings, page tables, or second-stage translation. The next milestone is HV3 vCPU lifecycle, followed by HV4 guest memory object.

## vCPU object

The initial vCPU has these smoke-proven fields:

```text
hv: vcpu_object=implemented
hv: vcpu.id=0
hv: vcpu.vm_id=0
hv: vcpu.state=defined
hv: vcpu.hart_binding=unbound
hv: vcpu.run_count=0
```

`hart_binding=unbound` and `run_count=0` are intentional. HV2 does not bind a vCPU to a hardware hart for execution and does not attempt guest entry.

## Shell commands

- `hv vm` prints the VM object fields and non-claim markers.
- `hv vcpu` prints the vCPU object fields and non-claim markers.
- `hv inspect` prints both objects together.
- `hv-objects` is a flat alias for `hv inspect`.

Required non-claim markers remain part of the HV2 command output:

```text
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
```

## Smoke proof

Run:

```sh
./smoke/smoke-hv-vm-vcpu-v0.sh
```

The smoke test boots the kernel in QEMU, runs `hv vm`, `hv vcpu`, `hv inspect`, and `hv-objects`, then verifies the object fields and the explicit no-guest-execution/no-Linux markers.

## Honest status

After HV2, Hyper-Zig can honestly be called:

- a hypervisor-first kernel;
- a hypervisor scaffold;
- an experimental hypervisor candidate.

It still must **not** be called a working hypervisor, because guest entry and guest execution do not exist yet.
