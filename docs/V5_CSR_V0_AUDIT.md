# ZIGN01D V5 CSR V0 Audit

## Result

V5 CSR V0 adds a real supervisor-mode CSR introspection layer and a `csr` shell
command. The values are read from the running QEMU CPU when the command executes;
they are not canned constants or inferred metrics.

## Implementation evidence

- `kernel/arch/riscv64/csr.zig::hartId` returns the firmware-provided hart ID
  saved from boot register `a0` by `boot/entry.S`.
- `kernel/arch/riscv64/csr.zig::readSstatus` reads `sstatus`.
- `kernel/arch/riscv64/csr.zig::readSie` reads `sie`.
- `kernel/arch/riscv64/csr.zig::readSip` reads `sip`.
- `kernel/arch/riscv64/csr.zig::readStvec` reads `stvec`.
- `kernel/arch/riscv64/csr.zig::readSepc` reads `sepc`.
- `kernel/arch/riscv64/csr.zig::readScause` reads `scause`.
- `kernel/arch/riscv64/csr.zig::readStval` reads `stval`.
- `kernel/arch/riscv64/csr.zig::readSatp` reads `satp`.
- `kernel/arch/riscv64/csr.zig::printStatus` prints stable readable names and
  hexadecimal values.
- `kernel/console/shell.zig::handle` routes the `csr` command.
- `smoke/smoke-csr-v0.sh` boots QEMU, runs `csr`, checks each required value,
  rejects panic output, and shuts the machine down.

## Privilege safety policy

ZIGN01D currently enters supervisor mode through OpenSBI or compatible firmware.
The M1 code therefore reads only supervisor CSRs that are available to the
current kernel execution mode: `sstatus`, `sie`, `sip`, `stvec`, `sepc`,
`scause`, `stval`, and `satp`.

The command does not read `mhartid`. `mhartid` is a machine-mode CSR, so the hart
ID comes from the architectural firmware handoff value in `a0`, which
`boot/entry.S` saves before calling `kmain`.

The command also avoids `mstatus`, `mie`, `mip`, `mtvec`, `mepc`, `mcause`,
`mtval`, and all hypervisor CSRs. Reading those from the current privilege mode
could raise an illegal-instruction exception. ZIGN01D's current live trap policy
is noreturn and cannot safely skip a faulting CSR instruction, so probing an
unavailable CSR would crash rather than discover capability.

`satp` is an S-mode CSR and is readable under the current QEMU/OpenSBI execution
contract. A machine-mode monitor can make supervisor `satp` access trap by
setting `mstatus.TVM`; ZIGN01D cannot inspect that M-mode control bit safely.
Ports that impose TVM must disable the `satp` read at platform configuration time
until M2 provides recoverable trap handling. M1 does not attempt a faulting probe.

## What this milestone proves

- The shell reads live supervisor CSR state.
- The installed trap vector is observable through `stvec`.
- Current trap cause/value/program-counter state is observable.
- Interrupt enable and pending state are observable without claiming interrupts
  are operational.
- Paging state is observable through `satp` without claiming ZIGN01D owns page
  tables.
- Machine-mode-only CSRs are deliberately excluded.

## What remains missing

- A complete saved trap frame.
- Recoverable illegal-instruction handling.
- CSR bitfield decoding.
- Timer interrupt enablement.
- Page-table ownership.
- Hypervisor CSR access.

The next action is M2: implement a complete trap frame and safe return path.
