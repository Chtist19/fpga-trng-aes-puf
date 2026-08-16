# TRNG 模块交付包

本目录是给 PUF 队友和 AES 队友使用的 TRNG 模块交付包。它只包含对接需要的源码、约束、上位机脚本和说明文档，不要求队友打开你的完整 Vivado 工程。

## 目录结构

```text
TRNG_module_package
├── rtl
│   ├── neoTRNG.vhd             # neoTRNG 熵源，含冯诺依曼去偏与 CRC 风格压缩
│   ├── trng_core.vhd           # TRNG 字节输出包装
│   ├── sha256.v                # FPGA SHA-256 模块
│   ├── uart_tx.v               # UART 发送模块
│   ├── trng_uart_top.v         # 当前板级测试顶层，串口输出完整数据帧
│   └── trng_key_provider.v     # 推荐给 AES/PUF 集成使用的板内接口包装
├── constraints
│   └── trng.xdc                # 当前开发板管脚和时钟约束
├── software
│   └── capture_trng_uart.py    # 串口采集、包尾判断、SHA-256 复算脚本
└── docs
    ├── 接口说明.md
    ├── AES对接说明.md
    ├── PUF对接说明.md
    └── 使用步骤.md
```

## 推荐对接方式

正式集成时推荐使用：

```text
rtl/trng_key_provider.v
```

它提供两类输出：

- 给 PUF 或协议模块使用的随机字节流：`trng_valid_o`、`trng_data_o`
- 给 AES 使用的 256 bit 密钥：`key_valid_o`、`key_ready_i`、`key_data_o`

串口顶层 `trng_uart_top.v` 主要用于测试、采集和统计，不建议作为最终 AES/PUF 板内接口。

## 当前测试帧格式

当前原始工程串口帧格式为：

```text
AA 55 + 00 80 + 128 字节原始随机数 + 32 字节 SHA-256 + 5A A5 33 CC
```

总长度为：

```text
168 字节
```

其中 `5A A5 33 CC` 只是包尾结束判断，不是 CRC 校验。

## 版本说明

- 熵源：neoTRNG，`NUM_CELLS = 3`
- 每输出 1 字节使用的去偏 bit 数：`NUM_RAW_BITS = 64`
- SHA 输入长度：128 字节
- SHA 输出长度：32 字节
- UART 参数：115200，8N1，无流控
