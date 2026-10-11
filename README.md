# fin-proto-risk-bin-zig

RBP(Risk Binary Protocol)风控二进制协议 v0.2.0 的 Zig 消息库(模块名
`risk_binary`),基于 [fin-proto-runtime-bin-zig](../fin-proto-runtime-bin-zig) 运行时。
对应 Rust 版本:[fin-proto-risk-bin-rs](https://github.com/xinchentechnote/fin-proto-risk-bin-rs)。

`src/` 下的全部 `.zig` 文件由 [fin-protoc](https://github.com/xinchentechnote/fin-protoc)
从 `proto/risk_v0.2.0.pdsl` 生成(`-z` 指定输出目录),请勿手改:

```bash
make compile    # fin-protoc -f proto/risk_v0.2.0.pdsl -z src/
```

## 协议要点

- 帧头定长 32B 大端:`MsgType u32 / Version u16 / Flags u16 / MsgSeq u64 /
  TsNs u64 / BodyLen u32(@lengthOf 回填)/ Checksum u32`
- `Checksum` 为普通字段(帧体字节累加 & 0xFF,由应用层计算/校验,
  flags.NO_CHECKSUM 时置 0),不走 `@calculatedFrom` 自动填充
- `match MsgType as Body` 分发 9 种帧体:事前校验流(NewOrderReq/CancelReq)、
  风控结果同步应答(RiskResult)、回报转发流(OrderConfirm/TradeReport/
  CancelReject/OrderReject)、实时指令流(Instruction/InstrAck)

## 互通测试

`tests/golden/*.bin` 是引擎侧(omni-rt-risk/risk-binary)RbpFrame 编码器产出的
golden 帧,`tests/golden_interop.zig` 用 `@embedFile` 逐帧解码、逐字段断言并
重编码要求字节级一致——与 fin-proto-risk-bin-rs 的 `golden_interop.rs` 使用
同一组帧,任何字段顺序/类型/定长/字节序漂移都会在这里暴露。

```bash
zig build test      # 11 个生成 round-trip 测试 + 9 个 golden 互通测试
```

依赖通过 `build.zig.zon` 的 path 依赖引入运行时:

```zig
.dependencies = .{
    .binary_codec = .{ .path = "../fin-proto-runtime-bin-zig" },
},
```
