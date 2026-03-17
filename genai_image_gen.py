#!/usr/bin/env -S uv run --script
#
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "google-genai",
#   "Pillow",
# ]
# ///

"""Generic GenAI image generator (Vertex AI via google-genai).

Design goals:
- Generic: no repo assumptions (article parsing etc.).
- Deterministic file outputs: basename + index, supports start index.
- Practical: WebP output with ImageMagick or sips+cwebp when available.

Typical usage:
  genai_image_gen.py --prompt "Draw a ..." --out-dir out --basename illustration --count 2
  genai_image_gen.py --prompt-file prompt.txt --out-dir static/articles/my-article --basename illustration --model gemini-3.1-flash-image-preview

Notes:
- This script uses Vertex AI (project/location) by default and unsets API keys
  to avoid accidentally using the API-key endpoint.
"""

from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from io import BytesIO
from pathlib import Path

from google import genai
from google.genai.types import GenerateContentConfig, Modality
from PIL import Image


DEFAULT_PROJECT = "gen-lang-client-0910640178"
DEFAULT_LOCATION = "global"
DEFAULT_MODEL = "gemini-3.1-flash-image-preview"  # Nano Banana 2 (per ai.google.dev docs)


@dataclass
class Tooling:
    image_processor: str  # imagemagick|sips|none
    webp_converter: str   # imagemagick|cwebp|none


def check_image_tools() -> Tooling:
    image_processor = "none"
    webp_converter = "none"

    # ImageMagick (preferred)
    try:
        subprocess.run(["magick", "--version"], capture_output=True, check=True)
        image_processor = "imagemagick"
        webp_converter = "imagemagick"
    except (subprocess.CalledProcessError, FileNotFoundError):
        pass

    # sips (macOS)
    if image_processor == "none" and sys.platform == "darwin":
        try:
            subprocess.run(["sips", "--version"], capture_output=True, check=True)
            image_processor = "sips"
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    # cwebp
    if webp_converter == "none":
        try:
            subprocess.run(["cwebp", "-version"], capture_output=True, check=True)
            webp_converter = "cwebp"
        except (subprocess.CalledProcessError, FileNotFoundError):
            pass

    return Tooling(image_processor=image_processor, webp_converter=webp_converter)


def _is_rate_limit_error(exc: Exception) -> bool:
    msg = str(exc).upper()
    return "429" in msg or "RESOURCE_EXHAUSTED" in msg


def call_genai_api(
    *,
    prompt: str,
    model: str,
    backend: str,
    project: str,
    location: str,
    number_of_images: int,
    delay_s: float,
) -> list:
    """Call the GenAI API.

    backend:
      - "vertex": use Vertex AI (project/location)
      - "api": use Gemini API key endpoint (GEMINI_API_KEY/GOOGLE_API_KEY)
      - "auto": prefer API key if present, otherwise Vertex
    """

    api_key = os.environ.get("GEMINI_API_KEY") or os.environ.get("GOOGLE_API_KEY")

    if backend == "auto":
        backend = "api" if api_key else "vertex"

    if backend == "vertex":
        # Avoid accidental API-key usage when Vertex is intended.
        # (We only remove keys for this process; it does not modify any files.)
        os.environ.pop("GOOGLE_API_KEY", None)
        os.environ.pop("GEMINI_API_KEY", None)
        client = genai.Client(project=project, location=location, vertexai=True)
    elif backend == "api":
        if not api_key:
            raise RuntimeError("backend=api requested but neither GEMINI_API_KEY nor GOOGLE_API_KEY is set")
        client = genai.Client(api_key=api_key)
    else:
        raise ValueError(f"Unknown backend: {backend}")

    max_retries = 5
    responses = []

    for i in range(number_of_images):
        if i > 0 and delay_s > 0:
            time.sleep(delay_s)

        for attempt in range(max_retries):
            try:
                resp = client.models.generate_content(
                    model=model,
                    contents=prompt,
                    config=GenerateContentConfig(response_modalities=[Modality.TEXT, Modality.IMAGE]),
                )
                responses.append(resp)
                break
            except Exception as e:
                if _is_rate_limit_error(e) and attempt < max_retries - 1:
                    wait = min(60, (2 ** attempt) * 2)
                    print(f"Rate limited (429). Retry {attempt+1}/{max_retries} in {wait}s...", file=sys.stderr)
                    time.sleep(wait)
                else:
                    raise

    return responses


