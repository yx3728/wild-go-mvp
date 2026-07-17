#!/usr/bin/env python3
"""Build the deterministic, Simulator-compatible Wild Go starter classifier."""

from pathlib import Path
import argparse

import coremltools as ct
import numpy as np
from PIL import Image, ImageOps
from coremltools.models import datatypes
from coremltools.models.neural_network import NeuralNetworkBuilder


SAMPLES = (
    ("black_eyed_susan", "binder-flower-gen.png"),
    ("blue_jay", "capture-blue-jay-landscape-gen-v2.png"),
    ("eastern_gray_squirrel", "binder-squirrel-gen.png"),
    ("monarch_butterfly", "binder-butterfly-gen.png"),
    ("northern_cardinal", "binder-cardinal-gen.png"),
    ("rock_pigeon", "binder-pigeon-gen.png"),
    ("turkey_tail", "binder-turkey-tail-gen.png"),
)
IMAGE_SIZE = 360
GRID_SIZE = 12
POOL_SIZE = IMAGE_SIZE // GRID_SIZE
SCORE_SCALE = 0.3


def prototype(image_path: Path) -> np.ndarray:
    image = ImageOps.fit(
        Image.open(image_path).convert("RGB"),
        (IMAGE_SIZE, IMAGE_SIZE),
        method=Image.Resampling.LANCZOS,
    )
    pixels = np.asarray(image, dtype=np.float32) / 255.0
    pooled = pixels.reshape(
        GRID_SIZE,
        POOL_SIZE,
        GRID_SIZE,
        POOL_SIZE,
        3,
    ).mean(axis=(1, 3))
    return np.transpose(pooled, (2, 0, 1)).reshape(-1)


def build(asset_dir: Path, output_path: Path) -> None:
    missing = [name for _, name in SAMPLES if not (asset_dir / name).is_file()]
    if missing:
        raise SystemExit(f"Missing starter images: {', '.join(missing)}")

    prototypes = np.stack([prototype(asset_dir / name) for _, name in SAMPLES])
    labels = [label for label, _ in SAMPLES]

    builder = NeuralNetworkBuilder(
        [("image", datatypes.Array(3, IMAGE_SIZE, IMAGE_SIZE))],
        [("targetProbability", datatypes.Dictionary(str))],
        mode="classifier",
    )
    builder.add_pooling(
        name="average_pool",
        height=POOL_SIZE,
        width=POOL_SIZE,
        stride_height=POOL_SIZE,
        stride_width=POOL_SIZE,
        layer_type="AVERAGE",
        padding_type="VALID",
        input_name="image",
        output_name="pooled",
    )
    builder.add_flatten(
        name="flatten",
        mode=0,
        input_name="pooled",
        output_name="features",
    )

    weights = (2 * SCORE_SCALE * prototypes).astype(np.float32)
    bias = (-SCORE_SCALE * np.sum(prototypes * prototypes, axis=1)).astype(
        np.float32
    )
    builder.add_inner_product(
        name="prototype_scores",
        W=weights,
        b=bias,
        input_channels=prototypes.shape[1],
        output_channels=len(labels),
        has_bias=True,
        input_name="features",
        output_name="scores",
    )
    builder.add_softmax(
        name="probabilities",
        input_name="scores",
        output_name="probabilities",
    )
    builder.set_class_labels(
        labels,
        predicted_feature_name="target",
        prediction_blob="probabilities",
    )
    builder.set_pre_processing_parameters(
        image_input_names=["image"],
        image_scale=1 / 255.0,
        image_format="NCHW",
    )

    spec = builder.spec
    spec.description.metadata.author = "Wild Go"
    spec.description.metadata.shortDescription = (
        "Simulator-compatible urban nature starter classifier."
    )
    spec.description.metadata.versionString = "2.0"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    ct.models.utils.save_spec(spec, str(output_path))
    print(f"Wrote starter model: {output_path}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("asset_dir", type=Path)
    parser.add_argument("output_path", type=Path)
    args = parser.parse_args()
    build(args.asset_dir.resolve(), args.output_path.resolve())


if __name__ == "__main__":
    main()
