# COMM V0 Plan: Honest Communication Scaffold

COMM V0 makes ZIGN01D communication-shaped without claiming it can communicate with the outside world yet. It adds small kernel command surfaces for a future host bridge, internet path, SMS/text path, and modem status path.

## What COMM V0 proves

COMM V0 proves only these boundaries:

- Communication commands exist in the shell.
- Bridge status shape exists.
- Net command shape exists.
- SMS command shape exists.
- Modem status command shape exists.
- Kernel status reports communication boundaries honestly.
- No fake internet or SMS success is claimed.

The proof is intentionally simple: every status field is static, auditable, and negative where the capability is absent.

## What COMM V0 does not prove

COMM V0 does not prove:

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

## Why internet bridge comes before real SMS

Internet first is the better engineering path because HTTP-style request/response tests can be made deterministic through a Linux host bridge before the kernel touches carrier, SIM, modem, radio, or message-center state. A host-bridged internet milestone can prove framing, request dispatch, timeouts, errors, transcripts, and safety without pretending the guest has a network driver.

Real SMS depends on more external truth: modem attachment, SIM state, registration, signal, carrier policy, phone numbers, message routing, privacy handling, and failure modes. COMM V0 therefore prepares SMS command shape now, but keeps real SMS as not implemented.

## Why SMS/texting remains the first emotional showcase

Texting is the strongest user-facing proof that the communication dream matters. The emotional showcase is not a fake success line; it is eventually seeing a message path become real through staged proofs. COMM V0 preserves that path by making `sms inbox`, `sms send`, and `sms wait` visible while clearly reporting that no message is sent or received.

## Why Wi-Fi calling is not first

Wi-Fi calling is not first because it combines networking, carrier authentication, voice signaling, audio routing, emergency-service policy, and modem/carrier integration. It is a later systems milestone, not a scaffold milestone. COMM V0 reports `wifi_calling=not-implemented` and does not claim call audio or calls work.

## COMM V0 command plan

- `comm`: print the full communication boundary state.
- `bridge status`: show that no bridge transport is connected.
- `net status`: show no internet backend and no direct virtio-net.
- `net get <url>`: echo the requested URL and report that no network request was sent.
- `sms inbox`: report inbox unavailable.
- `sms send <number> <text>`: report send not implemented and safety not sent.
- `sms wait`: report incoming messages unavailable.
- `modem status`: report no real modem attached.

## Next milestone

COMM V1 should define a tiny fake host bridge protocol with scripted responses only. It should not add real internet, real SMS, real modem access, real calls, or Wi-Fi calling.
