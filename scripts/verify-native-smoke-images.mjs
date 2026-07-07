import { inflateSync } from "node:zlib";
import { readFileSync, statSync } from "node:fs";
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

let failures = 0;

for (const tab of tabs) {
  const imagePath = join(screenshotDir, `${tab}.png`);
  try {
    const fileSize = statSync(imagePath).size;
    const image = parsePng(readFileSync(imagePath));
    const metrics = sampleImage(image);
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

    if (issues.length > 0) {
      failures += 1;
      console.error(`FAIL ${tab}: ${issues.join("; ")}`);
      continue;
    }

    console.log(
      `ok ${tab}: ${image.width}x${image.height}, ` +
        `${metrics.uniqueBuckets} color buckets, ` +
        `luma sd ${metrics.lumaDeviation.toFixed(1)}, ` +
        `avg sat ${metrics.averageSaturation.toFixed(3)}`,
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

  if (bitDepth !== 8 || colorType !== 6) {
    throw new Error(
      `unsupported PNG format bitDepth=${bitDepth} colorType=${colorType}`,
    );
  }

  const inflated = inflateSync(Buffer.concat(idatChunks));
  const bytesPerPixel = 4;
  const stride = width * bytesPerPixel;
  const pixels = Buffer.alloc(width * height * bytesPerPixel);
  let inputOffset = 0;
  let previous = Buffer.alloc(stride);

  for (let y = 0; y < height; y += 1) {
    const filter = inflated[inputOffset];
    inputOffset += 1;
    const current = Buffer.from(
      inflated.subarray(inputOffset, inputOffset + stride),
    );
    inputOffset += stride;

    unfilterScanline(current, previous, filter, bytesPerPixel);
    current.copy(pixels, y * stride);
    previous = current;
  }

  return { width, height, pixels };
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
