# ZBUS Roadmap

ZBUS milestones are intentionally staged so the kernel does not claim host capabilities before proof exists.

## ZBUS V0: kernel command scaffold only

- Static kernel-side status values.
- Shell commands for `zbus`, `zbus status`, `zbus ping`, and `zbus providers`.
- No host transport.
- No providers.
- No real requests sent.

## ZBUS V1: fake/scripted host daemon

- A scripted host daemon may exist for deterministic protocol tests.
- Fake responses must be labeled scripted or fake.
- Kernel output must not claim real internet, SMS, modem, call, or file capability.

## ZBUS V2: local serial/stdio transport

- Add a bounded local transport for request and response exchange.
- Preserve explicit `OK` and `ERR` responses.
- Keep provider allowlists and field-size bounds.

## ZBUS V3: host file/time providers

- Add bridge-backed file and time providers after transport proof.
- Label all results as host-backed or bridge-backed.
- Keep file paths allowlisted and bounded.

## ZBUS V4: bridge-backed HTTP provider

- Add a bridge-backed HTTP provider after the transport and provider security model are proven.
- Label network results as bridge-backed.
- Preserve explicit failures for unavailable network access.

## ZBUS V5: bridge-backed SMS provider

- Add a bridge-backed SMS provider only with explicit allowlisting and safe logging defaults.
- Do not log private SMS content by default.
- Preserve explicit failure for unavailable SMS provider states.

## ZBUS VNATIVE: replace bridge providers with native drivers

- Native drivers may replace bridge-backed providers when hardware support is implemented and tested.
- Native output must be labeled native rather than bridge-backed.
- Bridge-backed providers can remain as development or host-test options.
