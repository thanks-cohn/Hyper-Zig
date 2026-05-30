# COMM V0 Audit

COMM V0 is an honesty audit for the communication scaffold. It documents exactly where the boundary is and what the kernel refuses to claim.

## Proved by COMM V0

- Communication command exists: `comm`.
- Bridge status command exists: `bridge status`.
- Network command shape exists: `net status` and `net get <url>`.
- SMS command shape exists: `sms inbox`, `sms send <number> <text>`, and `sms wait`.
- Modem status command exists: `modem status`.
- Boot logs include `[ZIGN01D][INFO][COMM][COMM000] communication scaffold present; bridge not connected`.
- Kernel status includes `comm_interface=present` and negative communication capability fields.
- `net get` says no network request was sent.
- `sms send` says not implemented and not sent.
- `modem status` says no real modem is attached.

## Not proved by COMM V0

- Real internet access.
- Direct virtio-net.
- Host bridge transport.
- Real SMS sending.
- Real SMS receiving.
- Real modem access.
- Real calls.
- Call audio.
- Wi-Fi calling.
- Cellular internet.
- Direct hardware modem driver.

## Honesty requirements

Runtime output must not claim:

- Internet works.
- SMS was sent.
- SMS was received.
- A real modem is attached.
- Calls work.
- Wi-Fi calling works.
- Cellular works.

## Why the order is internet bridge, then SMS

The bridge should prove internet request framing before real SMS because an internet request can be constrained, replayed, logged, and tested without carrier or modem state. SMS remains the first emotional showcase because it is the human-visible communication moment, but it should arrive after bridge mechanics are proven honestly.

## Audit checks

The COMM V0 smoke test boots QEMU, waits for the shell, runs the communication commands, checks the COMM000 marker, checks status fields, and rejects fake success language.
