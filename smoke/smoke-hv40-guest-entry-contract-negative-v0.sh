#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TRANSCRIPT="$ROOT/smoke/transcripts/latest-hv40-guest-entry-contract-negative-v0.txt"; ELF="$ROOT/zig-out/bin/zign01d-v0"
mkdir -p "$ROOT/smoke/transcripts"; : > "$TRANSCRIPT"
"$ROOT/scripts/check-zig-version.sh" >/dev/null
"$ROOT/scripts/build.sh" >/dev/null
command -v qemu-system-riscv64 >/dev/null
QEMU=(qemu-system-riscv64 -machine virt -cpu rv64 -smp 1 -m 128M -nographic -monitor none -serial stdio -kernel "$ELF")
python3 - "$TRANSCRIPT" "${QEMU[@]}" <<'PYQ'
import os,selectors,subprocess,sys,time
cmds=['hv guest-entry-contract require-hv39-test','hv guest-entry-contract invalid-hv39-test','hv guest-entry-contract source-integrity-test','hv guest-entry-contract invalid-guest-pc-test','hv guest-entry-contract invalid-guest-sp-test','hv guest-entry-contract invalid-register-frame-test','hv guest-entry-contract invalid-execution-frame-test','hv guest-entry-contract invalid-trap-return-target-test','hv guest-entry-contract guest-ready-test','hv guest-entry-contract trap-return-ready-test','hv guest-entry-contract guest-entered-test','hv guest-entry-contract first-instruction-test','hv guest-entry-contract trap-return-executed-test','hv guest-entry-contract active-stage2-test','hv guest-entry-contract hgatp-written-test','hv guest-entry-contract invariant-consumption-test','hv guest-entry-contract invariant-corruption-test','shutdown']
tr=sys.argv[1]; p=subprocess.Popen(sys.argv[2:],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.STDOUT); os.set_blocking(p.stdout.fileno(),False); sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); seen=bytearray(); ready=False; deadline=time.monotonic()+180
with open(tr,'wb') as out:
 while time.monotonic()<deadline and p.poll() is None:
  for k,_ in sel.select(.05):
   d=k.fileobj.read()
   if d: out.write(d); out.flush(); seen.extend(d)
  if not ready and b'zign01d> ' in seen:
   ready=True
   for c in cmds: p.stdin.write((c+'\n').encode()); p.stdin.flush(); time.sleep(.05)
 if p.poll() is None: p.terminate(); time.sleep(.2)
 while True:
  d=p.stdout.read()
  if not d: break
  out.write(d)
sys.exit(0 if ready else 125)
PYQ
python3 - "$TRANSCRIPT" <<'PYC'
import re,sys
text=open(sys.argv[1],errors='replace').read()
def block(cmd):
 m=re.search(re.escape('zign01d> '+cmd)+r'\r?\n',text); assert m,'missing '+cmd
 s=m.end(); e=text.find('zign01d> ',s); return text[s: len(text) if e<0 else e]
expect={'require-hv39-test':'missing-hv39-source','invalid-hv39-test':'invalid-hv39-source','source-integrity-test':'source-mutated','invalid-guest-pc-test':'invalid-guest-pc','invalid-guest-sp-test':'invalid-guest-sp','invalid-register-frame-test':'invalid-register-frame','invalid-execution-frame-test':'invalid-execution-frame','invalid-trap-return-target-test':'invalid-trap-return-target','guest-ready-test':'guest-ready-corruption','trap-return-ready-test':'trap-return-ready-corruption','guest-entered-test':'guest-entered-corruption','first-instruction-test':'first-instruction-corruption','trap-return-executed-test':'trap-return-executed-corruption','active-stage2-test':'active-stage2-corruption','hgatp-written-test':'hgatp-written-corruption','invariant-corruption-test':'guest-entered-corruption'}
for cmd,blk in expect.items():
 b=block('hv guest-entry-contract '+cmd); assert '=rejected' in b and 'blocker='+blk in b,(cmd,blk,b)
b=block('hv guest-entry-contract invariant-consumption-test'); assert 'invariant_consumption_test=ok' in b and 'guest_entry_blocked=true' in b and 'trap_return_blocked=true' in b
for bad in ['linux_boot=ok','busybox_boot=ok','alpine_boot=ok','guest_entered=yes','guest_entered=true','first_guest_instruction=executed','first_guest_instruction_executed=true','trap_return=executed','trap_return_executed=true','hgatp=written','hgatp_write=ok','hgatp=active','second_stage_translation=ACTIVE','active_stage2=true','hgatp_write_performed=true']:
 assert bad not in text,bad
PYC
