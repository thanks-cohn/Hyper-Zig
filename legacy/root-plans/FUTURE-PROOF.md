================================================================================
RAMMY MESH
================================================================================

A ZIGN01D research and architecture note.

File:
    docs/RAMMY_MESH.md

Status:
    Long-term architecture.
    Realistic assumptions.
    Measurement-first design.

Core idea:
    A phone should not only sync with a computer.

    A phone should be able to become part of one.

    RAMMY Mesh is the ZIGN01D proposal for a trusted local compute fabric made
    from owned devices: phones, laptops, desktops, docks, and future modules.

    The goal is not to pretend that many small devices magically become a
    datacenter.

    The goal is to make local ownership scale.


================================================================================
1. THE PERSONAL MACHINE BECOMES PLURAL
================================================================================

Modern personal computing is usually built around one active device at a time.

A phone is a phone.
A laptop is a laptop.
A desktop is a desktop.
An old phone becomes e-waste, a drawer object, or a backup device.

RAMMY Mesh proposes a different model.

    One user.
    Many owned devices.
    One trusted local fabric.

In this model, a ZIGN01D phone can operate in three modes:

    1. Handheld Mode
        The device behaves as a normal phone.

    2. Docked Mode
        The device connects to a larger computer and exposes selected services:
            - storage
            - identity
            - memory regions
            - model shards
            - cache
            - compute queues
            - debug and recovery channels

    3. Fabric Mode
        Multiple trusted ZIGN01D devices cooperate as a local machine made of
        smaller machines.

This is the central idea:

    The phone is not a peripheral.
    The phone is a machine.

    When connected to other trusted machines, it should remain a machine.


================================================================================
2. HISTORICAL LINEAGE
================================================================================

RAMMY Mesh is not disconnected from operating systems history.

Plan 9 from Bell Labs explored a world where distributed resources could be
named, mounted, and composed through clean namespaces and 9P.

Amoeba explored capability-based distributed computing and processor pools.

Sprite explored distributed file systems and process migration, using idle
workstations as useful compute resources.

These systems asked a question that still matters:

    How should many machines behave when the user wants one coherent computing
    experience?

RAMMY Mesh asks that question again under modern conditions:

    - users own multiple powerful devices
    - phones have serious compute and memory
    - local AI is becoming valuable
    - privacy matters more, not less
    - cloud dependence is not always acceptable
    - interconnects are getting faster
    - old devices still contain usable compute
    - personal hardware should not be treated as disposable

RAMMY is not a claim that distributed systems are new.

RAMMY is a claim that distributed personal computing deserves to return as a
first-class design target.


================================================================================
3. CURRENT INTERCONNECT REALITY
================================================================================

RAMMY must start by telling the truth about links.

Local RAM is fast.
External fabrics are slower.
Latency matters.
Switching matters.
Protocol overhead matters.
Thermals matter.

A RAMMY system must never assume that remote memory behaves like local memory.

Current high-end external interconnects are already interesting:

    Thunderbolt 5:
        80 Gbps bidirectional bandwidth
        up to 120 Gbps one-way bandwidth boost in supported modes

    USB4 Version 2.0:
        up to 80 Gbps operation
        optional asymmetric mode up to 120 Gbps one way and 40 Gbps the other

These numbers do not mean RAMMY gets perfect RAM behavior.

They mean that consumer external links are moving into a range where serious
local fabrics are no longer absurd.

For perspective:

    80 Gbps  = 10 GB/s theoretical raw bandwidth
    120 Gbps = 15 GB/s theoretical raw bandwidth

Real application bandwidth will be lower after overhead.

But even imperfect bandwidth at this scale can matter when the alternative is:

    - not running the workload at all
    - paging to slow storage
    - renting cloud compute
    - sending private data away

The first RAMMY lesson:

    External memory is not local RAM.

The second RAMMY lesson:

    External memory can still be useful if the workload is designed around it.


================================================================================
4. DIRECT PCIe AND FUTURE CONNECTORS
================================================================================

USB4 and Thunderbolt-class RAMMY should be treated as early docked-fabric work.

The more serious long-term path is direct module attachment.

A future ZIGN01D phone or module could expose itself through:

    - PCIe endpoint mode
    - M.2-style carrier boards
    - PCIe switch/backplanes
    - dedicated docking boards
    - future CXL-like memory fabrics
    - custom coherent or semi-coherent interconnects

PCIe is already extremely fast at the high end.

Approximate theoretical x16 bidirectional figures by generation:

    PCIe 5.0:
        about 128 GB/s bidirectional aggregate

    PCIe 6.0:
        about 256 GB/s bidirectional aggregate

    PCIe 7.0:
        target class around 512 GB/s bidirectional aggregate

Those are not phone-dock guarantees.

They are direction-of-travel signals.

The important point is not that a first ZIGN01D dock reaches datacenter-class
bandwidth.

