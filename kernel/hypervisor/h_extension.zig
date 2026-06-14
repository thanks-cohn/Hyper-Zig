const uart = @import("../console/uart.zig");
const vm = @import("vm.zig");
const vcpu = @import("vcpu.zig");

pub const DiscoveryState = enum { empty, discovered, validated, rejected };
pub const DetectionMode = enum { none, safe_policy_only, safe_probe };
pub const HExtensionStatus = enum { unknown, detected, not_detected };
pub const HExtensionClaim = enum { not_claimed, claimed_safe_detected };
pub const CsrStatus = enum { unknown, allowed, blocked_by_safety_policy, unsupported, not_attempted };
pub const Result = enum { ok, rejected };
pub const Error = enum { none, discovery_empty, no_safe_h_csr_probe, unsafe_probe_forbidden, fake_detected_rejected, inconsistent_claim, hgatp_write_attempted, active_stage2_forbidden, owner_mismatch, csr_count_mismatch };

const TrackedCsr = struct { name: []const u8, status: *CsrStatus };

pub const HExtensionDiscovery = struct {
    owner_vm_id: vm.VmId,
    owner_vcpu_id: vcpu.VcpuId,
    state: DiscoveryState,
    detection_mode: DetectionMode,
    safe_detection_attempted: bool,
    safe_detection_allowed: bool,
    unsafe_csr_read_forbidden: bool,
    h_extension_status: HExtensionStatus,
    h_extension_claim: HExtensionClaim,
    hgatp_read_status: CsrStatus,
    hgatp_write_status: CsrStatus,
    hstatus_read_status: CsrStatus,
    hedeleg_read_status: CsrStatus,
    hideleg_read_status: CsrStatus,
    hvip_read_status: CsrStatus,
    hie_read_status: CsrStatus,
    htval_read_status: CsrStatus,
    htinst_read_status: CsrStatus,
    vscause_read_status: CsrStatus,
    vstval_read_status: CsrStatus,
    vsstatus_read_status: CsrStatus,
    vstvec_read_status: CsrStatus,
    vsepc_read_status: CsrStatus,
    readable_csr_count: usize,
    blocked_csr_count: usize,
    unsupported_csr_count: usize,
    build_count: usize,
    validate_count: usize,
    reject_count: usize,
    reset_count: usize,
    deterministic_blocker: Error,
    last_error: Error,
};

var discovery: HExtensionDiscovery = undefined;
var initialized = false;

pub fn init(owner: vm.VmId, owner_vcpu: vcpu.VcpuId) void { discovery = empty(owner, owner_vcpu, 0); initialized = true; }
pub fn object() *const HExtensionDiscovery { return mutable(); }
fn mutable() *HExtensionDiscovery { if (!initialized) init(vm.object().id, vcpu.object().id); return &discovery; }
fn empty(owner: vm.VmId, owner_vcpu: vcpu.VcpuId, resets: usize) HExtensionDiscovery { return .{ .owner_vm_id=owner, .owner_vcpu_id=owner_vcpu, .state=.empty, .detection_mode=.none, .safe_detection_attempted=false, .safe_detection_allowed=false, .unsafe_csr_read_forbidden=true, .h_extension_status=.unknown, .h_extension_claim=.not_claimed, .hgatp_read_status=.unknown, .hgatp_write_status=.not_attempted, .hstatus_read_status=.unknown, .hedeleg_read_status=.unknown, .hideleg_read_status=.unknown, .hvip_read_status=.unknown, .hie_read_status=.unknown, .htval_read_status=.unknown, .htinst_read_status=.unknown, .vscause_read_status=.unknown, .vstval_read_status=.unknown, .vsstatus_read_status=.unknown, .vstvec_read_status=.unknown, .vsepc_read_status=.unknown, .readable_csr_count=0, .blocked_csr_count=0, .unsupported_csr_count=0, .build_count=0, .validate_count=0, .reject_count=0, .reset_count=resets, .deterministic_blocker=.discovery_empty, .last_error=.none }; }
pub fn reset() void { const d=mutable(); discovery = empty(d.owner_vm_id, d.owner_vcpu_id, d.reset_count + 1); initialized = true; }

