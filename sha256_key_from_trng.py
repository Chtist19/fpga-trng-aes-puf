import argparse
import hashlib
from pathlib import Path


# 在 PyCharm 中直接运行时，优先修改这里的默认值。
DEFAULT_INPUT = r"F:\fpga_project\trng_data.bin"
DEFAULT_OUTPUT = r"F:\fpga_project\aes_keys.txt"
DEFAULT_RAW_BYTES_PER_KEY = 64
DEFAULT_KEY_COUNT = 8


def parse_args():
    parser = argparse.ArgumentParser(description="使用 SHA-256 对 TRNG 原始数据做后处理并生成 AES 密钥。")
    parser.add_argument("--input", default=DEFAULT_INPUT, help="TRNG 原始随机数字节文件。")
    parser.add_argument("--output", default=DEFAULT_OUTPUT, help="输出密钥文本文件。")
    parser.add_argument("--raw-bytes", type=int, default=DEFAULT_RAW_BYTES_PER_KEY, help="每个密钥使用的原始随机字节数。")
    parser.add_argument("--count", type=int, default=DEFAULT_KEY_COUNT, help="要生成的密钥数量。")
    return parser.parse_args()


def derive_keys(raw_data, raw_bytes_per_key, key_count):
    required_bytes = raw_bytes_per_key * key_count
    if len(raw_data) < required_bytes:
        raise ValueError(f"原始随机数据不足：需要 {required_bytes} 字节，实际只有 {len(raw_data)} 字节。")

    keys = []
    for index in range(key_count):
        start = index * raw_bytes_per_key
        end = start + raw_bytes_per_key
        raw_block = raw_data[start:end]

        digest = hashlib.sha256(raw_block).digest()
        aes128_key = digest[:16]
        aes256_key = digest

        keys.append(
            {
                "index": index,
                "raw_start": start,
                "raw_end": end - 1,
                "sha256": digest.hex(),
                "aes128": aes128_key.hex(),
                "aes256": aes256_key.hex(),
            }
        )

    return keys


def write_key_report(output_path, input_path, raw_bytes_per_key, keys):
    lines = []
    lines.append("TRNG + SHA-256 AES 密钥生成结果")
    lines.append("=" * 38)
    lines.append(f"输入文件：{input_path}")
    lines.append(f"每个密钥使用原始随机字节数：{raw_bytes_per_key}")
    lines.append(f"生成密钥数量：{len(keys)}")
    lines.append("")

    for item in keys:
        lines.append(f"密钥序号：{item['index']}")
        lines.append(f"原始数据范围：第 {item['raw_start']} 到 {item['raw_end']} 字节")
        lines.append(f"SHA-256 摘要：{item['sha256']}")
        lines.append(f"AES-128 密钥：{item['aes128']}")
        lines.append(f"AES-256 密钥：{item['aes256']}")
        lines.append("")

    output_path.write_text("\n".join(lines), encoding="utf-8")


def main():
    args = parse_args()
    input_path = Path(args.input)
    output_path = Path(args.output)

    if args.raw_bytes < 32:
        raise ValueError("建议每个密钥至少使用 32 字节 TRNG 原始数据。")

    raw_data = input_path.read_bytes()
    keys = derive_keys(raw_data, args.raw_bytes, args.count)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    write_key_report(output_path, input_path, args.raw_bytes, keys)

    print("密钥生成完成。")
    print(f"输入文件：{input_path}")
    print(f"输出文件：{output_path.resolve()}")
    print()
    print("第 0 个密钥预览：")
    print(f"AES-128：{keys[0]['aes128']}")
    print(f"AES-256：{keys[0]['aes256']}")


if __name__ == "__main__":
    main()
