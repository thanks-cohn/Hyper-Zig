# COMM Bridge Roadmap

The communication bridge is a prototype path for proof-driven development. It allows ZIGN01D to learn request framing and host interaction while the kernel still lacks direct networking, modem, and hardware drivers.

## Linux host bridge: prototype path, not final dream

A Linux host bridge is useful because the host can safely own mature networking, modem access, logging, permissions, and carrier-specific complexity while the guest kernel proves a narrow protocol. It is not the final dream: the final system should move more trust and capability into owned, auditable ZIGN01D components when the proof ladder reaches that stage.

## COMM V0: shape only

COMM V0 has no transport. It exposes command shape and honest status only:

- `bridge=not-connected`.
- `bridge_transport=none`.
- `net_backend=none`.
- `sms_backend=none`.
- `modem_backend=none`.
- `real_internet=not-implemented`.
- `real_sms_send=not-implemented`.
- `real_sms_receive=not-implemented`.
- `real_modem=not-attached`.
- `real_calls=not-implemented`.
- `wifi_calling=not-implemented`.

## COMM V1: fake host bridge protocol

COMM V1 should define a tiny line-based bridge protocol with fake/scripted responses only:

- `PING`.
- `NET_GET http://example.com`.
- `SMS_INBOX`.
- `SMS_SEND +15551234567 hello`.
- `MODEM_STATUS`.

The goal is to prove framing and state-machine behavior, not real network or modem access.

## Future path to host-bridged internet

After fake protocol proof, a later milestone can allow a Linux bridge process to perform a constrained host HTTP request and return a bounded response. That milestone must explicitly report whether a request came from the bridge, avoid direct virtio-net claims, and preserve logs showing host involvement.

## Future path to host-bridged fake SMS

Before touching real SMS, the bridge can return scripted inbox entries and scripted send acknowledgements. Those acknowledgements must be labeled fake/scripted. This stage is useful for UI and command flow, but it is not real SMS.

## Future path to real modem status

A later Linux host bridge can query modem status through host tools or APIs and return bounded fields such as attachment, SIM status, signal, registration, and carrier. The guest should continue to report that the host bridge is the source of truth until direct modem support exists.

## Future path to real SMS receive/send

Real SMS over a host bridge should come after modem status is proven. It needs safety gates for phone numbers, message bodies, consent, logs that do not leak private text, and clear send/receive failure handling. The kernel must never print fake delivered or received status.

## Future path to direct modem control

Direct modem control comes later than host bridge prototypes. It requires transport drivers, modem command protocols, SIM state, registration handling, security policy, and carrier-specific error handling. COMM V0 deliberately does none of that.