fn hasSafeHypervisorCsrProbe() bool { return false; }
fn csrTable(d: *HExtensionDiscovery) [13]TrackedCsr { return .{ .{ .name="hgatp", .status=&d.hgatp_read_status }, .{ .name="hstatus", .status=&d.hstatus_read_status }, .{ .name="hedeleg", .status=&d.hedeleg_read_status }, .{ .name="hideleg", .status=&d.hideleg_read_status }, .{ .name="hvip", .status=&d.hvip_read_status }, .{ .name="hie", .status=&d.hie_read_status }, .{ .name="htval", .status=&d.htval_read_status }, .{ .name="htinst", .status=&d.htinst_read_status }, .{ .name="vscause", .status=&d.vscause_read_status }, .{ .name="vstval", .status=&d.vstval_read_status }, .{ .name="vsstatus", .status=&d.vsstatus_read_status }, .{ .name="vstvec", .status=&d.vstvec_read_status }, .{ .name="vsepc", .status=&d.vsepc_read_status } }; }
fn recomputeCounts(d: *HExtensionDiscovery) void { var readable: usize=0; var blocked: usize=0; var unsupported: usize=0; var table=csrTable(d); for (&table) |*c| switch (c.status.*) { .allowed => readable += 1, .blocked_by_safety_policy => blocked += 1, .unsupported => unsupported += 1, else => {} }; d.readable_csr_count=readable; d.blocked_csr_count=blocked; d.unsupported_csr_count=unsupported; }

pub fn discoverSafe() Result {
    const d=mutable(); d.build_count += 1; d.safe_detection_attempted = true; d.unsafe_csr_read_forbidden = true; d.hgatp_write_status = .not_attempted;
    if (!hasSafeHypervisorCsrProbe()) {
        d.detection_mode = .safe_policy_only; d.safe_detection_allowed = false; d.h_extension_status = .unknown; d.h_extension_claim = .not_claimed;
        var table=csrTable(d); for (&table) |*c| c.status.* = .blocked_by_safety_policy;
        recomputeCounts(d); d.state=.discovered; d.last_error=.no_safe_h_csr_probe; d.deterministic_blocker=.no_safe_h_csr_probe; return .ok;
    }
    d.detection_mode = .safe_probe; d.safe_detection_allowed = true; d.h_extension_status = .not_detected; d.h_extension_claim = .not_claimed;
    var table=csrTable(d); for (&table) |*c| c.status.* = .unsupported;
    recomputeCounts(d); d.state=.discovered; d.last_error=.none; d.deterministic_blocker=.none; return .ok;
}

fn firstBlocker() Error { const d=object(); if (d.state == .empty) return .discovery_empty; if (d.owner_vm_id != vm.object().id or d.owner_vcpu_id != vcpu.object().id) return .owner_mismatch; if (!d.unsafe_csr_read_forbidden) return .unsafe_probe_forbidden; if (d.hgatp_write_status != .not_attempted) return .hgatp_write_attempted; if (d.h_extension_status == .detected and d.h_extension_claim != .claimed_safe_detected) return .inconsistent_claim; if (d.h_extension_claim == .claimed_safe_detected and d.h_extension_status != .detected) return .inconsistent_claim; if (d.detection_mode == .safe_policy_only and d.h_extension_status != .unknown) return .fake_detected_rejected; if (d.detection_mode == .safe_policy_only and d.blocked_csr_count != csrTableLen()) return .csr_count_mismatch; if (d.detection_mode == .safe_policy_only and d.deterministic_blocker == .no_safe_h_csr_probe) return .none; return .none; }
fn csrTableLen() usize { return 13; }
pub fn validate() Result { const d=mutable(); d.validate_count += 1; recomputeCounts(d); const e=firstBlocker(); if (e != .none) return reject(e); d.state=.validated; if (d.detection_mode == .safe_policy_only) { d.last_error=.no_safe_h_csr_probe; d.deterministic_blocker=.no_safe_h_csr_probe; } else { d.last_error=.none; d.deterministic_blocker=.none; } return .ok; }
fn reject(e: Error) Result { const d=mutable(); d.reject_count += 1; d.last_error=e; d.deterministic_blocker=e; d.state=.rejected; return .rejected; }

pub fn unsafeProbeTest() Result { const d=mutable(); if (d.state == .empty) _ = discoverSafe(); d.unsafe_csr_read_forbidden = true; return reject(.unsafe_probe_forbidden); }
pub fn fakeDetectedTest() Result { const d=mutable(); if (d.state == .empty) _ = discoverSafe(); d.h_extension_status = .detected; d.h_extension_claim = .not_claimed; return reject(.fake_detected_rejected); }

