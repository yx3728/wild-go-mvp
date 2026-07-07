import { inflateSync } from "node:zlib";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

const repoRoot = new URL("..", import.meta.url).pathname;
const screenshotDir = process.env.WILDGO_VISUAL_DIR ??
  join(repoRoot, "qa-shots/native-smoke");
const tabs = (process.env.WILDGO_VISUAL_TABS ??
  "capture binder profile map explore").split(/\s+/).filter(Boolean);

const minimumBytes = Number(process.env.WILDGO_VISUAL_MIN_BYTES ?? 120000);
const minimumWidth = Number(process.env.WILDGO_VISUAL_MIN_WIDTH ?? 390);
const minimumHeight = Number(process.env.WILDGO_VISUAL_MIN_HEIGHT ?? 800);
const minimumUniqueBuckets = Number(
  process.env.WILDGO_VISUAL_MIN_COLOR_BUCKETS ?? 50,
);
const minimumLumaDeviation = Number(
  process.env.WILDGO_VISUAL_MIN_LUMA_DEVIATION ?? 22,
);
const minimumAverageSaturation = Number(
  process.env.WILDGO_VISUAL_MIN_AVERAGE_SATURATION ?? 0.035,
);
const referenceCheckEnabled = process.env.WILDGO_VISUAL_REFERENCE_CHECK !== "0";
const referenceScoreOverride = process.env.WILDGO_VISUAL_MIN_REFERENCE_SCORE;
const referenceSpecs = {
  capture: {
    path: "qa-shots/swiftui-native-capture-layout-final.png",
    minimumScore: 0.82,
  },
  binder: {
    path: "qa-shots/swiftui-native-binder-grid-layout-final.png",
    minimumScore: 0.9,
  },
  profile: {
    path: "qa-shots/swiftui-native-friends-profile-v16.png",
    minimumScore: 0.9,
  },
  map: {
    path: "qa-shots/tuned-map.png",
    minimumScore: 0.58,
  },
};

let failures = 0;