The important point is that high-speed local interconnects continue improving,
and a personal compute fabric should be designed before the hardware becomes
obvious.

A realistic future assumption:

    Today's top external connectors can already deliver bandwidth that would
    have looked extreme in older personal computers.

    Future dock and module connectors may become fast enough that several owned
    devices can rival the memory and I/O capability of a strong single machine
    from an earlier generation.

That is enough to justify research.


================================================================================
5. DESIGN PRINCIPLE: DO NOT FAKE LOCALITY
================================================================================

RAMMY must not pretend all memory is equal.

A good RAMMY system should expose memory classes:

    local_hot
        Fastest memory.
        Used for active compute and critical state.

    local_cold
        Local memory used for less active regions.

    docked_fast
        Attached through high-speed local connector.

    mesh_remote
        Available across local fabric, but slower and less predictable.

    replicated
        Copied across nodes for resilience or speed.

    evictable
        Can be dropped and rebuilt.

    secret_never_remote
        Must not leave the device.

A weak design hides locality.

A strong design makes locality visible and schedulable.

Bad design:

    Program touches memory.
    Kernel faults random pages over the fabric.
    Latency explodes.
    Nobody knows why it is slow.

Good design:

    Workload declares memory needs.
    RAMMY places hot data near compute.
    Cold data is sharded deliberately.
    Transfers are batched.
    Prefetch is planned.
    Logs show stalls.
    Failures are visible.

The core law:

    RAMMY must move compute to memory whenever possible,
    not blindly move memory to compute.


================================================================================
6. THE AI WORKLOAD
================================================================================

Large language models are a useful benchmark because they punish dishonest
architecture.

They need:

    - memory capacity
    - sustained bandwidth
    - predictable scheduling
    - cache discipline
    - fast enough compute
    - good logging
    - graceful failure behavior

RAMMY should not begin with a claim that it beats high-end GPUs.

That is the wrong comparison.

The correct early comparison is:

    Can a local fabric run a model that no single node can comfortably hold?

If yes, RAMMY has done something meaningful.

Target ladder:

    7B Q4:
        early test class
        should become routine

    13B Q4:
        fast local assistant class
        target: 30+ tokens/sec sustained

    22B Q4:
        strong local assistant class
        target: 20+ tokens/sec sustained

    70B Q4:
        flagship mesh class
        proof target: 2 tokens/sec sustained
        public V1 target: 5 tokens/sec sustained
        serious long-term target: 20 tokens/sec sustained

A fast 13B or 22B model may be more useful day-to-day than a slow 70B model.

The 70B case is the architectural proof.

It demonstrates that the fabric can make a workload possible beyond the limits
of one node.


================================================================================
7. THE HOME RESEARCHER SCENARIO
================================================================================

A realistic RAMMY scene is not science fiction.

Imagine a researcher at home.

On the desk:

    - one desktop
    - one laptop
    - two ZIGN01D phones
    - one high-speed dock or switch
    - one private dataset
    - one local model
    - one problem worth staying up for

The desktop has the best cooling and storage.

The laptop contributes memory and a secondary worker.

The two ZIGN01D phones are not treated as dead slabs.

They are nodes.

    zign01d-phone-0:
        model shard
        identity service
        secure cache
        small compute queue

    zign01d-phone-1:
        model shard
        encrypted storage region
        recovery node
        small compute queue

    desktop:
        scheduler
        primary compute
        main logs
        storage

    laptop:
        secondary compute
        overflow memory
        display and interaction

The workload may be:

    - local document search
    - codebase analysis
    - private medical note analysis
    - local speech transcription
    - image archive indexing
    - mathematical exploration
    - small scientific simulation
    - local LLM inference
    - overnight research over private data

The breakthrough does not require the mesh to defeat a datacenter.

The breakthrough requires the mesh to provide enough local compute for the
researcher to run the experiment without surrendering the data or renting the
machine.

That is realistic.

Many discoveries happen because someone had just enough compute, just enough
time, and just enough control to keep iterating.


================================================================================
8. WHAT RAMMY COULD OPEN
================================================================================

RAMMY Mesh could open several practical research and product directions.

1. Personal compute fabrics

    The user's machine becomes a trusted arrangement of devices, not a single
    sealed object.

2. Local AI without cloud dependence

    Assistants, search, summarization, coding tools, translation, and archive
    analysis can run locally.

3. Old-device reuse

    Older phones and tablets become memory nodes, cache nodes, storage nodes,
    or small compute workers.

4. Trust-aware resource sharing

    Devices expose only the capabilities the user permits.

5. Phone-as-module hardware

    A phone becomes a dockable compute, storage, memory, and identity module.

6. Workload-aware operating systems

    The OS understands local, docked, and remote memory as different classes.

7. Measured local inference

    Logs expose token timing, bandwidth, latency, cache misses, stalls, and node
    failures.