def extract_images_to_pngs(*, responses: list, out_dir: Path, start_index: int) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)

    raw_paths: list[Path] = []
    for idx, response in enumerate(responses):
        image_index = start_index + idx
        raw_path = out_dir / f"raw_{image_index}.png"

        found = False
        if response.candidates and response.candidates[0].content and response.candidates[0].content.parts:
            for part in response.candidates[0].content.parts:
                if part.inline_data and part.inline_data.data:
                    image = Image.open(BytesIO(part.inline_data.data))
                    image.save(str(raw_path))
                    raw_paths.append(raw_path)
                    found = True
                    break

        if not found:
            raise RuntimeError(f"No image data found in response for index {image_index}")

    return raw_paths


def _convert_one(*, tooling: Tooling, raw_png: Path, out_webp: Path, size: int | None, quality: int) -> None:
    out_webp.parent.mkdir(parents=True, exist_ok=True)

    if tooling.image_processor == "imagemagick":
        cmd = ["magick", str(raw_png)]
        if size is not None:
            cmd += ["-resize", f"{size}x{size}"]
        cmd += ["-quality", str(quality), str(out_webp)]
        subprocess.run(cmd, check=True)
        return

    if tooling.image_processor == "sips":
        # Resize via sips into temp png, then convert with cwebp if available.
        tmp_png = raw_png.with_name(raw_png.stem + "_resized.png")
        shutil.copy2(raw_png, tmp_png)
        if size is not None:
            subprocess.run(["sips", "-z", str(size), str(size), str(tmp_png)], check=True, capture_output=True)

        if tooling.webp_converter == "cwebp":
            subprocess.run(["cwebp", "-q", str(quality), str(tmp_png), "-o", str(out_webp)], check=True)
        elif tooling.webp_converter == "imagemagick":
            subprocess.run(["magick", str(tmp_png), "-quality", str(quality), str(out_webp)], check=True)
        else:
            # fallback: keep png if no webp tools
            shutil.copy2(tmp_png, out_webp.with_suffix(".png"))
        return

    # No tools: keep as png
    shutil.copy2(raw_png, out_webp.with_suffix(".png"))


def convert_pngs_to_outputs(
    *,
    raw_pngs: list[Path],
    out_dir: Path,
    basename: str,
    start_index: int,
    tooling: Tooling,
    size: int | None,
    quality: int,
    keep_raw: bool,
) -> list[Path]:
    outputs: list[Path] = []

    for idx, raw_png in enumerate(raw_pngs):
        image_index = start_index + idx
        out_webp = out_dir / f"{basename}_{image_index}.webp"
        _convert_one(tooling=tooling, raw_png=raw_png, out_webp=out_webp, size=size, quality=quality)

        # If we fell back to png, adjust what we report
        if out_webp.exists():
            outputs.append(out_webp)
        else:
            outputs.append(out_webp.with_suffix(".png"))

    if not keep_raw:
        for p in raw_pngs:
            try:
                p.unlink(missing_ok=True)
            except Exception:
                pass

    return outputs


def read_prompt(args: argparse.Namespace) -> str:
    if args.prompt and args.prompt_file:
        raise SystemExit("Use either --prompt or --prompt-file, not both")

    if args.prompt:
        return args.prompt

    if args.prompt_file:
        return Path(args.prompt_file).read_text(encoding="utf-8")

    raise SystemExit("Missing prompt: provide --prompt or --prompt-file")


