# MILESTONE: ZBUS V0 User Guide

## What this milestone adds

ZBUS V0 adds the host capability bus scaffold. ZBUS defines the future plug between ZIGN01D kernel commands and a host-side capability daemon.

This milestone adds:

- A static ZBUS kernel subsystem.
- A boot marker proving the ZBUS scaffold is present.
- Shell commands for inspecting the ZBUS state.
- COMM, NET, SMS, and MODEM output that names ZBUS as the future provider path while still reporting no connected transport.
- A smoke test for the ZBUS V0 command surface.
- A documentation contract for all future milestones.

## What this milestone does not add

ZBUS V0 does not add real internet, SMS, SMS receive, real modem access, calls, Wi-Fi calling, host files, host time, or real host transport. It does not connect a host bridge. It does not send a host request.

## Build command

```sh
./scripts/build.sh
```

## Run command

```sh
./scripts/run-qemu.sh
```

Wait for the shell prompt:

```text
zign01d>
```

## Shell commands added

```text
zbus
zbus status
zbus ping
zbus providers
```

## Command examples

At the `zign01d>` prompt, type:

```text
help
status
zbus
zbus status
zbus ping
zbus providers
comm
net get http://example.com
sms send +15551234567 hello
modem status
```

Expected ZBUS command output includes:

```text
zbus: interface=present
zbus: transport=none
zbus: connected=no
zbus: providers=none
zbus: net=not-implemented
zbus: sms=not-implemented
zbus: modem=not-implemented
zbus: files=not-implemented
zbus: time=not-implemented
```

Expected `zbus ping` output is an explicit failure:

```text
zbus: ping=not-implemented
zbus: reason=no transport connected
zbus: safety=no host request sent
```

## Smoke test command

```sh
./smoke/smoke-zbus-v0.sh
```

To run the full milestone ladder:

```sh
./smoke/smoke-all.sh
```

## Expected passing smoke output

The ZBUS V0 smoke test prints:

```text
PASS ZIGN01D ZBUS V0 smoke
```

The full smoke ladder prints:

```text
PASS ZIGN01D full smoke ladder
```

## Manual verification checklist

After booting the kernel and running the command examples, verify these exact strings are present in the serial output:

- `ZBUS000`
- `zbus_interface=present`
- `zbus_transport=none`
- `zbus_connected=no`
- `zbus_providers=none`
- `zbus: safety=no host request sent`
- `net: safety=no network request sent`
- `sms: safety=not-sent`
- `modem: real_modem=not-attached`

Also verify the output does not claim internet success, SMS delivery, modem attachment, calls, Wi-Fi calling, connected host bridge, or available providers.

## Files added

- `kernel/comm/zbus.zig`
- `docs/ZBUS_V0_SPEC.md`
- `docs/ZBUS_ROADMAP.md`
- `docs/ZBUS_SECURITY_MODEL.md`
- `docs/ZBUS_V0_AUDIT.md`
- `docs/MILESTONE_ZBUS_V0_USER_GUIDE.md`
- `docs/DOCUMENTATION_CONTRACT.md`
- `smoke/smoke-zbus-v0.sh`
- `smoke/smoke-all.sh`

## Files changed

- `kernel/console/shell.zig`
- `kernel/comm/comm.zig`
- `kernel/comm/net.zig`
- `kernel/comm/sms.zig`
- `kernel/comm/modem.zig`
- `smoke/smoke-comm-v0.sh`
- `README.md`

## Next milestone

The next recommended milestone is MEMORY V0. It should add a memory map command, physical memory region report, kernel image boundaries, stack boundary report, allocator plan, no heap allocator unless proven safe, milestone docs, and `smoke/smoke-memory-v0.sh`.
