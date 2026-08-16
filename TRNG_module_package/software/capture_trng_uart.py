import argparse
import hashlib
import math
import time
from collections import Counter
from pathlib import Path

import serial


# 在 PyCharm 中直接运行时，优先修改这里的默认值。
DEFAULT_PORT = "COM9"
DEFAULT_BAUD = 115200
DEFAULT_BYTES = 10000000
DEFAULT_OUT = r"F:\fpga_project\trng_data.bin"
DEFAULT_FRAME_OUT = r"F:\fpga_project\trng_frames.bin"
DEFAULT_MISMATCH_LOG = r"F:\fpga_project\trng_mismatch_log.txt"
FRAME_HEADER = b"\xAA\x55"
FRAME_TAIL = b"\x5A\xA5\x33\xCC"
HASH_BYTES = 32
EXPECTED_RAW_LENGTH = 128
DEFAULT_FRAME_COUNT = DEFAULT_BYTES // EXPECTED_RAW_LENGTH
PROGRESS_INTERVAL_FRAMES = 256


def parse_args():
    parser = argparse.ArgumentParser(description="从 FPGA 串口抓取 TRNG 原始随机字节。")
    parser.add_argument("--port", default=DEFAULT_PORT, help="串口号，例如 COM9。")
    parser.add_argument("--baud", type=int, default=DEFAULT_BAUD, help="串口波特率。")
    parser.add_argument("--bytes", type=int, default=DEFAULT_BYTES, help="要抓取的字节数。")
    parser.add_argument("--out", default=DEFAULT_OUT, help="输出二进制文件。")
    parser.add_argument("--mode", choices=["raw", "frame"], default="frame", help="raw 表示旧版原始字节模式，frame 表示新版原始数据+SHA256帧模式。")
    parser.add_argument("--frames", type=int, default=DEFAULT_FRAME_COUNT, help="frame 模式下要抓取的数据帧数量。")
    parser.add_argument("--frame-out", default=DEFAULT_FRAME_OUT, help="frame 模式下保存完整帧数据的文件。")
    parser.add_argument("--mismatch-log", default=DEFAULT_MISMATCH_LOG, help="保存 SHA256 不匹配帧的诊断日志。")
    return parser.parse_args()


def capture_uart(args):
    output_path = Path(args.out)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    received = 0
    start_time = time.time()

    print(f"打开串口：{args.port}，波特率：{args.baud}")
    print(f"输出文件：{output_path}")
    print(f"目标字节数：{args.bytes}")

    with serial.Serial(args.port, args.baud, bytesize=8, parity="N", stopbits=1, timeout=1) as ser:
        ser.reset_input_buffer()

        with output_path.open("wb") as output_file:
            while received < args.bytes:
                chunk_size = min(4096, args.bytes - received)
                data = ser.read(chunk_size)

                if not data:
                    print("暂时没有收到数据。请检查 bitstream、COM 口、USB 线和波特率。")
                    continue

                output_file.write(data)
                received += len(data)

                percent = received * 100 / args.bytes
                print(f"\r已接收 {received}/{args.bytes} 字节，进度 {percent:.1f}%", end="")

    elapsed = max(time.time() - start_time, 0.001)
    speed = received / elapsed
    print()
    print(f"保存完成：{output_path.resolve()}")
    print(f"平均速度：{speed:.1f} 字节/秒")
    return output_path


def read_exact(ser, size):
    data = bytearray()
    while len(data) < size:
        chunk = ser.read(size - len(data))
        if not chunk:
            print("暂时没有收到足够数据。请检查 bitstream、COM 口、USB 线和波特率。")
            continue
        data.extend(chunk)
    return bytes(data)


def find_frame_header(ser):
    previous = b""
    while True:
        current = ser.read(1)
        if not current:
            print("正在等待帧头 AA 55 ...")
            continue
        if previous + current == FRAME_HEADER:
            return
        previous = current