for (const tab of tabs) {
  const imagePath = join(screenshotDir, `${tab}.png`);
  try {
    const fileSize = statSync(imagePath).size;
    const image = parsePng(readFileSync(imagePath));
    const metrics = sampleImage(image);
    const reference = referenceCheckEnabled
      ? compareAgainstReference(tab, image)
      : undefined;
    const issues = [];

    if (fileSize < minimumBytes) {
      issues.push(`file is only ${fileSize} bytes`);
    }
    if (image.width < minimumWidth || image.height < minimumHeight) {
      issues.push(`dimensions are ${image.width}x${image.height}`);
    }
    if (metrics.opaqueRatio < 0.98) {
      issues.push(`opaque ratio is ${metrics.opaqueRatio.toFixed(3)}`);
    }
    if (metrics.uniqueBuckets < minimumUniqueBuckets) {
      issues.push(`only ${metrics.uniqueBuckets} sampled color buckets`);
    }
    if (metrics.lumaDeviation < minimumLumaDeviation) {
      issues.push(`luma deviation is ${metrics.lumaDeviation.toFixed(1)}`);
    }
    if (metrics.averageSaturation < minimumAverageSaturation) {
      issues.push(
        `average saturation is ${metrics.averageSaturation.toFixed(3)}`,
      );
    }
    if (reference && reference.score < reference.minimumScore) {
      issues.push(
        `reference score ${reference.score.toFixed(3)} below ${
          reference.minimumScore.toFixed(3)
        }`,
      );
    }

    if (issues.length > 0) {
      failures += 1;
      console.error(`FAIL ${tab}: ${issues.join("; ")}`);
      continue;
    }

    console.log(
      `ok ${tab}: ${image.width}x${image.height}, ` +
        `${metrics.uniqueBuckets} color buckets, ` +
        `luma sd ${metrics.lumaDeviation.toFixed(1)}, ` +
        `avg sat ${metrics.averageSaturation.toFixed(3)}` +
        (reference ? `, ref ${reference.score.toFixed(3)}` : ""),
    );
  } catch (error) {
    failures += 1;
    console.error(
      `FAIL ${tab}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

if (failures > 0) {
  console.error(
    `Native smoke visual check failed for ${failures} of ${tabs.length} screenshots.`,
  );
  process.exit(1);
}

console.log(`Native smoke visual check passed for tabs: ${tabs.join(" ")}`);

function parsePng(buffer) {
  const signature = buffer.subarray(0, 8).toString("hex");
  if (signature !== "89504e470d0a1a0a") {
    throw new Error("not a PNG file");
  }

  let offset = 8;
  let width = 0;
  let height = 0;
  let bitDepth = 0;
  let colorType = 0;
  const idatChunks = [];

  while (offset < buffer.length) {
    const length = buffer.readUInt32BE(offset);
    const type = buffer.subarray(offset + 4, offset + 8).toString("ascii");
    const data = buffer.subarray(offset + 8, offset + 8 + length);
    offset += 12 + length;

    if (type === "IHDR") {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      bitDepth = data[8];
      colorType = data[9];
    } else if (type === "IDAT") {
      idatChunks.push(data);
    } else if (type === "IEND") {
      break;
    }
  }

  if (bitDepth !== 8 || ![2, 6].includes(colorType)) {
    throw new Error(
      `unsupported PNG format bitDepth=${bitDepth} colorType=${colorType}`,
    );
  }

  const inflated = inflateSync(Buffer.concat(idatChunks));
  const sourceBytesPerPixel = colorType === 6 ? 4 : 3;
  const sourceStride = width * sourceBytesPerPixel;
  const pixels = Buffer.alloc(width * height * 4);
  let inputOffset = 0;
  let previous = Buffer.alloc(sourceStride);

  for (let y = 0; y < height; y += 1) {
    const filter = inflated[inputOffset];
    inputOffset += 1;
    const current = Buffer.from(
      inflated.subarray(inputOffset, inputOffset + sourceStride),
    );
    inputOffset += sourceStride;

    unfilterScanline(current, previous, filter, sourceBytesPerPixel);
    copyScanlineToRgba(current, pixels, y * width * 4, sourceBytesPerPixel);
    previous = current;
  }

  return { width, height, pixels };
}

function copyScanlineToRgba(source, target, targetOffset, sourceBytesPerPixel) {
  for (let sourceOffset = 0; sourceOffset < source.length; sourceOffset += sourceBytesPerPixel) {
    const targetPixelOffset = targetOffset + (sourceOffset / sourceBytesPerPixel) * 4;
    target[targetPixelOffset] = source[sourceOffset];
    target[targetPixelOffset + 1] = source[sourceOffset + 1];
    target[targetPixelOffset + 2] = source[sourceOffset + 2];
    target[targetPixelOffset + 3] = sourceBytesPerPixel === 4
      ? source[sourceOffset + 3]
      : 255;
  }
}

function unfilterScanline(current, previous, filter, bytesPerPixel) {
  for (let index = 0; index < current.length; index += 1) {
    const left = index >= bytesPerPixel ? current[index - bytesPerPixel] : 0;
    const up = previous[index] ?? 0;
    const upperLeft = index >= bytesPerPixel
      ? previous[index - bytesPerPixel]
      : 0;

    let predictor = 0;
    if (filter === 1) {
      predictor = left;
    } else if (filter === 2) {
      predictor = up;
    } else if (filter === 3) {
      predictor = Math.floor((left + up) / 2);
    } else if (filter === 4) {
      predictor = paeth(left, up, upperLeft);
    } else if (filter !== 0) {
      throw new Error(`unsupported PNG filter ${filter}`);
    }

    current[index] = (current[index] + predictor) & 0xff;
  }
}

function paeth(left, up, upperLeft) {
  const estimate = left + up - upperLeft;
  const leftDistance = Math.abs(estimate - left);
  const upDistance = Math.abs(estimate - up);
  const upperLeftDistance = Math.abs(estimate - upperLeft);
  if (leftDistance <= upDistance && leftDistance <= upperLeftDistance) {
    return left;
  }
  if (upDistance <= upperLeftDistance) return up;
  return upperLeft;
}

function compareAgainstReference(tab, image) {
  const spec = referenceSpecs[tab];
  if (!spec) return undefined;

  const referencePath = join(repoRoot, spec.path);
  if (!existsSync(referencePath)) {
    throw new Error(`reference image missing: ${spec.path}`);
  }

  const reference = parsePng(readFileSync(referencePath));
  return {
    score: thumbnailSimilarity(image, reference),
    minimumScore: Number(referenceScoreOverride ?? spec.minimumScore),
    path: spec.path,
  };
}

function thumbnailSimilarity(actual, reference) {
  const columns = 36;
  const rows = 72;
  let totalDistance = 0;
  let samples = 0;
  const maximumDistance = Math.sqrt((255 ** 2) * 3);

  for (let row = 0; row < rows; row += 1) {
    const yRatio = rows === 1 ? 0 : row / (rows - 1);
    for (let column = 0; column < columns; column += 1) {
      const xRatio = columns === 1 ? 0 : column / (columns - 1);
      const actualPixel = pixelAtRatio(actual, xRatio, yRatio);
      const referencePixel = pixelAtRatio(reference, xRatio, yRatio);
      const redDistance = actualPixel[0] - referencePixel[0];
      const greenDistance = actualPixel[1] - referencePixel[1];
      const blueDistance = actualPixel[2] - referencePixel[2];
      totalDistance += Math.sqrt(
        (redDistance ** 2) + (greenDistance ** 2) + (blueDistance ** 2),
      );
      samples += 1;
    }
  }

  return 1 - ((totalDistance / samples) / maximumDistance);
}

function pixelAtRatio({ width, height, pixels }, xRatio, yRatio) {
  const x = Math.max(0, Math.min(width - 1, Math.round(xRatio * (width - 1))));
  const y = Math.max(0, Math.min(height - 1, Math.round(yRatio * (height - 1))));
  const offset = ((y * width) + x) * 4;
  return [
    pixels[offset],
    pixels[offset + 1],
    pixels[offset + 2],
  ];
}

function sampleImage({ width, height, pixels }) {
  const stepX = Math.max(1, Math.floor(width / 96));
  const stepY = Math.max(1, Math.floor(height / 160));
  const buckets = new Set();
  let count = 0;
  let opaque = 0;
  let saturationTotal = 0;
  let lumaTotal = 0;
  let lumaSquaredTotal = 0;

  for (let y = 0; y < height; y += stepY) {
    for (let x = 0; x < width; x += stepX) {
      const offset = ((y * width) + x) * 4;
      const red = pixels[offset];
      const green = pixels[offset + 1];
      const blue = pixels[offset + 2];
      const alpha = pixels[offset + 3];

      count += 1;
      if (alpha > 245) opaque += 1;

      const luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue);
      lumaTotal += luma;
      lumaSquaredTotal += luma * luma;
      saturationTotal += saturation(red, green, blue);
      buckets.add(`${red >> 4},${green >> 4},${blue >> 4}`);
    }
  }

  const lumaMean = lumaTotal / count;
  const lumaVariance = Math.max(
    0,
    (lumaSquaredTotal / count) - (lumaMean ** 2),
  );

  return {
    opaqueRatio: opaque / count,
    uniqueBuckets: buckets.size,
    lumaDeviation: Math.sqrt(lumaVariance),
    averageSaturation: saturationTotal / count,
  };
}

function saturation(red, green, blue) {
  const max = Math.max(red, green, blue) / 255;
  const min = Math.min(red, green, blue) / 255;
  if (max === 0) return 0;
  return (max - min) / max;
}
