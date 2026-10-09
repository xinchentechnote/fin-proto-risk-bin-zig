//! Encode/decode benchmarks for the risk (RBP) binary library, mirrored by
//! examples/bench.rs in fin-proto-risk-bin-rs: both sides use the same
//! methodology (10k warmup iterations, then 10 batches of 100k operations;
//! the fastest batch is reported), so the numbers are directly comparable.
//!
//! Output is one TSV line per case on stderr (std.debug.print):
//!   lib \t lang \t op \t ns_per_op \t frame_bytes
//!
//! Run with: zig build bench -Doptimize=ReleaseFast

const std = @import("std");
const codec = @import("binary_codec");
const risk = @import("risk_binary");

const LIB = "risk";
const LANG = "zig";
const ITERS: usize = 100_000;
const BATCHES: usize = 10;
const WARMUP: usize = 10_000;

const gettime = @extern(*const fn (c_int, *std.c.timespec) callconv(.c) c_int, .{ .name = "clock_gettime" });

fn nowNs() u64 {
    var ts: std.c.timespec = undefined;
    _ = gettime(@backingInt(std.c.CLOCK.MONOTONIC), &ts);
    return @as(u64, @intCast(ts.sec)) * std.time.ns_per_s + @as(u64, @intCast(ts.nsec));
}

fn report(op: []const u8, best_ns: u64, bytes: usize) void {
    const ns_per_op = @as(f64, @floatFromInt(best_ns)) / @as(f64, @floatFromInt(ITERS));
    std.debug.print("{s}\t{s}\t{s}\t{d:.1}\t{d}\n", .{ LIB, LANG, op, ns_per_op, bytes });
}

fn benchEncode(allocator: std.mem.Allocator, msg: *const risk.NewOrderReq) !usize {
    var buf = codec.Buffer.init(allocator, .big);
    defer buf.deinit();
    var sink: usize = 0;
    for (0..WARMUP) |_| {
        buf.reset();
        try msg.encode(&buf);
    }
    var best: u64 = std.math.maxInt(u64);
    for (0..BATCHES) |_| {
        const t0 = nowNs();
        for (0..ITERS) |_| {
            buf.reset();
            try msg.encode(&buf);
            sink += buf.len;
        }
        best = @min(best, nowNs() - t0);
    }
    std.mem.doNotOptimizeAway(sink);
    report("encode", best, buf.len);
    return buf.len;
}

fn benchDecode(allocator: std.mem.Allocator, raw: []const u8) !void {
    var sink: usize = 0;
    for (0..WARMUP) |_| {
        var r = codec.Reader.init(raw, .big);
        const m = try risk.NewOrderReq.decode(allocator, &r);
        sink += m.transact_time;
    }
    var best: u64 = std.math.maxInt(u64);
    for (0..BATCHES) |_| {
        const t0 = nowNs();
        for (0..ITERS) |_| {
            var r = codec.Reader.init(raw, .big);
            const m = try risk.NewOrderReq.decode(allocator, &r);
            sink += m.transact_time;
        }
        best = @min(best, nowNs() - t0);
    }
    std.mem.doNotOptimizeAway(sink);
    report("decode", best, raw.len);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();

    const msg = risk.NewOrderReq{
        .req_id = 1001,
        .channel_id = 1,
        .adapter = 1,
        .account = "A123",
        .account_group = "G1",
        .cl_ord_id = "C0001",
        .security_id = "600000",
        .market = 1,
        .side = 1,
        .price = 1050,
        .order_qty = 100,
        .ord_type = 1,
        .time_in_force = 0,
        .pbu = "P0001",
        .transact_time = 1_700_000_000,
        .ts_recv_ns = 123_456,
        .raw_ref = 7,
    };

    const bytes = try benchEncode(allocator, &msg);

    var buf = codec.Buffer.init(allocator, .big);
    defer buf.deinit();
    try msg.encode(&buf);
    try benchDecode(allocator, buf.written()[0..bytes]);
}
