# TRNG 模块接口定义 v1.0

> 模块归属：贾同学（TRNG）
> 对接方：队友（PUF 模块）、队友（AES 模块）
> 依据实现：`project_1`（Zynq UltraScale+ xczu3eg，100 MHz 差分系统时钟）
> 状态：草案，等待三方对齐后冻结

---

## 0. 通用约定（三方共同遵守）

| 项目 | 约定 |
|---|---|
| 时钟 | 片上统一使用 `sys_clk`（100 MHz），**不做跨时钟域**，各模块不得另起时钟 |
| 复位 | `sys_rst_n` 低有效、异步复位，全局统一 |
| 握手语义 | `valid`/`ready`：`valid=1` 表示数据有效；`ready=1` 表示接收方就绪；两者同为 1 时完成一次传输。**valid=1 且 ready=0 时，发送方必须保持数据不变** |
| 字节序 | 字节流按先后顺序；`key_data` 见接口 B 定义 |

TRNG 对外共两个业务接口 + 一个调试口：

- **接口 A**：随机数流（给 PUF / 协议用 nonce、IV、挑战值等）
- **接口 B**：AES 密钥（给 AES 加解密用）
- **调试口**：UART（仅测试取证，认证流程禁用）

---

## 1. 接口 A —— 随机数流接口（供 PUF/协议）

随机字节流，从熵源直接输出。熵源为 3 路环形振荡器（neoTRNG），片内已做
von Neumann 去偏 + CRC-8 压缩，输出字节质量无需再后处理。

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `trng_valid_o` | 输出 | 1 | 本拍 `trng_data_o` 有效（每字节 1 拍） |
| `trng_data_o`  | 输出 | 8 | 随机字节 |
| `trng_ready_i` | 输入 | 1 | 接收方就绪（**待集成时新增**，当前实现尚无背压） |

- 无背压期间（`ready=0`）的字节：由接收方决定是否丢弃；TRNG 侧不缓存。
- 吞吐：以板上实测为准（可用现有 `capture_trng_uart.py` 测 `平均速度` 得到字节率）。
- 用途示例：PUF 上电随机化、challenge 生成、协议 nonce/IV。

## 2. 接口 B —— AES 密钥接口（供 AES）

密钥由片上硬件派生：**128 字节原始随机数 → SHA-256（`sha256.v`）→ 32 字节摘要**。

| 信号 | 方向 | 位宽 | 说明 |
|---|---|---|---|
| `key_valid_o` | 输出 | 1 | 密钥就绪，高有效 |
| `key_ready_i` | 输入 | 1 | AES 接受密钥 |
| `key_data_o`  | 输出 | 256 | 密钥数据，见下方字节序 |
| `key_size_o`  | 输出 | 1 | 1 = AES-256，0 = AES-128 |
| `key_index_o` | 输出 | 8 | 密钥序号（0~255 循环），双方对账用 |

**密钥数据布局**（摘要字节 D0..D31，D0 为 SHA-256 输出的第一个字节）：
- `key_data[255:248] = D0`，…，`key_data[7:0] = D31`（即字节按大端排布）
- AES-128：取 `key_data[127:0]`（D16..D31）
- AES-256：取 `key_data[255:0]`（D0..D31）

**时序约定**：
1. 密钥计算完成 → `key_valid_o` 拉高，数据稳定；
2. AES 就绪后拉 `key_ready_i` 一拍，完成握手 → TRNG 下一拍撤 `key_valid_o`；
3. 两把密钥之间至少间隔 1 拍（防止连发误读）；
4. TRNG 处于「收集/哈希/发送」忙态时，新到的随机字节**直接丢弃**（不影响安全性，只影响速率）。

**密钥生成速率** ≈ 随机字节率 ÷ 128（把/秒）。若 AES 侧需要更高吞吐，后续可并行多路或提高采集效率（另行协商）。

## 3. 调试口 —— UART（测试取证专用）

| 信号 | 方向 | 说明 |
|---|---|---|
| `test_mode_i` | 输入 | 1 = 允许 UART 输出；0 = UART 静默 |
| `uart_txd` | 输出 | 115200-8N1，帧 = `AA 55` + 长度(2B) + 128B 原始 + 32B SHA-256 |

- 测试路径完全沿用现有 `trng_uart_top` + `capture_trng_uart.py`，用于 NIST SP 800-22 等随机性取证。
- **安全红线：正式认证流程 `test_mode_i=0`；密钥数据永不进入 UART 帧。** 密钥只经接口 B 交付。

## 4. 集成顶层端口草案（供三方对账）

```verilog
module trng_key_top (
    // 系统
    input        sys_clk_p,
    input        sys_clk_n,
    input        sys_rst_n,
    // 测试模式
    input        test_mode_i,
    // --- 接口 A：随机数流（PUF/协议）---
    output       trng_valid_o,
    output [7:0] trng_data_o,
    input        trng_ready_i,
    // --- 接口 B：AES 密钥 ---
    output       key_valid_o,
    input        key_ready_i,
    output [255:0] key_data_o,
    output       key_size_o,
    output [7:0] key_index_o,
    // --- 调试 ---
    output       uart_txd,
    output [1:0] led
);
```

## 5. 需要队友确认的问题

**AES 侧**：
- [ ] 取钥方式：按块（接口 B，推荐）还是按字节流？
- [ ] 密钥长度：128 / 256 / 都要（`key_size_o` 可配置）？
- [ ] 是否需要 `key_index_o` 对账，还是每次只取一把？

**PUF 侧**：
- [ ] 字节流接口是否够用？是否需要 burst/定长读取（如一次 32/64 字节）？
- [ ] 是否需要独立的 `trng_enable` 控制（省电/隔离）？

**三方共同**：
- [ ] 是否同一块 FPGA 集成（推荐），时钟是否统一 100 MHz？

---

## 变更记录

| 版本 | 日期 | 说明 |
|---|---|---|
| v1.0 | 草案 | 初版，待对齐冻结 |