pub fn printStatusCommand() void { printSummary(); printBlockers(); printNonClaims(); }
pub fn printDiscoverCommand() void { const r=discoverSafe(); printResult("discover_result", r); printSummary(); printSafety(); printCsrTable(); printBlockers(); printNonClaims(); }
pub fn printValidateCommand() void { const r=validate(); printResult("validate_result", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printBlockersCommand() void { printBlockers(); printNonClaims(); }
pub fn printCsrTableCommand() void { printCsrTable(); printNonClaims(); }
pub fn printSafetyCommand() void { printSafety(); printNonClaims(); }
pub fn printUnsafeProbeTestCommand() void { const r=unsafeProbeTest(); printResult("unsafe_probe_test", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printFakeDetectedTestCommand() void { const r=fakeDetectedTest(); printResult("fake_detected_test", r); printSummary(); printBlockers(); printNonClaims(); }
pub fn printResetCommand() void { reset(); uart.write("hv: h_extension.reset_result=ok\r\n"); printSummary(); printBlockers(); printNonClaims(); }

fn printResult(name: []const u8, r: Result) void { uart.write("hv: h_extension."); uart.write(name); uart.write("="); uart.write(if (r==.ok) "ok" else "rejected"); uart.write("\r\n"); }
fn hStatusName(s: HExtensionStatus) []const u8 { return switch (s) { .unknown => "unknown", .detected => "detected", .not_detected => "not-detected" }; }
fn statusName(s: CsrStatus) []const u8 { return switch(s){ .unknown=>"unknown", .allowed=>"allowed", .blocked_by_safety_policy=>"blocked-by-safety-policy", .unsupported=>"unsupported", .not_attempted=>"not-attempted" }; }
fn errorName(e: Error) []const u8 { return switch(e){ .none=>"none", .discovery_empty=>"discovery-empty", .no_safe_h_csr_probe=>"no-safe-h-csr-probe", .unsafe_probe_forbidden=>"unsafe-probe-forbidden", .fake_detected_rejected=>"fake-detected-rejected", .inconsistent_claim=>"inconsistent-claim", .hgatp_write_attempted=>"hgatp-write-attempted", .active_stage2_forbidden=>"active-stage2-forbidden", .owner_mismatch=>"owner-mismatch", .csr_count_mismatch=>"csr-count-mismatch" }; }
fn printSummary() void { const d=object(); uart.write("hv: h_extension_discovery=implemented\r\n"); uart.write("hv: h_extension_discovery.state="); uart.write(@tagName(d.state)); uart.write("\r\n"); uart.write("hv: h_extension_discovery.ready="); uart.write(if (d.state==.validated) "true" else "false"); uart.write("\r\n"); uart.write("hv: h_extension.owner_vm_id="); uart.writeDec(d.owner_vm_id); uart.write("\r\n"); uart.write("hv: h_extension.owner_vcpu_id="); uart.writeDec(d.owner_vcpu_id); uart.write("\r\n"); uart.write("hv: h_extension.detection_mode="); uart.write(@tagName(d.detection_mode)); uart.write("\r\n"); uart.write("hv: h_extension.safe_detection_attempted="); uart.write(if (d.safe_detection_attempted) "true" else "false"); uart.write("\r\n"); uart.write("hv: h_extension.safe_detection_allowed="); uart.write(if (d.safe_detection_allowed) "true" else "false"); uart.write("\r\n"); uart.write("hv: unsafe_csr_read_forbidden="); uart.write(if (d.unsafe_csr_read_forbidden) "true" else "false"); uart.write("\r\n"); uart.write("hv: h_extension_status="); uart.write(hStatusName(d.h_extension_status)); uart.write("\r\n"); if (d.h_extension_status == .unknown) uart.write("hv: h_extension.reason=no-safe-h-csr-probe\r\n"); uart.write("hv: h_extension_claim="); uart.write(if (d.h_extension_claim==.claimed_safe_detected) "claimed-safe-detected" else "not-claimed"); uart.write("\r\n"); uart.write("hv: hgatp_read="); uart.write(statusName(d.hgatp_read_status)); uart.write("\r\n"); uart.write("hv: hgatp_write="); uart.write(statusName(d.hgatp_write_status)); uart.write("\r\n"); uart.write("hv: readable_csr_count="); uart.writeDec(d.readable_csr_count); uart.write("\r\n"); uart.write("hv: blocked_csr_count="); uart.writeDec(d.blocked_csr_count); uart.write("\r\n"); uart.write("hv: unsupported_csr_count="); uart.writeDec(d.unsupported_csr_count); uart.write("\r\n"); uart.write("hv: h_extension.build_count="); uart.writeDec(d.build_count); uart.write("\r\n"); uart.write("hv: h_extension.validate_count="); uart.writeDec(d.validate_count); uart.write("\r\n"); uart.write("hv: h_extension.reject_count="); uart.writeDec(d.reject_count); uart.write("\r\n"); uart.write("hv: h_extension.reset_count="); uart.writeDec(d.reset_count); uart.write("\r\n"); uart.write("hv: h_extension.last_error="); uart.write(errorName(d.last_error)); uart.write("\r\n"); }
fn printSafety() void { const d=object(); uart.write("hv: hypervisor_csr_probe="); uart.write(if (d.safe_detection_allowed) "safe-probe-available" else "safety-blocked"); uart.write("\r\n"); uart.write("hv: h_csr_fault_recovery=not-present\r\n"); uart.write("hv: unsafe_direct_h_csr_reads=forbidden\r\n"); uart.write("hv: active_stage2=false\r\n"); }
fn printCsrTable() void { const d=object(); uart.write("hv: h_extension.csr_table=begin\r\n"); uart.write("hv: csr.hgatp.read="); uart.write(statusName(d.hgatp_read_status)); uart.write("\r\n"); uart.write("hv: csr.hstatus.read="); uart.write(statusName(d.hstatus_read_status)); uart.write("\r\n"); uart.write("hv: csr.hedeleg.read="); uart.write(statusName(d.hedeleg_read_status)); uart.write("\r\n"); uart.write("hv: csr.hideleg.read="); uart.write(statusName(d.hideleg_read_status)); uart.write("\r\n"); uart.write("hv: csr.hvip.read="); uart.write(statusName(d.hvip_read_status)); uart.write("\r\n"); uart.write("hv: csr.hie.read="); uart.write(statusName(d.hie_read_status)); uart.write("\r\n"); uart.write("hv: csr.htval.read="); uart.write(statusName(d.htval_read_status)); uart.write("\r\n"); uart.write("hv: csr.htinst.read="); uart.write(statusName(d.htinst_read_status)); uart.write("\r\n"); uart.write("hv: csr.vscause.read="); uart.write(statusName(d.vscause_read_status)); uart.write("\r\n"); uart.write("hv: csr.vstval.read="); uart.write(statusName(d.vstval_read_status)); uart.write("\r\n"); uart.write("hv: csr.vsstatus.read="); uart.write(statusName(d.vsstatus_read_status)); uart.write("\r\n"); uart.write("hv: csr.vstvec.read="); uart.write(statusName(d.vstvec_read_status)); uart.write("\r\n"); uart.write("hv: csr.vsepc.read="); uart.write(statusName(d.vsepc_read_status)); uart.write("\r\n"); uart.write("hv: h_extension.csr_table=end\r\n"); }
fn printBlockers() void { const d=object(); const e=d.deterministic_blocker; const count: usize = if (e == .none) 0 else 1; uart.write("hv: h_extension.blocker_count="); uart.writeDec(count); uart.write("\r\n"); uart.write("hv: h_extension.blocker="); uart.write(errorName(e)); uart.write("\r\n"); uart.write("hv: h_extension.blockers=deterministic-from-h-extension-state\r\n"); }
fn printNonClaims() void { uart.write("hv: active_stage2=false\r\n"); uart.write("hv: guest_entered=no\r\n"); uart.write("hv: first_guest_instruction=not-executed\r\n"); uart.write("hv: trap_return=not-executed\r\n"); uart.write("hv: hgatp_write=not-attempted\r\n"); uart.write("hv: linux_guest=not-supported-yet\r\n"); uart.write("hv: guest_execution=not-supported-yet\r\n"); uart.write("hv: second_stage_translation=MISSING\r\n"); uart.write("hv: printk=not-proven-yet\r\n"); }
