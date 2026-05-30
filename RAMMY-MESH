=```
===============================================================================
RAMMY MESH
================================================================================

A ZIGN01D design document.

Status:
    Vision document with engineering constraints.

Purpose:
    Define the long-term RAMMY Mesh idea without pretending the hard parts are
    solved.

Core idea:
    A single phone is a machine.
    Many phones can become a larger machine.

    RAMMY Mesh is the attempt to make trusted ZIGN01D devices cooperate as one
    local compute fabric: sharing memory capacity, model shards, cache, identity,
    storage, and selected compute work.

    Not cloud.
    Not rental intelligence.
    Not a hidden server.

    A mega mind made out of countless smaller parts.


================================================================================
1. THE DREAM
================================================================================

Modern phones are powerful, but isolated.

Each phone has its own CPU, RAM, storage, battery, sensors, radios, identity
material, and thermal limits. When the phone is not enough, the modern answer is
usually:

    - buy a bigger phone
    - rent cloud compute
    - depend on a vendor account
    - send private work to someone else's machine

RAMMY Mesh asks for another path.

    What if the user's devices could cooperate?

    What if a phone could dock into a larger computer and become part of it?

    What if many trusted phones, tablets, small boards, desktops, and local
    machines could expose selected memory and compute capacity to each other?

    What if a model too large for one device could become usable across many?

The dream is not that every small device magically becomes a datacenter.

The dream is that local ownership scales.

A ZIGN01D phone should not merely sync with a computer.
A ZIGN01D phone should be able to become part of one.


================================================================================
2. WHAT RAMMY MESH IS
================================================================================

RAMMY Mesh is a local trusted device fabric.

It is a system for connecting ZIGN01D machines so they can coordinate resources
without treating the cloud as the default owner of the user's future.

A RAMMY Mesh node may provide:

    - memory capacity
    - model shard storage
    - hot/cold cache regions
    - secure identity material
    - local compute workers
    - encrypted storage blocks
    - network relay services
    - debug and recovery channels
    - device health telemetry
    - bandwidth and latency measurements

The first serious target is not general magic RAM.

The first serious target is deliberate workload-aware cooperation.

RAMMY should not blindly pretend remote memory is local memory.

Remote memory has different latency.
Remote memory has different bandwidth.
Remote memory can disappear.
Remote memory can stall.
Remote memory can lie if the node is not trusted.
Remote memory must be measured, logged, authenticated, and designed around.

The correct design is honest:

    local RAM      = fastest and most trusted
    docked RAM     = useful, but slower
    mesh RAM       = useful for capacity and sharding
    storage        = fallback, not RAM
    cloud          = optional, never assumed


================================================================================
3. WHAT RAMMY MESH IS NOT
================================================================================

RAMMY Mesh is not a claim that a pile of phones beats a high-end GPU.

It does not pretend to beat:

    - HBM-equipped datacenter GPUs
    - high-end AI accelerators
    - dedicated inference servers
    - tightly coupled NUMA systems
    - CXL-class memory hardware when used properly

A serious GPU has extreme memory bandwidth and specialized compute hardware.
A phone mesh over USB4, Thunderbolt, Wi-Fi, or other external fabric will not
match that by wishful thinking.

RAMMY Mesh is not successful because it wins every benchmark.

RAMMY Mesh is successful when it makes the impossible local.

A normal phone cannot comfortably run a 70B-class model.
A normal laptop may not hold it well.
A cloud service can run it, but the user does not own the machine.

RAMMY Mesh exists for a different question:

    Can a user-owned cluster of trusted local machines run something larger than
    any one of them can hold?

That is the mountain.


================================================================================
4. REALITY OF SPEED
================================================================================

For large language models, memory bandwidth matters.

A 70B-class model is huge. Even quantized, it can require tens of gigabytes for
weights, plus additional memory for context, KV cache, runtime state, and working
buffers.

Rough target model:

    model class:        70B instruct model
    quantization:       Q4 or equivalent
    minimum context:    4K
    stretch context:    8K
    benchmark metric:   sustained generation speed after prompt ingestion

A realistic RAMMY ladder:

    0.1 - 0.5 tokens/sec
        painful proof of life
        the monster speaks, but barely

    1 token/sec
        minimum viable miracle
        slow, but real

    2 tokens/sec
        minimum competitive RAMMY target
        useful because one phone could not do it at all

    5 tokens/sec
        public V1 target
        slow compared to cloud, but usable as sovereign local intelligence

    8 - 10 tokens/sec
        strong result
        people stop laughing

    20+ tokens/sec
        long-term serious target
        likely requires better interconnects, accelerators, smarter sharding,
        or dedicated hardware support

RAMMY Mesh V1 target:

    70B Q4
    4K context
    trusted local fabric
    no cloud
    no hidden GPU server
    no SSD paging pretending to be RAM
    2 tokens/sec minimum competitive result
    5 tokens/sec public target

This is not fantasy.
This is hard.
That is why it is worth writing down.


================================================================================
5. FABRIC ASSUMPTIONS
================================================================================

Possible RAMMY transport layers:

    - virtio simulation in QEMU
    - Unix sockets for early host simulation
    - Ethernet for development clusters
    - USB-C device mode
    - USB4 / Thunderbolt-class docking
    - PCIe / M.2 module experiments
    - future CXL-like memory semantics if hardware permits

Important distinction:

    Bandwidth is not latency.
    Raw link speed is not usable workload speed.
    Theoretical speed is not sustained speed.
    A switched fabric is not the same thing as local RAM.

Thunderbolt 3 / USB4-class links may offer high headline bandwidth, but RAMMY
must assume real overhead:

    - protocol overhead
    - switching overhead
    - encryption overhead
    - scheduling overhead
    - cache misses
    - retransmission
    - node contention
    - thermal throttling
    - power limits
    - asymmetric devices
    - sudden disconnects

RAMMY must measure reality, not marketing.

Every serious RAMMY run should log:

    - node count
    - node identities
    - node memory offered
    - node memory accepted
    - transport type
    - measured bandwidth
    - measured latency
    - transfer size distribution
    - stall time
    - retry count
    - cache hits
    - cache misses
    - token timing
    - thermal throttling if visible
    - node dropout events


================================================================================
6. DESIGN RULES
================================================================================

Rule 1:
    Do not pretend remote RAM is local RAM.

Rule 2:
    Prefer explicit sharding over accidental paging.

Rule 3:
    Keep hot data close to compute.

Rule 4:
    Keep KV cache near the active inference worker when possible.

Rule 5:
    Stream cold layers predictably.

Rule 6:
    Batch transfers.

Rule 7:
    Compress and quantize aggressively when useful.

Rule 8:
    Measure every stall.

Rule 9:
    Fail gracefully when a node disappears.

Rule 10:
    Never pass a benchmark without logs proving what happened.

Bad design:

    application touches memory
        ->
    kernel randomly faults remote pages
        ->
    fabric thrashes
        ->
    token speed dies
        ->
    logs hide the truth

Good design:

    workload declares memory plan
        ->
    RAMMY maps local/hot/cold/sharded regions
        ->
    scheduler places workers near data
        ->
    fabric prefetches predictable regions
        ->
    logs expose bandwidth, latency, stalls, and failures


================================================================================
7. RAMMY-LLM MODE
================================================================================

The first serious RAMMY showcase should be LLM inference because it exposes the
truth quickly.

A RAMMY-LLM runtime should support:

    - model shard placement
    - quantized model formats first
    - memory region pinning
    - KV cache placement policy
    - prefetch planning
    - transfer batching
    - node health checks
    - node trust verification
    - deterministic benchmark mode
    - token-by-token timing logs
    - fabric stall reporting
    - degraded mode when nodes vanish

The goal is not to hide complexity.

The goal is to control it.

RAMMY-LLM should be able to say:

    This model is too large for one node.
    These nodes are trusted.
    These shards are placed here.
    This cache lives here.
    This transport is the bottleneck.
    This token was slow because this node stalled.
    This run achieved this speed under these exact conditions.

The system must tell the truth.


================================================================================
8. SECURITY MODEL
================================================================================

RAMMY Mesh is only useful if trust is explicit.

A node must not be accepted merely because it is nearby.

A node should prove:

    - device identity
    - OS identity
    - RAMMY protocol version
    - allowed capabilities
    - user authorization
    - session freshness
    - encryption support
    - health state where possible

Capabilities should be explicit.

A node may be allowed to provide:

    - storage but not compute
    - memory but not identity
    - cache but not secrets
    - debug logs but not private data
    - model shards but not user documents

RAMMY should be capability-based, not ambient-trust-based.

The mesh should assume:

    - nodes can disconnect
    - nodes can be stolen
    - nodes can overheat
    - nodes can be slow
    - nodes can be compromised
    - links can be observed
    - logs can leak information if careless

Therefore:

    - encrypt transport
    - authenticate nodes
    - avoid placing secrets on weak nodes
    - distinguish model weights from private user data
    - make trust visible
    - make revocation possible


================================================================================
9. PHONE AS MODULE
================================================================================

ZIGN01D targets RISC-V partly because the long-term dream is hardware ownership.

A ZIGN01D phone should eventually operate in three modes:

    1. Handheld Mode

        The device behaves as a normal phone.

    2. Docked Mode

        The device connects to a larger computer and exposes selected services:
            - storage
            - identity
            - networking
            - debug console
            - recovery interface
            - memory service
            - compute workers

    3. Fabric Mode

        Multiple trusted ZIGN01D devices cooperate as a local compute mesh.

The phone should not plug in as a dumb peripheral.

The phone should plug in as a machine.


================================================================================
10. DEVELOPMENT LADDER
================================================================================

V0:
    Bootable RISC-V ZIGN01D kernel in QEMU.

V1:
    Shell, logs, memory map, storage basics, network basics.

V2:
    Local RAMMY simulator over processes or QEMU nodes.

V3:
    RAMMY protocol over sockets/virtio with real logs.

V4:
    RAMMY-LLM benchmark harness with fake/small model shards.

V5:
    Real quantized model shard loading across multiple machines.

V6:
    7B-class local mesh inference.

V7:
    13B / 30B-class mesh inference.

V8:
    70B Q4 proof of life.

V9:
    70B Q4 at 2 tokens/sec sustained.

V10:
    70B Q4 at 5 tokens/sec sustained.

VX:
    Docked ZIGN01D hardware module with RAMMY services.

Do not skip the simulator.
Do not skip the logs.
Do not skip the boring measurements.

The fantasy only survives if the measurements are honest.


================================================================================
11. ACCEPTANCE TESTS
================================================================================

A RAMMY milestone is not accepted because it prints a success message.

A RAMMY milestone is accepted only if it proves the system worked.

Required artifacts for serious RAMMY tests:

    logs/latest/rammy.log
    logs/latest/fabric.log
    logs/latest/nodes.log
    logs/latest/bandwidth.log
    logs/latest/latency.log
    logs/latest/inference.log
    smoke/transcripts/rammy-latest.txt

Required fields:

    - test name
    - git commit
    - build date
    - host machine
    - node count
    - node IDs
    - transport type
    - model name or synthetic workload name
    - quantization
    - context size
    - total memory required
    - local memory used
    - remote memory used
    - storage fallback used: yes/no
    - measured tokens/sec
    - median tokens/sec across runs
    - best run
    - worst run
    - stall time
    - failure count
    - dropout count

A test must fail if:

    - nodes are missing
    - logs are missing
    - transcript is missing
    - model shards are missing
    - hidden cloud access is detected
    - storage paging is used without being declared
    - token timing is not recorded
    - benchmark conditions are not printed

No fake smoke tests.
No echo-only proof.
No pretend success.


================================================================================
12. COMPETITIVE POSITION
================================================================================

Modern phone:

    sealed appliance
    one device
    vendor ecosystem
    cloud fallback
    app store control
    opaque background behavior

RAMMY ZIGN01D direction:

    user-owned machine
    many devices
    local trusted fabric
    explicit capabilities
    inspectable logs
    workload-aware memory
    optional cloud, never default

The first comparison is not against datacenter hardware.

The first comparison is against helplessness.

If one phone cannot run the model, and ten trusted local nodes can, RAMMY wins a
specific and meaningful victory.

Not the fastest.
Not the cheapest.
Not the easiest.

Owned.
Local.
Inspectable.
Expandable.

That is the point.


================================================================================
13. FINAL STATEMENT
================================================================================

RAMMY Mesh is the belief that personal machines should be allowed to cooperate.

Not as disposable accessories.
Not as cloud terminals.
Not as vendor-owned endpoints.

As machines.

A phone should be able to stand alone.
A phone should be able to dock into a larger body.
A phone should be able to join other trusted machines and become part of a
larger mind.

The honest first mountain:

    70B Q4
    4K context
    trusted local fabric
    2 tokens/sec minimum competitive result
    5 tokens/sec public V1 target
    no cloud
    no hidden server
    full logs

A mega mind made out of countless smaller parts.

That is RAMMY Mesh.
================================================================================

```
