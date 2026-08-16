# FPGA TRNG / SHA-256 / AES-PUF 对接项目

本仓库用于管理 SRTP 项目中的 FPGA TRNG 模块、SHA-256 后处理、串口采集脚本，以及与 AES、PUF 队友对接所需的接口文档。

## 当前模块

- `project_1`：原始 TRNG 工程，neoTRNG 保留冯诺依曼去偏与 CRC 风格压缩，并接入 SHA-256 和 UART 调试输出。
- `project_1_light`：轻量对照工程，去掉 neoTRNG 内部 CRC 风格压缩，只保留冯诺依曼去偏和 SHA-256。
- `TRNG_module_package`：给队友使用的 TRNG 交付包，包含 RTL、约束、Python 脚本和接口文档。

## 推荐给队友看的入口

```text
TRNG_module_package/README.md
TRNG_module_package/docs/接口说明.md
TRNG_module_package/docs/AES对接说明.md
TRNG_module_package/docs/PUF对接说明.md
TRNG_module_package/docs/使用步骤.md
```

## 关键接口

板内集成推荐使用：

```text
TRNG_module_package/rtl/trng_key_provider.v
```

AES 队友使用：

```text
key_valid_o
key_ready_i
key_data_o[255:0]
key_index_o[15:0]
```

PUF 队友使用：

```text
trng_valid_o
trng_data_o[7:0]
```

串口测试帧格式：

```text
AA 55 + 00 80 + 128 字节原始随机数 + 32 字节 SHA-256 + 5A A5 33 CC
```

其中 `5A A5 33 CC` 是包尾结束判断，不是 CRC 校验。

## 不提交到 Git 的内容

仓库通过 `.gitignore` 排除了以下内容：

- Vivado 综合、实现、缓存、中间报告
- `.bin` 随机数采集数据
- 第三方压缩包和大型工具目录
- 生成的 bitstream、checkpoint 和临时日志

需要共享大文件时，建议单独发网盘或使用 GitHub Release，不要直接放进主分支。

## 基本协作流程

```powershell
git pull
git checkout -b feature/你的功能名
git add 文件
git commit -m "说明本次修改"
git push -u origin feature/你的功能名
```

之后在 GitHub 上创建 Pull Request，让队友检查后再合并。
