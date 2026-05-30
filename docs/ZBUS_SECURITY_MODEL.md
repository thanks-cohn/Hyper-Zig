# ZBUS Security Model

ZBUS is a host capability bus, not a blanket host escape hatch. The default state is no connected transport and no providers.

## No ambient authority

The kernel must not gain implicit authority just because ZBUS exists. Each request must name a provider and carry bounded parameters.

## Provider allowlist

Future host daemons must use a provider allowlist. Unlisted providers must fail explicitly with an `ERR` response and a machine-readable code.

## Bounded requests

Requests must have bounded line length, bounded field length, and bounded response size before any transport is enabled. Oversized or malformed requests must fail closed.

## Explicit provider names

Requests and responses must include explicit services such as `NET.GET`, `SMS.SEND`, `SMS.INBOX`, `MODEM.STATUS`, `TIME.NOW`, or `FILE.READ`. Generic hidden host operations are not allowed.

## Private SMS content

Default logs must not include private SMS body content. Tests may use synthetic values, but production-oriented logging must prefer metadata and explicit redaction.

## No raw modem access by default

ZBUS must not expose raw modem control by default. Modem providers must be narrow, documented, and allowlisted.

## Host-backed labeling

All host-backed or bridge-backed results must be labeled as host-backed or bridge-backed so users do not confuse them with native hardware support.

## Explicit failure

Failure must be explicit. There must be no silent success, fake internet, fake SMS, fake modem access, fake calls, or fake Wi-Fi calling.