8. Offline research machines

    Field researchers, students, independent builders, ships, rural labs, and
    disaster zones can run stronger local systems without assuming cloud access.

9. Modular personal hardware

    The personal computer becomes expandable again.

10. A new developer target

    Applications can be written for a personal fabric:
        native code for system work
        WebAssembly for portable apps
        RAMMY services for distributed local workloads


================================================================================
9. REALISTIC PERFORMANCE CLASSES
================================================================================

RAMMY should define performance classes honestly.

Class 0: Simulation

    Transport:
        QEMU, sockets, virtio

    Purpose:
        protocol design, logging, scheduling, failure behavior

    Expected result:
        not performance-relevant

Class 1: Ethernet / basic local network

    Purpose:
        early real multi-node development

    Strength:
        easy to test

    Weakness:
        latency and bandwidth limits

Class 2: USB4 / Thunderbolt-class docked fabric

    Purpose:
        serious early docked RAMMY

    Strength:
        high consumer external bandwidth

    Weakness:
        not local RAM, switching and protocol overhead matter

    70B Q4 expectation:
        proof: 1-2 tokens/sec
        good: 3-5 tokens/sec
        excellent: 8-10 tokens/sec

Class 3: Direct PCIe modules

    Purpose:
        real phone-as-module architecture

    Strength:
        much better fit for queues, DMA, memory windows, and accelerators

    70B Q4 expectation:
        proof: 5 tokens/sec
        good: 10-20 tokens/sec
        excellent: 20-30 tokens/sec

Class 4: PCIe backplane plus per-module accelerators

    Purpose:
        distributed inference hardware

    Strength:
        compute lives near memory

    70B Q4 expectation:
        good: 20-40 tokens/sec
        excellent: 40+ tokens/sec

Class 5: Future CXL-like or custom coherent fabric

    Purpose:
        serious memory-fabric architecture

    Strength:
        closer to memory expansion semantics

    Expectation:
        highly hardware-dependent
        potentially transformative
        not a V1 assumption


================================================================================
10. WHAT MUST BE MEASURED
================================================================================

RAMMY should be built around logs from the beginning.

Every serious run should record:

    - git commit
    - build timestamp
    - node count
    - node identity
    - node role
    - transport type
    - negotiated link speed
    - measured bandwidth
    - measured latency
    - transfer sizes
    - queue depth
    - local memory used
    - remote memory used
    - replicated memory used
    - storage fallback used: yes/no
    - cache hits
    - cache misses
    - stall time
    - retry count
    - thermal throttling
    - node dropout events
    - workload name
    - model name, if applicable
    - quantization, if applicable
    - context size, if applicable
    - tokens/sec, if applicable
    - median speed across runs
    - worst run
    - best run

RAMMY must be able to explain its own performance.

If a token was slow, the system should be able to say why.

If a node failed, the system should say what was lost.

If the fabric stalled, the logs should show where.


================================================================================
11. ENGINEERING ROADMAP
================================================================================

V0:
    ZIGN01D boots on RISC-V in QEMU.

V1:
    Logs, shell, memory map, storage basics, network basics.

V2:
    RAMMY simulator over local processes.

V3:
    RAMMY protocol over sockets or virtio.

V4:
    Multi-node local test with full logging.

V5:
    Memory class API:
        local_hot
        local_cold
        docked_fast
        mesh_remote
        replicated
        evictable
        secret_never_remote

V6:
    Small synthetic workload sharding.

V7:
    7B Q4 model across nodes.

V8:
    13B Q4 target:
        30+ tokens/sec sustained

V9:
    22B Q4 target:
        20+ tokens/sec sustained

V10:
    70B Q4 proof:
        2 tokens/sec sustained

V11:
    70B Q4 public target:
        5 tokens/sec sustained

VX:
    Direct PCIe ZIGN01D module prototype.

VX+:
    70B Q4 over direct module fabric:
        20 tokens/sec sustained


================================================================================
12. FINAL POSITION
================================================================================

RAMMY Mesh is not a promise that cables solve computing.

It is a bet that personal machines should be designed for a future where local
interconnects are fast enough, common enough, and flexible enough to make owned
device fabrics practical.

The idea is simple:

    A phone should stand alone.

    A phone should dock into a larger body.

    A phone should join other trusted machines when the user needs more than one
    device can provide.

The measure of success is not fantasy speed.

The measure of success is capability:

    Can the user's owned machines do useful work together?

    Can they run workloads no single node could hold?

    Can they keep private data local?

    Can they expose the truth through logs?

    Can old devices remain useful?

    Can a researcher at home, with two computers and two ZIGN01D phones, run an
    experiment that would otherwise have been out of reach?

If yes, RAMMY is not a gimmick.

It is a path toward the personal computer becoming personal again.

A machine made of machines.

A mega mind made out of smaller owned parts.
================================================================================
