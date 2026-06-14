const uart=@import("../console/uart.zig"); const gef=@import("guest_entry_frame.zig"); const trf=@import("trap_return_frame.zig"); const fip=@import("first_instruction_plan.zig"); const hgatp=@import("hgatp_candidate.zig"); const sp=@import("stage2_activation_plan.zig");
fn ok(label:[]const u8, pass:bool)bool{uart.write("hv: hv26.");uart.write(label);uart.write("=");uart.write(if(pass)"ok" else "rejected");uart.write("\r\n");return pass;} fn all(a:bool,b:bool)bool{return a and b;}
pub fn guestEntryLifecycle()bool{gef.reset(); var p=true; p=all(p,gef.validate()==.rejected); const before=gef.object().build_count; p=all(p,gef.build()==.ok); p=all(p,gef.object().build_count>before); p=all(p,gef.object().checksum!=0); p=all(p,gef.object().sources.activation_plan_checksum==sp.object().checksum); p=all(p,gef.object().sources.hgatp_checksum==hgatp.object().checksum); p=all(p,gef.validate()==.ok); gef.reset(); p=all(p,gef.object().checksum==0 and gef.object().reset_count>0); return ok("guest_entry.lifecycle_invariant",p);} 
pub fn guestEntryMutation()bool{_=gef.build(); const a=gef.object().checksum; const pc=gef.mutatePc(); _=gef.build(); const spc=gef.mutateSp(); _=gef.build(); const args=gef.mutateArgs(); const r=gef.corruptRegister(); const p=(a!=0 and pc!=a and spc!=a and args!=a and r==.rejected); return ok("guest_entry.mutation_invariant",p);} 
pub fn trapLifecycle()bool{trf.reset(); var p=true; p=all(p,trf.validate()==.rejected); const b=trf.object().build_count; p=all(p,trf.build()==.ok); p=all(p,trf.object().build_count>b and trf.object().checksum!=0 and trf.object().entry_frame_checksum==gef.object().checksum and trf.object().activation_plan_checksum==sp.object().checksum); p=all(p,trf.validate()==.ok); trf.reset(); p=all(p,trf.object().checksum==0); return ok("trap_return.lifecycle_invariant",p);} 
pub fn trapMutation()bool{_=trf.build(); const a=trf.object().checksum; _=gef.mutatePc(); _=trf.build(); const b=trf.object().checksum; const se=trf.corruptSepc(); const st=trf.corruptStatus(); return ok("trap_return.mutation_invariant",a!=0 and b!=a and se==.rejected and st==.rejected);} 
pub fn firstConsumption()bool{_=fip.build(); const a=fip.object().execution_chain_checksum; _=hgatp.mutateRootPpn(1); _=fip.build(); const b=fip.object().execution_chain_checksum; _=sp.build(); _=fip.build(); const c=fip.object().execution_chain_checksum; _=gef.mutatePc(); _=fip.build(); const d=fip.object().execution_chain_checksum; _=trf.build(); _=fip.build(); const e=fip.object().execution_chain_checksum; return ok("first_instruction.consumption_invariant",a!=0 and b!=a and c!=0 and d!=0 and e!=0);} 
pub fn firstCorruption()bool{var p=true; p=all(p,fip.missingHgatp()==.rejected); p=all(p,fip.missingActivation()==.rejected); p=all(p,fip.missingEntry()==.rejected); p=all(p,fip.missingTrap()==.rejected); p=all(p,fip.markGuest()==.rejected); p=all(p,fip.markInstruction()==.rejected); p=all(p,fip.markTrap()==.rejected); p=all(p,fip.markHgatpWritten()==.rejected); p=all(p,fip.markStage2()==.rejected); return ok("first_instruction.corruption_invariant",p);} 
pub fn hv25Consumption()bool{_=gef.build(); const g0=gef.object().checksum; _=fip.build(); const f0=fip.object().execution_chain_checksum; _=sp.removeTable(); _=gef.build(); const g1=gef.object().checksum; _=sp.build(); _=hgatp.mutateRootPpn(2); _=fip.build(); const f1=fip.object().execution_chain_checksum; return ok("hv25.consumption_invariant",g0!=0 and f0!=0 and (g1!=g0 or f1!=f0));}
pub fn allInvariants()void{var p=true; p=all(p,guestEntryLifecycle());p=all(p,guestEntryMutation());p=all(p,trapLifecycle());p=all(p,trapMutation());p=all(p,firstConsumption());p=all(p,firstCorruption());p=all(p,hv25Consumption());p=all(p,detailedConsumptionProof());p=all(p,detailedRejectionProof());p=all(p,detailedNonExecutionProof());p=all(p,detailedCounterProof());p=all(p,detailedDependencyGraphProof());p=all(p,detailedFrameChainProof()); _=ok("all_invariants",p);} 

