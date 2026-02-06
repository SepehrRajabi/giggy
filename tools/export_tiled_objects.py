#!/usr/bin/env python3
"""Flatten Tiled exports into a single JSON with points, rectangles, polygons, and images."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, Mapping

DEFAULT_INPUT = Path("tiled/objects.json")
DEFAULT_OUTPUT = Path("resources/json/layers.json")


def translate_point(base_x: float, base_y: float, point: Mapping[str, Any]) -> Dict[str, float]:
    return {"x": base_x + float(point.get("x", 0)), "y": base_y + float(point.get("y", 0))}


def parse_object_entry(
    entry_type: str, obj: Mapping[str, Any], base_x: float, base_y: float
) -> Dict[str, Any]:
    base = {
        "name": obj.get("name", ""),
        "rotation": float(obj.get("rotation", 0)),
    }

    if entry_type == "point":
        return {"position": translate_point(base_x, base_y, {}), **base}

    if entry_type == "rectangle":
        return {
            "position": {"x": base_x, "y": base_y},
            "width": float(obj.get("width", 0)),
            "height": float(obj.get("height", 0)),
            **base,
        }

    if entry_type == "polygon":
        vertices = [
            translate_point(base_x, base_y, vertex) for vertex in obj.get("polygon", [])
        ]
        return {
            "vertices": vertices,
            "closed": bool(obj.get("closed", True)),
            **base,
        }

    return {}


def collect_objects(layers: list[Mapping[str, Any]]) -> Dict[str, list[Dict[str, Any]]]:
    result = {"points": [], "rectangles": [], "polygons": []}
    for layer in layers:
        for obj in layer.get("objects", []):
            base_x = float(obj.get("x", 0))
            base_y = float(obj.get("y", 0))

            if obj.get("point"):
                result["points"].append(parse_object_entry("point", obj, base_x, base_y))
                continue

            if obj.get("polygon"):
                entry = parse_object_entry("polygon", obj, base_x, base_y)
                if len(entry["vertices"]) >= 2:
                    result["polygons"].append(entry)
                continue

            if obj.get("width", 0) != 0 or obj.get("height", 0) != 0:
                result["rectangles"].append(parse_object_entry("rectangle", obj, base_x, base_y))
    return result


def collect_images(layers: list[Mapping[str, Any]]) -> list[Dict[str, Any]]:
    images: list[Dict[str, Any]] = []
    for layer in layers:
        if layer.get("type") != "imagelayer":
            continue
        x = float(layer.get("offsetx", layer.get("x", 0)))
        y = float(layer.get("offsety", layer.get("y", 0)))
        entry = {
            "name": layer.get("name", ""),
            "image": layer.get("image"),
            "position": {"x": x, "y": y},
            "width": float(layer.get("imagewidth", layer.get("width", 0))),
            "height": float(layer.get("imageheight", layer.get("height", 0))),
        }
        for prop in layer.get("properties", []):
            if isinstance(prop, dict) and prop.get("name") == "index":
                entry["index"] = prop.get("value")
                break
        images.append(entry)
    return images


def export_layers(input_path: Path, output_path: Path) -> None:
    document = json.loads(input_path.read_text())
    layers = [layer for layer in document.get("layers", []) if isinstance(layer, dict)]
    objects = [layer for layer in layers if layer.get("type") == "objectgroup"]

    summary = {
        "points": [],
        "rectangles": [],
        "polygons": [],
        "images": [],
    }

    obj_entries = collect_objects(objects)
    summary.update(obj_entries)
    summary["images"] = collect_images(layers)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(summary, indent=2))
    print(f"Wrote {output_path.name}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Produce a single JSON summary of object/image layers from Tiled."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help="Path to Tiled export (default: tiled/objects.json)",
    )
    parser.add_argument(
        "--output",
        type=Path,
        default=DEFAULT_OUTPUT,
        help="Output JSON file (default: resources/json/layers.json)",
    )
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if not args.input.exists():
        raise SystemExit(f"Input file not found: {args.input}")
    export_layers(args.input, args.output)


if __name__ == "__main__":
    main()
