# ZBUS V0 Audit

## Files added

- `kernel/comm/zbus.zig` adds the static ZBUS V0 status and command output helpers.
- `docs/ZBUS_V0_SPEC.md` defines the V0 technical contract.
- `docs/ZBUS_ROADMAP.md` defines staged future ZBUS milestones.
- `docs/ZBUS_SECURITY_MODEL.md` defines security expectations for future providers.
- `docs/ZBUS_V0_AUDIT.md` records this audit.
- `docs/MILESTONE_ZBUS_V0_USER_GUIDE.md` explains ZBUS V0 for users.
- `docs/DOCUMENTATION_CONTRACT.md` defines future milestone documentation requirements.
- `smoke/smoke-zbus-v0.sh` verifies the ZBUS V0 command surface.
- `smoke/smoke-all.sh` runs the full smoke ladder.

## Files changed

- `kernel/console/shell.zig` adds ZBUS commands to the shell and includes ZBUS fields in `status`.
- `kernel/comm/comm.zig` initializes ZBUS and references it from COMM status.
- `kernel/comm/net.zig` labels the future network provider as ZBUS while still reporting no request sent.
- `kernel/comm/sms.zig` labels the future SMS provider as ZBUS while still reporting not sent.
- `kernel/comm/modem.zig` labels the future modem provider as ZBUS while still reporting no real modem attached.
- `smoke/smoke-comm-v0.sh` keeps the COMM smoke aligned with the new ZBUS bridge label.
- `README.md` points users to the ZBUS V0 guide and documentation contract.

## Commands added

- `zbus`
- `zbus status`
- `zbus ping`
- `zbus providers`

## Tests that prove the milestone

- `./smoke/smoke-zbus-v0.sh` checks the ZBUS boot marker, commands, status fields, COMM reference, and no-request safety outputs.
- `./smoke/smoke-all.sh` runs the build plus V0, V1, V2, V3, V4, COMM V0, and ZBUS V0 smoke tests in order.

## Intentionally missing

ZBUS V0 intentionally omits real internet, real SMS, SMS receive, real modem access, calls, Wi-Fi calling, real host transport, host files, and host time. No ZBUS V0 command sends a host request.

## Manual command-surface verification

Boot the kernel, wait for `zign01d>`, and run:

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

Look for these exact strings:

```text
ZBUS000
zbus_interface=present
zbus_transport=none
zbus_connected=no
zbus_providers=none
zbus: safety=no host request sent
net: safety=no network request sent
sms: safety=not-sent
modem: real_modem=not-attached
```
