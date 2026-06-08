# MINIMUS-LOG MAXIM

## The Principle

Never make a human read more than necessary.

Never throw away information that may later matter.

The ideal system produces the minimum amount of console output required for a human to understand what is happening while simultaneously recording the maximum amount of useful information to durable storage.

The console is for humans.

The log is for history.

The transcript is for evidence.

The machine should respect all three.

---

# The Problem

Most software fails in one of two ways.

## Failure Mode A: Log Spam

The console becomes a firehose.

Thousands of lines scroll by.

Important information disappears.

Humans stop reading.

When failure occurs, nobody knows what happened.

The information existed but was effectively invisible.

## Failure Mode B: Silent Systems

The console remains quiet.

Little or no information is recorded.

A failure occurs.

Nobody knows why.

The information never existed.

Both approaches waste time.

---

# The Minimus-Log Maxim

Produce:

- Minimal console noise
- Maximum evidence capture

At all times.

The operator should receive only information that affects immediate understanding.

The machine should record everything useful for future investigation.

---

# The Three-Tier Output Model

## Tier 1: Console

Purpose:

Human situational awareness.

Characteristics:

- Short
- Dense
- High signal
- Easy to scan
- Immediate relevance

Example:

[BUILD] PASS
[QEMU] BOOTED
[CSR] VERIFIED
[SMOKE] PASS

---

## Tier 2: Structured Log

Purpose:

Technical investigation.

Characteristics:

- Timestamped
- Structured
- Searchable
- Machine-readable

Example:

[2026-06-08T09:50:02Z][CSR][INFO]
hart_id=0
sstatus=0x8000000200006020
stvec=0x80200000

---

## Tier 3: Transcript

Purpose:

Historical reconstruction.

Characteristics:

- Raw
- Complete
- Reproducible
- Archivable

The transcript should allow a future engineer to answer:

"What actually happened?"

without rerunning the experiment.

---

# The Golden Rule

Every important console event should have a corresponding durable record.

Every durable record should not necessarily appear on the console.

This distinction is critical.

---

# Human Time Is Expensive

CPU time is cheap.

Disk space is cheap.

Human attention is expensive.

Therefore:

Store aggressively.

Display conservatively.

---

# The Evidence Ladder

Level 0:
No logging.

Level 1:
Console only.

Level 2:
Console + file log.

Level 3:
Structured logs.

Level 4:
Transcripts.

Level 5:
Reproducible build records.

Level 6:
Machine state capture.

Level 7:
Historical reconstruction.

The goal is Level 7.

---

# Application To Kernel Development

For kernels:

Console:
- PASS
- FAIL
- BOOT
- PANIC
- READY

Logs:
- memory state
- CSR values
- trap causes
- scheduler decisions
- allocation activity
- device enumeration

Transcripts:
- complete boot session
- complete smoke session
- complete test session

The operator sees almost nothing.

The repository remembers everything.

---

# The Law

If a human must repeatedly rerun a process to discover what happened, the logging system has failed.

If the answer already exists in a durable record, the logging system has succeeded.

Therefore:

Minimize console output.

Maximize retained evidence.

This is the Minimus-Log Maxim.
