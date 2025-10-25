#!/usr/bin/env python3
import subprocess

def get_audio_streams() -> dict[str, list]:
    """
    返回正在播放声音的应用列表：
    {
        app_name: str, [id: str, volume: float, is_muted: 0/1]
    }
    """
    result = subprocess.run(["wpctl", "status", "-k"], capture_output=True, text=True)
    lines = result.stdout.splitlines()
    streams = {}
    capture = False
    for line in lines:
        if line.find("Streams:") != -1:
            capture = True
            continue
        if capture:
            if line.strip() == "":
                break  # Streams结束
            # 匹配父级行（ID + 应用名）
            stripped = line.strip()
            if stripped.find("input_F") != -1 \
                or stripped.find("output_F") != -1 \
                or stripped.find("monitor_F") != -1 \
                or stripped.find("cava") != -1:
                continue  # 忽略这些行
            if stripped[0].isdigit() and '.' in stripped:
                parts = stripped.split('.', 1)
                stream_id = parts[0].strip()
                app_name = parts[1].strip()
                # wpctl get-volume @ID@ 获取音量
                volume_result = subprocess.run(["wpctl", "get-volume", f"{stream_id}"], capture_output=True, text=True)
                # result: Volume: 1.00
                try:
                    if volume_result.stdout.find("MUTED") != -1:
                        volume = float(volume_result.stdout.split(':')[1].strip().split()[0]) * 100
                        is_muted = 1
                    else:
                        volume = float(volume_result.stdout.split(':')[1].strip()) * 100
                        is_muted = 0
                    while app_name in streams:
                        app_name += " "
                    streams.update({app_name: [stream_id, volume, is_muted]})
                except (IndexError, ValueError):
                    print("Error parsing volume for stream ID:", stream_id)
                    pass
    return streams

streams = get_audio_streams()
print(streams.__str__().replace("'", '"'))