def capture_and_verify_frames(args):
    frame_output_path = Path(args.frame_out)
    raw_output_path = Path(args.out)
    mismatch_log_path = Path(args.mismatch_log)
    frame_output_path.parent.mkdir(parents=True, exist_ok=True)
    raw_output_path.parent.mkdir(parents=True, exist_ok=True)
    mismatch_log_path.parent.mkdir(parents=True, exist_ok=True)

    all_raw = bytearray()
    matched = 0
    mismatched = 0
    tail_errors = 0

    print(f"打开串口：{args.port}，波特率：{args.baud}")
    print(f"目标帧数：{args.frames}")
    print(f"目标原始随机数：{args.frames * EXPECTED_RAW_LENGTH} 字节")
    print("帧格式：AA 55 + 2 字节原始数据长度 + 128 字节原始随机数 + 32 字节 FPGA SHA-256 + 包尾 5A A5 33 CC")

    with serial.Serial(args.port, args.baud, bytesize=8, parity="N", stopbits=1, timeout=1) as ser:
        ser.reset_input_buffer()

        with frame_output_path.open("wb") as frame_file, mismatch_log_path.open("w", encoding="utf-8") as mismatch_log:
            mismatch_log.write("SHA256 不匹配帧诊断日志\n")
            mismatch_log.write("说明：不匹配帧通常表示串口传输错位或误码，不会写入 trng_data.bin。\n\n")
            frame_index = 0
            while frame_index < args.frames:
                find_frame_header(ser)
                length_bytes = read_exact(ser, 2)
                raw_length = int.from_bytes(length_bytes, byteorder="big")

                if raw_length != EXPECTED_RAW_LENGTH:
                    print(f"发现伪帧头，长度字段为 {raw_length}，已丢弃并重新同步。")
                    continue

                raw_data = read_exact(ser, raw_length)
                fpga_hash = read_exact(ser, HASH_BYTES)
                frame_tail = read_exact(ser, len(FRAME_TAIL))

                if frame_tail != FRAME_TAIL:
                    tail_errors += 1
                    print(f"第 {frame_index} 帧：包尾错误，收到 {frame_tail.hex()}，已丢弃并重新同步。")
                    mismatch_log.write(f"帧号：{frame_index}\n")
                    mismatch_log.write("类型：包尾错误，判断为帧错位或串口丢字节\n")
                    mismatch_log.write(f"收到包尾：{frame_tail.hex()}\n")
                    mismatch_log.write(f"期望包尾：{FRAME_TAIL.hex()}\n")
                    mismatch_log.write(f"FPGA SHA256 ：{fpga_hash.hex()}\n")
                    mismatch_log.write(f"原始数据前32字节：{raw_data[:32].hex()}\n\n")
                    continue

                frame_file.write(FRAME_HEADER + length_bytes + raw_data + fpga_hash + frame_tail)

                python_hash = hashlib.sha256(raw_data).digest()
                is_match = python_hash == fpga_hash
                if is_match:
                    matched += 1
                    result = "匹配"
                    all_raw.extend(raw_data)
                else:
                    mismatched += 1
                    result = "不匹配"
                    mismatch_log.write(f"帧号：{frame_index}\n")
                    mismatch_log.write(f"长度：{raw_length}\n")
                    mismatch_log.write(f"FPGA SHA256 ：{fpga_hash.hex()}\n")
                    mismatch_log.write(f"Python SHA256：{python_hash.hex()}\n")
                    mismatch_log.write(f"原始数据前32字节：{raw_data[:32].hex()}\n\n")

                frame_number = frame_index + 1
                should_show_detail = frame_index < 3 or not is_match or frame_number == args.frames
                should_show_progress = frame_number % PROGRESS_INTERVAL_FRAMES == 0

                if should_show_detail:
                    print(f"第 {frame_index} 帧：长度 {raw_length} 字节，SHA256 {result}")
                    print(f"  FPGA ：{fpga_hash.hex()}")
                    print(f"  Python：{python_hash.hex()}")
                elif should_show_progress:
                    raw_bytes = frame_number * EXPECTED_RAW_LENGTH
                    percent = frame_number * 100 / args.frames
                    print(
                        f"已接收 {frame_number}/{args.frames} 帧，"
                        f"原始随机数 {raw_bytes} 字节，进度 {percent:.1f}% ，"
                        f"匹配 {matched}，不匹配 {mismatched}，包尾错误 {tail_errors}"
                    )

                frame_index += 1

    raw_output_path.write_bytes(all_raw)
    print()
    print(f"完整帧数据保存到：{frame_output_path.resolve()}")
    print(f"已匹配原始随机数保存到：{raw_output_path.resolve()}")
    print(f"不匹配诊断日志保存到：{mismatch_log_path.resolve()}")
    print(f"匹配帧数：{matched}")
    print(f"不匹配帧数：{mismatched}")
    print(f"包尾错误帧数：{tail_errors}")
    return raw_output_path


