# ZIGN01D Logging and Breadcrumb Doctrine

ZIGN01D logs are operational evidence, not decoration.

> Real viability tests. Never fake green checkmarks. Never hollow victories.
> We must be cleverer than our excuses and wilier than our inner saboteur.
> Build steadily. Build honestly. Build with zeal.
> Every test should answer a real question.
> Every log should tell a story.
> Every breadcrumb should lead us home.
> Until there is nothing left but genuine progress.
> Not a dithering skeleton of "it's something,"
> but living proof that it works.

## Required format

Every kernel breadcrumb uses this exact shape:

```text
[ZIGN01D][LEVEL][SUBSYSTEM][CODE] message
```

The kernel-side helper for V1 is `kernel/diag/breadcrumb.zig`. It deliberately writes static strings to UART and avoids heap allocation, libc, `std.debug`, and generic formatting.

## Log levels

- `TRACE`: extremely fine-grained path evidence, normally disabled or rare.
- `DEBUG`: developer-focused state that is useful during bring-up but not required for normal proof.
- `INFO`: a real success, state transition, or command reaching a meaningful point.
- `WARN`: a degraded path, explicit placeholder, missing driver, or non-fatal limitation.
- `ERROR`: a failed operation that can return or continue.
- `PANIC`: unrecoverable kernel failure.

## Subsystems

Allowed subsystem names for V1 are:

- `BOOT`
- `UART`
- `MEM`
- `IRQ`
- `TIMER`
- `SCHED`
- `TASK`
- `DEV`
- `SYSCALL`
- `NET`
- `PHONE`
- `INIT`
- `SHELL`
- `SMOKE`
- `BUILD`
- `QEMU`
- `PANIC`

New subsystems must update this doctrine and must expose init, status, shell visibility, boot breadcrumbs, failure breadcrumbs, and inspect hints.

## Code naming rules

Codes are short, stable, and subsystem-scoped:

- `BOOT001`, `BOOT090`
- `TASK001`
- `SYS001`
- `NET002`
- `PHONE003`

Use increasing numbers for related breadcrumbs, but do not renumber old codes casually. Tests and transcripts may rely on them.

## Useful breadcrumbs

A useful breadcrumb answers at least one real diagnostic question:

- Where did execution reach?
- Which subsystem changed state?
- Which real data structure is being exposed?
- Which driver or trap boundary is missing?
- Which file should be inspected next?

A breadcrumb is not useful if it only says that a name exists.

## What must never be logged

Never log secrets, credentials, SIM data, private message bodies, access tokens, keys, or arbitrary user payloads. For phone and network paths, log capability and state, not sensitive content.

Never log fake success. A missing network driver must say the driver is missing. A call command must not pretend to place a call. An SMS command must not pretend to send a message.

## Failure message requirements

Every error or warning that represents failure must answer:

1. Where did this happen?
2. What was being attempted?
3. What failed?
4. What state was observed?
5. What should be inspected next?

When the message cannot fit all details in one kernel line, the shell command or smoke script must print the inspect hint immediately nearby.

## Good logs

```text
[ZIGN01D][WARN][NET][NET002] network driver not implemented; inspect kernel/net/net.zig and virtio-mmio device registry
[ZIGN01D][WARN][PHONE][PHONE003] sms unavailable; inspect kernel/phone/phone.zig, modem driver, cellular stack
[ZIGN01D][INFO][TASK][TASK001] task subsystem initialized
```

These are good because they name the subsystem, the condition, the truth of the missing feature, and the next inspection path.

## Bad logs

```text
network ok
phone ready
[ZIGN01D][INFO][NET][NET777] ping worked
```

These are bad because V1 has no network driver, no modem driver, no cellular stack, and no real ping path. They would be fake green checkmarks.
