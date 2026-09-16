#!/usr/bin/env python3
"""
Backend engine for AirCard native macOS GUI app.
"""
from __future__ import annotations

import io
import json
import os
import sys
from pathlib import Path

# Augment PATH so bundled tools and system tools are always found
script_dir = Path(__file__).resolve().parent
bundled_bin = script_dir / "bin"
bundled_lib = script_dir / "lib"
app_bin = Path("/Applications/AirCard.app/Contents/Resources/bin")
app_lib = Path("/Applications/AirCard.app/Contents/Resources/lib")

paths_to_add = [
    str(bundled_bin),
    str(app_bin),
    "/opt/homebrew/bin",
    "/usr/local/bin",
    "/usr/bin",
    "/bin"
]
for p in reversed(paths_to_add):
    if os.path.isdir(p) and p not in os.environ.get("PATH", ""):
        os.environ["PATH"] = f"{p}:{os.environ.get('PATH', '')}"

lib_paths = [str(bundled_lib), str(app_lib)]
for lp in lib_paths:
    if os.path.isdir(lp):
        cur_dyld = os.environ.get("DYLD_LIBRARY_PATH", "")
        os.environ["DYLD_LIBRARY_PATH"] = f"{lp}:{cur_dyld}" if cur_dyld else lp

from apply_card_skin import (
    native,
    operation_ok,
    write_file,
    ROOT,
    DEVICE_HELPER,
)
from aircard import (
    get_connected_device,
    load_saved_cards,
    save_cards,
    TARGET_ASSETS,
    CACHE_FILES,
)


def cmd_device():
    device = get_connected_device()
    if not device:
        print(json.dumps({"connected": False}))
        return
    probe = native("probe", device["udid"])
    device["airlift_compatible"] = operation_ok(probe)
    device["connected"] = True
    print(json.dumps(device))


def cmd_get_saved_cards():
    cards = load_saved_cards()
    print(json.dumps({"ok": True, "cards": cards}))


def cmd_save_cards(cards_json: str):
    try:
        cards = json.loads(cards_json)
        if isinstance(cards, list):
            save_cards(cards)
            print(json.dumps({"ok": True}))
            return
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))
        return
    print(json.dumps({"ok": False, "error": "Invalid format"}))


def cmd_prepare_image(src: str, dst: str):
    path = Path(src).expanduser()
    if not path.is_file():
        print(json.dumps({"ok": False, "error": f"File not found: {src}"}))
        return
    try:
        from PIL import Image, ImageOps
        with Image.open(path) as img:
            img = img.convert("RGBA")
            target_size = (1536, 969)
            fitted = ImageOps.fit(img, target_size, method=Image.Resampling.LANCZOS)
            fitted.save(dst, format="PNG")
        print(json.dumps({"ok": True, "path": dst}))
        return
    except ImportError:
        pass
    except Exception as e:
        pass
    
    # Fallback to macOS built-in sips tool (built into every macOS, 0 dependencies!)
    try:
        import subprocess
        subprocess.check_call([
            "/usr/bin/sips",
            "-s", "format", "png",
            "-z", "969", "1536",
            str(path),
            "--out", str(dst)
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        print(json.dumps({"ok": True, "path": dst}))
    except Exception as e:
        print(json.dumps({"ok": False, "error": str(e)}))


def cmd_flash(udid: str, card_hash: str, image_path: str):
    img_path = Path(image_path)
    if not img_path.is_file():
        print(json.dumps({"ok": False, "error": "Image file not found"}))
        return

    payload = img_path.read_bytes()
    pkpass_dir = f"/var/mobile/Library/Passes/Cards/{card_hash}.pkpass"
    
    total_steps = len(TARGET_ASSETS) + 2
    step = 0

    for asset in TARGET_ASSETS:
        step += 1
        print(json.dumps({
            "type": "progress",
            "card": card_hash,
            "step": step,
            "total": total_steps,
            "asset": asset,
            "message": f"Writing {asset}..."
        }))
        sys.stdout.flush()
        ok = write_file(udid, pkpass_dir, asset, payload)
        if not ok:
            print(json.dumps({
                "type": "error",
                "card": card_hash,
                "asset": asset,
                "message": f"Failed to write {asset}"
            }))
            sys.stdout.flush()

    # Clear cache
    step += 1
    print(json.dumps({
        "type": "progress",
        "card": card_hash,
        "step": step,
        "total": total_steps,
        "message": "Invalidating system pass cache..."
    }))
    sys.stdout.flush()
    for ext in [".cache", ".pkcache"]:
        cache_dir = f"/var/mobile/Library/Passes/Cards/{card_hash}{ext}"
        for leaf in CACHE_FILES:
            write_file(udid, cache_dir, leaf, b"corrupted")

    step += 1
    print(json.dumps({
        "type": "success",
        "card": card_hash,
        "step": step,
        "total": total_steps,
        "message": f"Successfully updated {card_hash[:12]}..."
    }))
    sys.stdout.flush()


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "No command provided"}))
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "--device":
        cmd_device()
    elif cmd == "--cards":
        cmd_get_saved_cards()
    elif cmd == "--save-cards" and len(sys.argv) > 2:
        cmd_save_cards(sys.argv[2])
    elif cmd == "--prepare-image" and len(sys.argv) > 3:
        cmd_prepare_image(sys.argv[2], sys.argv[3])
    elif cmd == "--flash" and len(sys.argv) > 4:
        cmd_flash(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        print(json.dumps({"error": f"Unknown command: {cmd}"}))
        sys.exit(1)


if __name__ == "__main__":
    main()
