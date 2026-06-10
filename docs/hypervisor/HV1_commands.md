# HV1 Hypervisor Commands

## HV0 status commands kept unchanged

The following commands print the HV0/HV status scaffold. They are status-only and must not claim guest execution, VM/vCPU support, or Linux guest support:

```text
hv
hv status
hv-status
```

Expected status-only markers include:

```text
hv: status=research-scaffold
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
hv: vm_object=MISSING
hv: vcpu_object=MISSING
```

## HV1 capability commands

The following commands print the HV1 capability detection status:

```text
hv capability
hv-capability
```

Expected HV1 markers include:

```text
hv: branch=hypervisor-v0
hv: target=zig-0.14.x
hv: capability_detection=implemented
hv: capability_source=supervisor-mode-safe-static-policy
hv: h_extension=unknown reason=no-safe-detection-yet
hv: guest_execution=not-supported-yet
hv: linux_guest=not-supported-yet
hv: vm_object=MISSING
hv: vcpu_object=MISSING
```

## Non-claims

HV1 commands do not imply guest execution, Linux guest support, VM object support, vCPU object support, guest memory, guest entry, guest trap return, second-stage translation, virtual console, SBI mediation, or virtio support for Linux.

## Smoke proof

Use:

```sh
./smoke/smoke-hv-capability-v0.sh
```

The transcript path is:

```text
smoke/transcripts/latest-hv-capability-v0.txt
```