fn nonzero(value: usize) bool {
    return value != 0;
}

fn changed(before: usize, after: usize) bool {
    return before != 0 and after != 0 and before != after;
}

pub fn detailedConsumptionProof() bool {
    var pass = true;
    _ = gef.build();
    const entry_before = gef.object().checksum;
    const entry_plan_before = gef.object().sources.activation_plan_checksum;
    _ = fip.build();
    const first_before = fip.object().execution_chain_checksum;
    const hgatp_before = fip.object().consumed_hgatp_checksum;
    const activation_before = fip.object().consumed_activation_plan_checksum;
    const trap_before = fip.object().consumed_trap_return_frame_checksum;
    pass = all(pass, nonzero(entry_before));
    pass = all(pass, nonzero(entry_plan_before));
    pass = all(pass, nonzero(first_before));
    pass = all(pass, nonzero(hgatp_before));
    pass = all(pass, nonzero(activation_before));
    pass = all(pass, nonzero(trap_before));
    _ = sp.removeTable();
    _ = gef.build();
    const entry_after_plan_mutation = gef.object().checksum;
    _ = sp.build();
    _ = hgatp.mutateRootPpn(3);
    _ = fip.build();
    const first_after_hgatp_mutation = fip.object().execution_chain_checksum;
    pass = all(pass, changed(entry_before, entry_after_plan_mutation) or changed(first_before, first_after_hgatp_mutation));
    return ok("detailed_consumption_proof", pass);
}

pub fn detailedRejectionProof() bool {
    var pass = true;
    pass = all(pass, gef.missingActivationPlan() == .rejected);
    pass = all(pass, gef.object().first_blocker == .activation_plan_missing);
    pass = all(pass, gef.missingContext() == .rejected);
    pass = all(pass, gef.object().first_blocker == .guest_context_missing);
    pass = all(pass, gef.corruptRegister() == .rejected);
    pass = all(pass, gef.object().first_blocker == .register_corrupt);
    pass = all(pass, trf.missingEntry() == .rejected);
    pass = all(pass, trf.object().first_blocker == .entry_frame_missing);
    pass = all(pass, trf.missingCsr() == .rejected);
    pass = all(pass, trf.object().first_blocker == .csr_safety_missing);
    pass = all(pass, trf.missingHext() == .rejected);
    pass = all(pass, trf.object().first_blocker == .h_extension_missing);
    pass = all(pass, trf.corruptSepc() == .rejected);
    pass = all(pass, trf.object().first_blocker == .sepc_corrupt);
    pass = all(pass, trf.corruptStatus() == .rejected);
    pass = all(pass, trf.object().first_blocker == .status_corrupt);
    pass = all(pass, fip.missingHgatp() == .rejected);
    pass = all(pass, fip.object().first_blocker == .hgatp_missing);
    pass = all(pass, fip.missingActivation() == .rejected);
    pass = all(pass, fip.object().first_blocker == .activation_plan_missing);
    pass = all(pass, fip.missingEntry() == .rejected);
    pass = all(pass, fip.object().first_blocker == .entry_frame_missing);
    pass = all(pass, fip.missingTrap() == .rejected);
    pass = all(pass, fip.object().first_blocker == .trap_return_frame_missing);
    return ok("detailed_rejection_proof", pass);
}

pub fn detailedNonExecutionProof() bool {
    var pass = true;
    _ = gef.build();
    _ = trf.build();
    _ = fip.build();
    pass = all(pass, !gef.object().guest_entered);
    pass = all(pass, !gef.object().guest_instruction_executed);
    pass = all(pass, !gef.object().trap_return_executed);
    pass = all(pass, !gef.object().hgatp_written);
    pass = all(pass, !gef.object().active_stage2);
    pass = all(pass, !trf.object().guest_entered);
    pass = all(pass, !trf.object().guest_instruction_executed);
    pass = all(pass, !trf.object().trap_return_executed);
    pass = all(pass, !trf.object().hgatp_written);
    pass = all(pass, !trf.object().active_stage2);
    pass = all(pass, !fip.object().guest_entered);
    pass = all(pass, !fip.object().guest_instruction_executed);
    pass = all(pass, !fip.object().trap_return_executed);
    pass = all(pass, !fip.object().hgatp_written);
    pass = all(pass, !fip.object().active_stage2);
    return ok("detailed_non_execution_proof", pass);
}

