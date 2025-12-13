#!/usr/bin/env python3
import subprocess
from functools import lru_cache


@lru_cache(maxsize=128)
def get_client_app_name(client_id: str) -> str | None:
    r = subprocess.run(
        ["wpctl", "inspect", client_id],
        capture_output=True,
        text=True
    )

    for line in r.stdout.splitlines():
        if "application.name" in line:
            return line.split("=", 1)[1].strip().strip('"')
    return None


@lru_cache(maxsize=128)
def get_host_app(stream_id: str) -> str | None:
    """
    stream(node) → client.id → client.application.name
    """
    r = subprocess.run(
        ["wpctl", "inspect", stream_id],
        capture_output=True,
        text=True
    )

    client_id = None
    for line in r.stdout.splitlines():
        if "client.id" in line:
            client_id = line.split("=", 1)[1].strip().strip('"')
            break

    if not client_id:
        return None

    return get_client_app_name(client_id)


def get_audio_streams() -> dict[str, list]:
    """
    返回正在播放声音的应用列表：
    {
        app_name: [id: str, volume: float, is_muted: 0/1]
    }
    """
    result = subprocess.run(
        ["wpctl", "status", "-k"],
        capture_output=True,
        text=True
    )

    lines = result.stdout.splitlines()
    streams = {}
    capture = False

    for line in lines:
        if "Streams:" in line:
            capture = True
            continue

        if capture:
            if not line.strip():
                break

            stripped = line.strip()

            if (
                "input_F" in stripped
                or "output_F" in stripped
                or "monitor_F" in stripped
                or "cava" in stripped
            ):
                continue

            if stripped[0].isdigit() and "." in stripped:
                parts = stripped.split(".", 1)
                stream_id = parts[0].strip()
                node_name = parts[1].strip()

                host_app = get_host_app(stream_id)

                if host_app and host_app.lower() not in node_name.lower():
                    app_name = f"{node_name}: {host_app}"
                else:
                    app_name = node_name

                volume_result = subprocess.run(
                    ["wpctl", "get-volume", stream_id],
                    capture_output=True,
                    text=True
                )

                try:
                    out = volume_result.stdout
                    if "MUTED" in out:
                        volume = float(out.split(":")[1].strip().split()[0]) * 100
                        is_muted = 1
                    else:
                        volume = float(out.split(":")[1].strip()) * 100
                        is_muted = 0

                    key = app_name
                    while key in streams:
                        key += " "

                    streams[key] = [stream_id, volume, is_muted]

                except (IndexError, ValueError):
                    pass

    return streams


if __name__ == "__main__":
    import json
    streams = get_audio_streams()
    print(json.dumps(streams))