def evaluate_randomness(data):
    byte_count = len(data)
    if byte_count == 0:
        raise ValueError("没有可评估的数据。")

    bit_count = byte_count * 8
    one_count = sum(byte.bit_count() for byte in data)
    zero_count = bit_count - one_count
    one_ratio = one_count / bit_count
    monobit_z = (one_count - bit_count / 2) / math.sqrt(bit_count / 4)

    counts = Counter(data)
    expected = byte_count / 256
    chi_square = sum((counts.get(value, 0) - expected) ** 2 / expected for value in range(256))
    entropy = -sum((count / byte_count) * math.log2(count / byte_count) for count in counts.values())

    runs, max_run_length = count_bit_runs(data)
    expected_runs = 2 * one_count * zero_count / bit_count + 1
    runs_ratio = runs / expected_runs

    adjacent_corr = adjacent_byte_correlation(data)
    byte_mean = sum(data) / byte_count

    return {
        "byte_count": byte_count,
        "bit_count": bit_count,
        "one_count": one_count,
        "zero_count": zero_count,
        "one_ratio": one_ratio,
        "monobit_z": monobit_z,
        "entropy": entropy,
        "chi_square": chi_square,
        "byte_min_count": min(counts.get(value, 0) for value in range(256)),
        "byte_max_count": max(counts.get(value, 0) for value in range(256)),
        "byte_mean": byte_mean,
        "runs": runs,
        "expected_runs": expected_runs,
        "runs_ratio": runs_ratio,
        "max_run_length": max_run_length,
        "adjacent_corr": adjacent_corr,
    }


def count_bit_runs(data):
    previous_bit = None
    runs = 0
    current_length = 0
    max_length = 0

    for byte in data:
        for bit_index in range(7, -1, -1):
            bit = (byte >> bit_index) & 1

            if previous_bit is None:
                runs = 1
                current_length = 1
            elif bit == previous_bit:
                current_length += 1
            else:
                max_length = max(max_length, current_length)
                runs += 1
                current_length = 1

            previous_bit = bit

    max_length = max(max_length, current_length)
    return runs, max_length


def adjacent_byte_correlation(data):
    if len(data) < 2:
        return float("nan")

    xs = data[:-1]
    ys = data[1:]
    mean_x = sum(xs) / len(xs)
    mean_y = sum(ys) / len(ys)

    covariance = sum((x - mean_x) * (y - mean_y) for x, y in zip(xs, ys))
    variance_x = sum((x - mean_x) ** 2 for x in xs)
    variance_y = sum((y - mean_y) ** 2 for y in ys)

    if variance_x == 0 or variance_y == 0:
        return float("nan")

    return covariance / math.sqrt(variance_x * variance_y)


def print_report(report):
    print()
    print("随机性快速评估报告")
    print("-----------------------")
    print(f"字节数                ：{report['byte_count']}")
    print(f"比特数                ：{report['bit_count']}")
    print(f"0 的数量              ：{report['zero_count']}")
    print(f"1 的数量              ：{report['one_count']}")
    print(f"1 的比例              ：{report['one_ratio']:.6f}  理想值 0.500000")
    print(f"单比特 z 分数         ：{report['monobit_z']:.3f}  越接近 0 越好")
    print(f"字节熵                ：{report['entropy']:.6f} bit/byte  理想值 8.000000")
    print(f"字节卡方值            ：{report['chi_square']:.3f}  自由度 255")
    print(f"字节出现次数最小/最大 ：{report['byte_min_count']} / {report['byte_max_count']}")
    print(f"字节均值              ：{report['byte_mean']:.3f}  理想值约 127.5")
    print(f"游程数量              ：{report['runs']}")
    print(f"理论游程数量          ：{report['expected_runs']:.3f}")
    print(f"游程 实际/理论        ：{report['runs_ratio']:.6f}  理想值约 1.000000")
    print(f"最长连续相同比特长度  ：{report['max_run_length']}")
    print(f"相邻字节相关性        ：{report['adjacent_corr']:.6f}  理想值约 0")

    if abs(report["one_ratio"] - 0.5) < 0.002 and report["entropy"] > 7.99 and abs(report["adjacent_corr"]) < 0.01:
        print("快速结论              ：作为第一次硬件快速检查，结果看起来正常。")
    else:
        print("快速结论              ：建议采集更多数据，或进行更深入测试。")


def main():
    args = parse_args()
    if args.mode == "frame":
        output_path = capture_and_verify_frames(args)
    else:
        output_path = capture_uart(args)
    data = output_path.read_bytes()
    report = evaluate_randomness(data)
    print_report(report)


if __name__ == "__main__":
    main()