def build_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(
        prog="genai_image_gen.py",
        description=(
            "Generate images via Google GenAI (Vertex AI) from a prompt and write them as WebP (preferred).\n\n"
            "Default model is Nano Banana 2: gemini-3.1-flash-image-preview."
        ),
        formatter_class=argparse.RawTextHelpFormatter,
    )

    p.add_argument("--prompt", help="Prompt text to generate the image(s).")
    p.add_argument("--prompt-file", help="Read prompt text from a UTF-8 file.")

    p.add_argument("--out-dir", required=True, help="Output directory for generated images.")
    p.add_argument("--basename", default="image", help="Output base name. Files become <basename>_<index>.webp")
    p.add_argument("--count", type=int, default=1, help="Number of images to generate.")
    p.add_argument("--start-index", type=int, default=1, help="Start index for output numbering.")

    p.add_argument("--model", default=DEFAULT_MODEL, help=f"Model name (default: {DEFAULT_MODEL})")

    p.add_argument(
        "--backend",
        choices=["auto", "vertex", "api"],
        default="auto",
        help=(
            "Which backend to use.\n"
            "  auto: use API key if GEMINI_API_KEY/GOOGLE_API_KEY is set, otherwise Vertex\n"
            "  vertex: force Vertex AI (project/location)\n"
            "  api: force Gemini API key endpoint\n"
            "Default: auto"
        ),
    )

    p.add_argument("--project", default=DEFAULT_PROJECT, help=f"Vertex AI project (default: {DEFAULT_PROJECT})")
    p.add_argument("--location", default=DEFAULT_LOCATION, help=f"Vertex AI location (default: {DEFAULT_LOCATION})")

    p.add_argument("--delay-s", type=float, default=8.0, help="Delay between images to smooth rate limits.")
    p.add_argument("--size", type=int, default=None, help="Optional square resize (e.g. 1024). If omitted, keep model output size.")
    p.add_argument("--quality", type=int, default=90, help="WebP quality (or PNG fallback).")
    p.add_argument("--keep-raw", action="store_true", help="Keep raw_*.png files next to outputs.")

    p.add_argument("--dry-run", action="store_true", help="Print planned actions without calling the API.")

    p.epilog = (
        "Examples:\n"
        "  # 1 image from a prompt\n"
        "  genai_image_gen.py --prompt \"A minimal 3D illustration of ...\" --out-dir out --basename illustration\n\n"
        "  # 2 images, explicit model\n"
        "  genai_image_gen.py --prompt-file prompt.txt --out-dir static/articles/x --basename illustration --count 2 \\\n"
        "    --model gemini-3.1-flash-image-preview\n\n"
        "  # Continue numbering (write illustration_3.webp)\n"
        "  genai_image_gen.py --prompt \"...\" --out-dir static/articles/x --basename illustration --count 1 --start-index 3\n"
    )

    return p


def main() -> None:
    args = build_argparser().parse_args()

    if args.count < 1:
        raise SystemExit("--count must be >= 1")

    prompt = read_prompt(args)
    out_dir = Path(args.out_dir)

    planned = [out_dir / f"{args.basename}_{args.start_index + i}.webp" for i in range(args.count)]
    if args.dry_run:
        print("DRY RUN")
        print(f"Model: {args.model}")
        print(f"Project/Location: {args.project}/{args.location}")
        print(f"Out dir: {out_dir}")
        print(f"Basename: {args.basename}")
        print(f"Count: {args.count} (start-index: {args.start_index})")
        print(f"Planned outputs: {', '.join(str(p) for p in planned)}")
        return

    tooling = check_image_tools()
    if tooling.image_processor == "none":
        print("Warning: no ImageMagick/sips found; outputs may be PNG instead of WebP", file=sys.stderr)
    if tooling.webp_converter == "none":
        print("Warning: no WebP converter found; outputs may be PNG instead of WebP", file=sys.stderr)

    # Use a temp directory inside out_dir for raw images (so we never write into cwd unexpectedly)
    tmp_dir = out_dir / f".genai_tmp_{int(time.time())}"
    tmp_dir.mkdir(parents=True, exist_ok=True)

    try:
        responses = call_genai_api(
            prompt=prompt,
            model=args.model,
            backend=args.backend,
            project=args.project,
            location=args.location,
            number_of_images=args.count,
            delay_s=args.delay_s,
        )

        raw_pngs = extract_images_to_pngs(responses=responses, out_dir=tmp_dir, start_index=args.start_index)
        outputs = convert_pngs_to_outputs(
            raw_pngs=raw_pngs,
            out_dir=out_dir,
            basename=args.basename,
            start_index=args.start_index,
            tooling=tooling,
            size=args.size,
            quality=args.quality,
            keep_raw=args.keep_raw,
        )

        for o in outputs:
            print(o)
    finally:
        # clean tmp dir (safe: this is a unique dir we just created)
        try:
            shutil.rmtree(tmp_dir)
        except Exception:
            pass


if __name__ == "__main__":
    main()
