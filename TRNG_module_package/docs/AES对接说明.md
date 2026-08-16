# AES 对接说明

## 1. 推荐用法

AES 队友建议直接对接 `trng_key_provider.v` 的密钥接口：

```text
key_valid_o
key_ready_i
key_data_o[255:0]
key_index_o[15:0]
```

不要从 UART 帧里取密钥。UART 是测试通道，正式板内集成应直接走 FPGA 内部信号。

## 2. AES-256 接法

当 `key_valid_o = 1` 时：

```verilog
aes_key <= key_data_o;
```

确认 AES 已经保存密钥后：

```verilog
key_ready_i <= 1'b1; // 拉高 1 拍
```

下一拍拉低：

```verilog
key_ready_i <= 1'b0;
```

## 3. AES-128 接法

如果只做 AES-128，建议取 SHA-256 前 16 字节：

```verilog
aes_key_128 <= key_data_o[255:128];
```

## 4. 推荐状态机

```text
等待 key_valid_o
    ↓
锁存 key_data_o
    ↓
key_ready_i 拉高 1 拍
    ↓
开始 AES 加密或更新密钥
```

## 5. 注意事项

- `key_valid_o = 1` 时，`key_data_o` 会保持稳定，直到 AES 拉高 `key_ready_i`。
- `key_ready_i` 建议只拉高 1 个 `clk_i` 周期。
- `key_index_o` 可用于调试，确认 AES 有没有重复使用同一把密钥。
- 如果 AES 不需要频繁换密钥，可以一直保持 `key_ready_i = 0`，密钥会停在输出端口等待读取。
