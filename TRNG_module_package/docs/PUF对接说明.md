# PUF 对接说明

## 1. 推荐用法

PUF 队友可以使用 `trng_key_provider.v` 的随机字节流接口：

```text
trng_valid_o
trng_data_o[7:0]
```

当 `trng_valid_o = 1` 时，`trng_data_o` 是一个有效随机字节。

## 2. 生成 challenge 示例

如果 PUF 需要 128 bit challenge，可以连续收集 16 个有效随机字节：

```text
16 字节 = 128 bit
```

流程：

```text
等待 trng_valid_o = 1
采样 trng_data_o
计数 +1
收满 16 字节后组成 challenge
```

## 3. 生成 nonce 或随机扰动

如果 PUF 协议只需要短随机数，例如 32 bit nonce，可以连续收集 4 字节：

```text
4 字节 = 32 bit
```

## 4. 注意事项

- 当前随机字节接口没有 `ready`，PUF 不需要时可以忽略随机字节。
- 如果 PUF 希望“请求一次给固定长度随机数”，后续可以在 PUF 外层加一个小 FIFO 或计数器。
- `trng_data_o` 是已经经过 neoTRNG 冯诺依曼去偏和 CRC 风格压缩后的随机字节。