pub fn detailedCounterProof() bool {
    var pass = true;
    gef.reset();
    const gef_reset = gef.object().reset_count;
    const gef_build_before = gef.object().build_count;
    _ = gef.build();
    const gef_build_after = gef.object().build_count;
    const gef_validate_before = gef.object().validate_count;
    _ = gef.validate();
    const gef_validate_after = gef.object().validate_count;
    _ = gef.corruptRegister();
    const gef_reject_after = gef.object().reject_count;
    pass = all(pass, gef_reset > 0);
    pass = all(pass, gef_build_after > gef_build_before);
    pass = all(pass, gef_validate_after > gef_validate_before);
    pass = all(pass, gef_reject_after > 0);
    trf.reset();
    const trf_reset = trf.object().reset_count;
    const trf_build_before = trf.object().build_count;
    _ = trf.build();
    const trf_build_after = trf.object().build_count;
    const trf_validate_before = trf.object().validate_count;
    _ = trf.validate();
    const trf_validate_after = trf.object().validate_count;
    _ = trf.corruptSepc();
    const trf_reject_after = trf.object().reject_count;
    pass = all(pass, trf_reset > 0);
    pass = all(pass, trf_build_after > trf_build_before);
    pass = all(pass, trf_validate_after > trf_validate_before);
    pass = all(pass, trf_reject_after > 0);
    fip.reset();
    const fip_reset = fip.object().reset_count;
    const fip_build_before = fip.object().build_count;
    _ = fip.build();
    const fip_build_after = fip.object().build_count;
    const fip_validate_before = fip.object().validate_count;
    _ = fip.validate();
    const fip_validate_after = fip.object().validate_count;
    _ = fip.missingTrap();
    const fip_reject_after = fip.object().reject_count;
    pass = all(pass, fip_reset > 0);
    pass = all(pass, fip_build_after > fip_build_before);
    pass = all(pass, fip_validate_after > fip_validate_before);
    pass = all(pass, fip_reject_after > 0);
    return ok("detailed_counter_proof", pass);
}

pub fn detailedDependencyGraphProof() bool {
    var pass = true;
    _ = fip.build();
    const d0 = fip.object().deps[0];
    const d1 = fip.object().deps[1];
    const d2 = fip.object().deps[2];
    const d3 = fip.object().deps[3];
    pass = all(pass, d0.present);
    pass = all(pass, d0.valid);
    pass = all(pass, nonzero(d0.checksum));
    pass = all(pass, d0.blocker == .hgatp_missing);
    pass = all(pass, d1.present);
    pass = all(pass, d1.valid);
    pass = all(pass, nonzero(d1.checksum));
    pass = all(pass, d1.blocker == .activation_plan_missing);
    pass = all(pass, d2.present);
    pass = all(pass, d2.valid);
    pass = all(pass, nonzero(d2.checksum));
    pass = all(pass, d2.blocker == .entry_frame_missing);
    pass = all(pass, d3.present);
    pass = all(pass, d3.valid);
    pass = all(pass, nonzero(d3.checksum));
    pass = all(pass, d3.blocker == .trap_return_frame_missing);
    pass = all(pass, fip.object().next_required_action == .guarded_trap_return_assembly_preparation);
    return ok("detailed_dependency_graph_proof", pass);
}

pub fn detailedFrameChainProof() bool {
    var pass = true;
    _ = gef.build();
    const entry_checksum = gef.object().checksum;
    const entry_register_checksum = gef.object().register_image.checksum;
    const entry_activation_checksum = gef.object().sources.activation_plan_checksum;
    const entry_hgatp_checksum = gef.object().sources.hgatp_checksum;
    _ = trf.build();
    const trap_checksum = trf.object().checksum;
    const trap_entry_checksum = trf.object().entry_frame_checksum;
    const trap_activation_checksum = trf.object().activation_plan_checksum;
    _ = fip.build();
    const chain_checksum = fip.object().execution_chain_checksum;
    pass = all(pass, nonzero(entry_checksum));
    pass = all(pass, nonzero(entry_register_checksum));
    pass = all(pass, nonzero(entry_activation_checksum));
    pass = all(pass, nonzero(entry_hgatp_checksum));
    pass = all(pass, nonzero(trap_checksum));
    pass = all(pass, trap_entry_checksum == entry_checksum);
    pass = all(pass, trap_activation_checksum == entry_activation_checksum);
    pass = all(pass, nonzero(chain_checksum));
    pass = all(pass, fip.object().consumed_guest_entry_frame_checksum == entry_checksum);
    pass = all(pass, fip.object().consumed_trap_return_frame_checksum == trap_checksum);
    return ok("detailed_frame_chain_proof", pass);
}
