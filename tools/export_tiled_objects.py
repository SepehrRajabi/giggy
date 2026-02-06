#!/usr/bin/env python3
"""Export Tiled object layers into per-layer JSON suitable for the ECS loader."""

from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any, Dict, Iterable, Mapping

DEFAULT_INPUT = Path("tiled/objects.json")
DEFAULT_OUTPUT_DIR = Path("resources/json")


def sanitize_name(raw_name: str) -> str:
    """Produce a filesystem-friendly identifier for each layer."""
    sanitized = re.sub(r"[^\w]+", "_", raw_name.strip())
    sanitized = sanitized.strip("_")
    return sanitized or "layer"


def absolute_point(base_x: float, base_y: float, point: Mapping[str, Any]) -> Dict[str, float]:
    """Return object-space vertex coordinates translated to world space."""
    return {
        "x": base_x + float(point.get("x", 0)),
        "y": base_y + float(point.get("y", 0)),
    }


def extract_layer_data(layer: Mapping[str, Any]) -> Dict[str, Any]:
    """Convert a Tiled layer entry into a simplified structure."""
    layer_name = layer.get("name", "layer")
    objects = layer.get("objects", [])

    data = {
        "name": layer_name,
        "points": [],
        "polygons": [],
    }

    for obj in objects:
        obj_id = obj.get("id")
        obj_name = obj.get("name", "")
        base_x = float(obj.get("x", 0))
        base_y = float(obj.get("y", 0))

        if obj.get("polygon"):
            vertex_list = []
            for vertex in obj.get("polygon", []):
                vertex_list.append(absolute_point(base_x, base_y, vertex))
            if len(vertex_list) >= 2:
                data["polygons"].append(
                    {
                        "name": obj_name,
                        "closed": True,
                        "vertices": vertex_list,
                    }
                )
            continue

        if obj.get("point") or obj.get("height") == 0 and obj.get("width") == 0:
            data["points"].append(
                {
                    "name": obj_name,
                    "position": {"x": base_x, "y": base_y},
                }
            )

    return data


def export_layers(input_path: Path, output_dir: Path) -> None:
    """Read the tiled export and create a filtered JSON file per layer."""
    document = json.loads(input_path.read_text())
    layers = [
        layer
        for layer in document.get("layers", [])
        if isinstance(layer, dict) and layer.get("type") == "objectgroup"
    ]

    output_dir.mkdir(parents=True, exist_ok=True)

    for layer in layers:
        layer_data = extract_layer_data(layer)
        file_name = f"{sanitize_name(layer_data['name'])}.json"
        (output_dir / file_name).write_text(json.dumps(layer_data, indent=2))
        print(f"Wrote {file_name} ({len(layer_data['points'])} points, {len(layer_data['polygons'])} polygons)")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Export Tiled objects.json layers into clean ECS-friendly JSON."
    )
    parser.add_argument(
        "--input",
        type=Path,
        default=DEFAULT_INPUT,
        help="Path to the Tiled objects export (default: tiled/objects.json)",
    )
    parser.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUTPUT_DIR,
        help="Output directory for cleaned JSON per layer (default: resources/json)",
    )
    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    if not args.input.exists():
        raise SystemExit(f"Input file not found: {args.input}")
    export_layers(args.input, args.out)


if __name__ == "__main__":
    main()
