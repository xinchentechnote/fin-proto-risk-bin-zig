//! 与引擎侧实现（omni-rt-risk/risk-binary）的互通测试：
//! tests/golden/*.bin 由引擎的 RbpFrame 编码生成（与 fin-proto-risk-bin-rs 的
//! golden_interop.rs 使用同一组帧）。此处用 fin-protoc 生成的 Zig 代码解码并
//! 逐字段断言，再重编码要求字节级一致。
//! 任何字段顺序/类型/定长/字节序漂移都会在这里暴露。

const std = @import("std");
const codec = @import("binary_codec");
const risk = @import("risk_binary");

const golden_new_order_req = @embedFile("golden/05_new_order_req.bin");
const golden_cancel_req = @embedFile("golden/06_cancel_req.bin");
const golden_order_confirm = @embedFile("golden/07_order_confirm.bin");
const golden_trade_report = @embedFile("golden/08_trade_report.bin");
const golden_cancel_reject = @embedFile("golden/09_cancel_reject.bin");
const golden_order_reject = @embedFile("golden/10_order_reject.bin");
const golden_risk_result = @embedFile("golden/11_risk_result.bin");
const golden_instruction = @embedFile("golden/12_instruction.bin");
const golden_instr_ack = @embedFile("golden/13_instr_ack.bin");

fn roundtrip(name: []const u8, raw: []const u8, allocator: std.mem.Allocator) !risk.RbpBinary {
    var reader = codec.Reader.init(raw, .big);
    const decoded = try risk.RbpBinary.decode(allocator, &reader);
    try std.testing.expectEqual(@as(usize, 0), reader.remaining());

    var buf = codec.Buffer.init(allocator, .big);
    defer buf.deinit();
    try decoded.encode(&buf);
    if (!std.mem.eql(u8, raw, buf.written())) {
        std.debug.print("{s}: re-encoded bytes differ\n", .{name});
        return error.ReencodeMismatch;
    }
    return decoded;
}

test "golden new_order_req" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("new_order_req", golden_new_order_req, arena.allocator());
    try std.testing.expectEqual(@as(u32, 16), m.msg_type);
    try std.testing.expectEqual(@as(u32, 123), m.body_len);
    const body = m.body.new_order_req;
    try std.testing.expectEqual(@as(u64, 1001), body.req_id);
    try std.testing.expectEqual(@as(u16, 1), body.channel_id);
    try std.testing.expectEqual(@as(u8, 1), body.adapter);
    try std.testing.expectEqualStrings("A123", body.account);
    try std.testing.expectEqualStrings("G1", body.account_group);
    try std.testing.expectEqualStrings("C0001", body.cl_ord_id);
    try std.testing.expectEqualStrings("600000", body.security_id);
    try std.testing.expectEqual(@as(u8, 1), body.market);
    try std.testing.expectEqual(@as(u8, 1), body.side);
    try std.testing.expectEqual(@as(i64, 1050), body.price);
    try std.testing.expectEqual(@as(i64, 100), body.order_qty);
    try std.testing.expectEqual(@as(u8, 1), body.ord_type);
    try std.testing.expectEqual(@as(u8, 0), body.time_in_force);
    try std.testing.expectEqualStrings("P0001", body.pbu);
    try std.testing.expectEqual(@as(u64, 1_700_000_000), body.transact_time);
    try std.testing.expectEqual(@as(u64, 123_456), body.ts_recv_ns);
    try std.testing.expectEqual(@as(u64, 7), body.raw_ref);
}

test "golden cancel_req" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("cancel_req", golden_cancel_req, arena.allocator());
    try std.testing.expectEqual(@as(u32, 17), m.msg_type);
    try std.testing.expectEqual(@as(u32, 88), m.body_len);
    const body = m.body.cancel_req;
    try std.testing.expectEqual(@as(u64, 1002), body.req_id);
    try std.testing.expectEqualStrings("C0002", body.cl_ord_id);
    try std.testing.expectEqualStrings("C0001", body.orig_cl_ord_id);
    try std.testing.expectEqualStrings("600000", body.security_id);
    try std.testing.expectEqual(@as(u8, 1), body.side);
    try std.testing.expectEqual(@as(u64, 8), body.raw_ref);
}

