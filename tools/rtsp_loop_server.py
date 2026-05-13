import argparse
import ipaddress
import os
import shutil
import signal
import socket
import subprocess
import sys
import threading
import time
from pathlib import Path
from typing import List, Optional


def list_candidate_ips() -> List[str]:
    candidates: List[str] = []

    probe = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    try:
      probe.connect(("8.8.8.8", 80))
      ip = probe.getsockname()[0]
      if ip:
          candidates.append(ip)
    except OSError:
      pass
    finally:
      probe.close()

    try:
        for info in socket.getaddrinfo(socket.gethostname(), None, socket.AF_INET):
            ip = info[4][0]
            if ip:
                candidates.append(ip)
    except OSError:
        pass

    unique: List[str] = []
    for ip in candidates:
        if ip not in unique:
            unique.append(ip)
    return unique


def is_preferred_lan_ip(ip: str) -> bool:
    try:
        addr = ipaddress.ip_address(ip)
    except ValueError:
        return False

    if addr.is_loopback or addr.is_link_local or addr.is_multicast:
        return False
    if ip.startswith("198.18.") or ip.startswith("198.19."):
        return False
    return addr.is_private


def resolve_local_ip() -> str:
    candidates = list_candidate_ips()
    for ip in candidates:
        if is_preferred_lan_ip(ip):
            return ip

    for ip in candidates:
        if not ip.startswith("127."):
            return ip

    return "127.0.0.1"


def require_command(name: str) -> str:
    path = shutil.which(name)
    if not path:
        raise FileNotFoundError(f"未找到命令: {name}")
    return path


def build_ffmpeg_command(
    ffmpeg_path: str,
    input_file: Path,
    push_url: str,
    use_copy: bool,
) -> List[str]:
    command = [
        ffmpeg_path,
        "-re",
        "-stream_loop",
        "-1",
        "-i",
        str(input_file),
    ]

    if use_copy:
        command.extend(
            [
                "-c",
                "copy",
            ],
        )
    else:
        command.extend(
            [
                "-an",
                "-c:v",
                "libx264",
                "-preset",
                "ultrafast",
                "-tune",
                "zerolatency",
                "-pix_fmt",
                "yuv420p",
                "-r",
                "15",
                "-g",
                "15",
                "-b:v",
                "1000k",
            ],
        )

    command.extend(
        [
            "-f",
            "rtsp",
            "-rtsp_transport",
            "tcp",
            push_url,
        ],
    )
    return command


def terminate_process(name: str, process: Optional[subprocess.Popen]) -> None:
    if process is None or process.poll() is not None:
        return

    print(f"[stop] 正在停止 {name} ...")
    try:
        process.terminate()
        process.wait(timeout=5)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=5)


def forward_logs(name: str, process: subprocess.Popen) -> None:
    if process.stdout is None:
        return

    for line in process.stdout:
        print(f"[{name}] {line.rstrip()}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="启动 MediaMTX 并循环推流脚本目录下的 test.mp4",
    )
    parser.add_argument(
        "--file",
        default="test.mp4",
        help="要循环推送的本地视频文件，默认是脚本目录下的 test.mp4",
    )
    parser.add_argument(
        "--stream",
        default="camera",
        help="RTSP 流名称，默认 camera",
    )
    parser.add_argument(
        "--port",
        type=int,
        default=8554,
        help="RTSP 端口，默认 8554",
    )
    parser.add_argument(
        "--host",
        default=None,
        help="手动指定拉流用的本机 IP，默认自动探测",
    )
    parser.add_argument(
        "--transcode",
        action="store_true",
        help="改为转码推流；默认直接 copy，优先保证和 MediaMTX 的兼容性",
    )
    args = parser.parse_args()

    script_dir = Path(__file__).resolve().parent
    input_file = (script_dir / args.file).resolve()
    if not input_file.exists():
        print(f"未找到视频文件: {input_file}")
        print("请把 test.mp4 放到脚本同目录，或用 --file 指定。")
        return 1

    try:
        mediamtx_path = require_command("mediamtx")
        ffmpeg_path = require_command("ffmpeg")
    except FileNotFoundError as exc:
        print(exc)
        return 1

    host = args.host or resolve_local_ip()
    push_url = f"rtsp://127.0.0.1:{args.port}/{args.stream}"
    play_url_local = f"rtsp://127.0.0.1:{args.port}/{args.stream}"
    play_url_lan = f"rtsp://{host}:{args.port}/{args.stream}"
    config_file = script_dir / "mediamtx.generated.yml"

    mediamtx_process: Optional[subprocess.Popen] = None
    ffmpeg_process: Optional[subprocess.Popen] = None

    def cleanup(*_: object) -> None:
        terminate_process("ffmpeg", ffmpeg_process)
        terminate_process("mediamtx", mediamtx_process)

    signal.signal(signal.SIGINT, cleanup)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, cleanup)

    try:
        config_file.write_text(
            "paths:\n"
            f"  {args.stream}:\n"
            "    source: publisher\n",
            encoding="utf-8",
        )

        print(f"[start] MediaMTX: {mediamtx_path}")
        print(f"[config] {config_file}")
        mediamtx_process = subprocess.Popen(
            [mediamtx_path, str(config_file)],
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        mediamtx_log_thread = threading.Thread(
            target=forward_logs,
            args=("mediamtx", mediamtx_process),
            daemon=True,
        )
        mediamtx_log_thread.start()

        time.sleep(1.5)
        if mediamtx_process.poll() is not None:
            print("[error] MediaMTX 启动失败。")
            return 1

        ffmpeg_command = build_ffmpeg_command(
            ffmpeg_path=ffmpeg_path,
            input_file=input_file,
            push_url=push_url,
            use_copy=not args.transcode,
        )

        print(f"[start] FFmpeg -> {push_url}")
        print(f"[mode] {'copy' if not args.transcode else 'transcode'}")
        ffmpeg_process = subprocess.Popen(
            ffmpeg_command,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )

        print()
        print("RTSP 服务已启动。")
        print(f"本机拉流地址: {play_url_local}")
        print(f"局域网拉流地址: {play_url_lan}")
        print("按 Ctrl+C 停止。")
        print()

        assert ffmpeg_process.stdout is not None
        for line in ffmpeg_process.stdout:
            print(f"[ffmpeg] {line.rstrip()}")

        exit_code = ffmpeg_process.wait()
        if exit_code != 0:
            print(f"[error] FFmpeg 已退出，退出码: {exit_code}")
            return exit_code
        return 0
    finally:
        cleanup()
        try:
            if config_file.exists():
                os.remove(config_file)
        except OSError:
            pass


if __name__ == "__main__":
    sys.exit(main())
