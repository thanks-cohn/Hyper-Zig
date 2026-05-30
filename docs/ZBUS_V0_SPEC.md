# ZBUS V0 Technical Specification

## What ZBUS is

ZBUS is the ZIGN01D host capability bus. It defines the plug that future communication providers can use to ask a trusted host-side component for bounded capabilities such as file access, time, HTTP, SMS, or modem status.

In V0, ZBUS is only a kernel command scaffold and status contract. The interface is present, but no transport is connected and no provider is available.

## What ZBUS is not

ZBUS V0 is not native hardware support. It does not drive a modem, Wi-Fi chipset, NIC, storage device, SIM, or radio.

ZBUS is not Linux compatibility. It does not implement POSIX, Linux syscalls, sockets, a userspace daemon ABI, or a Linux driver model.

ZBUS is a host capability bridge design. A future ZIGN01D kernel will send bounded requests to a future host daemon. The future host daemon will perform only allowed actions and return structured responses. All bridge-backed results must be labeled bridge-backed or host-backed. Native implementations can replace ZBUS providers later when real drivers exist.

## V0 command surface

The V0 shell exposes these commands:

```text
zbus
zbus status
zbus ping
zbus providers
```

The commands are read-only diagnostics. They do not send host requests.

## V0 status fields

V0 reports these static fields:

```text
zbus_interface=present
zbus_transport=none
zbus_connected=no
zbus_providers=none
zbus_net=not-implemented
zbus_sms=not-implemented
zbus_modem=not-implemented
zbus_files=not-implemented
zbus_time=not-implemented
```

## Example request format

Future ZBUS requests are one line each:

```text
ZBUS/0 PING id=1
ZBUS/0 NET.GET id=2 url=http://example.com
ZBUS/0 SMS.SEND id=3 to=+15551234567 text=hello
ZBUS/0 SMS.INBOX id=4
ZBUS/0 MODEM.STATUS id=5
ZBUS/0 TIME.NOW id=6
ZBUS/0 FILE.READ id=7 path=/demo.txt
```

V0 does not emit these requests. They define the contract that later milestones must preserve or explicitly revise.

## Example response format

Future responses have one response header per line. Every response includes `OK` or `ERR` and an `id`:

```text
ZBUS/0 OK id=1 service=PING message=pong
ZBUS/0 ERR id=3 service=SMS.SEND code=NOT_IMPLEMENTED message="sms provider unavailable"
```

## Failure format

Every failed request must return `ERR`, the original `id`, a `service`, and a machine-readable `code`. Human-readable text may appear in `message`, but success must never be inferred from text alone.

## Protocol rules

- One request per line.
- One response header per line.
- Every response includes `OK` or `ERR`.
- Every response includes `id`.
- Every failure includes `code`.
- No silent success.
- No fake internet.
- No fake SMS.
- No fake modem.
- No fake call support.
- Field sizes must be bounded before a real transport is enabled.
- Logs must avoid leaking private SMS content by default.

## Safety rules

- ZBUS V0 sends no host request.
- ZBUS V0 has no ambient authority.
- ZBUS V0 exposes no host file, network, SMS, modem, call, or time provider.
- Any future provider must identify itself explicitly.
- Any future host-backed result must be labeled host-backed or bridge-backed.
- Failure must be explicit and visible to shell users and smoke tests.

## Exact V0 limitations

ZBUS V0 intentionally does not implement real internet, SMS send, SMS receive, modem access, calls, Wi-Fi calling, host file access, host time, or a real transport. `zbus ping` reports `not-implemented` and `safety=no host request sent` because there is no connected transport.