test "golden order_confirm" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("order_confirm", golden_order_confirm, arena.allocator());
    try std.testing.expectEqual(@as(u32, 18), m.msg_type);
    try std.testing.expectEqual(@as(u32, 76), m.body_len);
    const body = m.body.order_confirm;
    try std.testing.expectEqual(@as(u64, 1001), body.req_id);
    try std.testing.expectEqualStrings("C0001", body.cl_ord_id);
    try std.testing.expectEqualStrings("O9", body.order_id);
    try std.testing.expectEqual(@as(u8, 1), body.ord_status);
}

test "golden trade_report" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("trade_report", golden_trade_report, arena.allocator());
    try std.testing.expectEqual(@as(u32, 19), m.msg_type);
    try std.testing.expectEqual(@as(u32, 138), m.body_len);
    const body = m.body.trade_report;
    try std.testing.expectEqualStrings("E1", body.exec_id);
    try std.testing.expectEqual(@as(u8, 0), body.exec_type);
    try std.testing.expectEqual(@as(u8, 3), body.ord_status);
    try std.testing.expectEqual(@as(i64, 1050), body.last_px);
    try std.testing.expectEqual(@as(i64, 40), body.last_qty);
    try std.testing.expectEqual(@as(i64, 40), body.cum_qty);
    try std.testing.expectEqual(@as(i64, 60), body.leaves_qty);
}

test "golden cancel_reject" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("cancel_reject", golden_cancel_reject, arena.allocator());
    try std.testing.expectEqual(@as(u32, 20), m.msg_type);
    try std.testing.expectEqual(@as(u32, 109), m.body_len);
    const body = m.body.cancel_reject;
    try std.testing.expectEqualStrings("C0002", body.cl_ord_id);
    try std.testing.expectEqualStrings("C0001", body.orig_cl_ord_id);
    try std.testing.expectEqual(@as(u16, 0), body.reason_code);
    try std.testing.expectEqualStrings("filled", body.text);
}

test "golden order_reject" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("order_reject", golden_order_reject, arena.allocator());
    try std.testing.expectEqual(@as(u32, 21), m.msg_type);
    const body = m.body.order_reject;
    try std.testing.expectEqual(@as(u16, 2), body.channel_id);
    try std.testing.expectEqual(@as(u8, 2), body.adapter);
    try std.testing.expectEqualStrings("C0003", body.cl_ord_id);
    try std.testing.expectEqual(@as(u16, 1), body.reason_code);
    try std.testing.expectEqualStrings("no cash", body.text);
}

test "golden risk_result" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("risk_result", golden_risk_result, arena.allocator());
    try std.testing.expectEqual(@as(u32, 32), m.msg_type);
    try std.testing.expectEqual(@as(u32, 77), m.body_len);
    const body = m.body.risk_result;
    try std.testing.expectEqual(@as(u64, 1001), body.req_id);
    try std.testing.expectEqual(@as(u8, 1), body.decision);
    try std.testing.expectEqual(@as(u16, 1002), body.code);
    try std.testing.expectEqual(@as(u16, 5), body.rule_id);
    try std.testing.expectEqual(@as(u64, 123_456), body.ts_recv_ns);
    try std.testing.expectEqual(@as(u64, 223_456), body.ts_engine_ns);
    try std.testing.expectEqualStrings("over limit", body.text);
}

test "golden instruction" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("instruction", golden_instruction, arena.allocator());
    try std.testing.expectEqual(@as(u32, 48), m.msg_type);
    try std.testing.expectEqual(@as(u32, 75), m.body_len);
    const body = m.body.instruction;
    try std.testing.expectEqual(@as(u64, 55), body.instr_id);
    try std.testing.expectEqual(@as(u16, 3), body.instr_type);
    try std.testing.expectEqual(@as(u8, 1), body.target_type);
    try std.testing.expectEqualStrings("A123", body.target);
    try std.testing.expectEqual(@as(u64, 0), body.expiry_ns);
    try std.testing.expectEqualStrings("risk-op", body.operator);
}

test "golden instr_ack" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const m = try roundtrip("instr_ack", golden_instr_ack, arena.allocator());
    try std.testing.expectEqual(@as(u32, 49), m.msg_type);
    try std.testing.expectEqual(@as(u32, 17), m.body_len);
    const body = m.body.instr_ack;
    try std.testing.expectEqual(@as(u64, 55), body.instr_id);
    try std.testing.expectEqual(@as(u8, 0), body.result);
}
