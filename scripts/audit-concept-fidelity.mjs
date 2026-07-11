import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { inflateSync } from "node:zlib";

const repoRoot = fileURLToPath(new URL("..", import.meta.url));

const conceptSpecs = {
  capture: {
    actual: "qa-shots/swiftui-native-capture-layout-final.png",
    concept: "docs/card-visuals/capture-holo-unlock.png",
    minimumComposite: 0.765,
    minimumThumbnail: 0.825,
    minimumHistogram: 0.62,
    minimumBand: 0.88,
  },
  binder: {
    actual: "qa-shots/swiftui-native-binder-grid-layout-final.png",
    concept: "docs/card-visuals/binder-rarity-grid.png",
    minimumComposite: 0.8,
    minimumThumbnail: 0.83,
    minimumHistogram: 0.7,
    minimumBand: 0.93,
  },
  friends: {
    actual: "qa-shots/swiftui-native-friends-profile-v16.png",
    concept: "docs/card-visuals/friends-showcase-stack.png",
    minimumComposite: 0.775,
    minimumThumbnail: 0.774,
    minimumHistogram: 0.703,
    minimumBand: 0.907,
  },
};

let failures = 0;

for (const [name, spec] of Object.entries(conceptSpecs)) {
  try {
    assertReadablePng(spec.actual);
    assertReadablePng(spec.concept);

    const actual = parsePng(readFileSync(join(repoRoot, spec.actual)));
    const concept = parsePng(readFileSync(join(repoRoot, spec.concept)));
    const metrics = conceptFidelity(actual, concept);
    const issues = [];

    if (metrics.composite < spec.minimumComposite) {
      issues.push(
        `composite ${format(metrics.composite)} below ${format(spec.minimumComposite)}`,
      );
    }
    if (metrics.thumbnail < spec.minimumThumbnail) {
      issues.push(
        `thumbnail ${format(metrics.thumbnail)} below ${format(spec.minimumThumbnail)}`,
      );
    }
    if (metrics.histogram < spec.minimumHistogram) {
      issues.push(
        `histogram ${format(metrics.histogram)} below ${format(spec.minimumHistogram)}`,
      );
    }
    if (metrics.bands < spec.minimumBand) {
      issues.push(
        `bands ${format(metrics.bands)} below ${format(spec.minimumBand)}`,
      );
    }

    const summary = `${actual.width}x${actual.height} vs ${concept.width}x${concept.height}, ` +
      `composite ${format(metrics.composite)}, thumb ${format(metrics.thumbnail)}, ` +
      `hist ${format(metrics.histogram)}, bands ${format(metrics.bands)}`;

    if (issues.length > 0) {
      failures += 1;
      console.error(`FAIL ${name}: ${summary}; ${issues.join("; ")}`);
      continue;
    }

    console.log(`ok ${name}: ${summary}`);
  } catch (error) {
    failures += 1;
    console.error(
      `FAIL ${name}: ${error instanceof Error ? error.message : String(error)}`,
    );
  }
}

if (failures > 0) {
  console.error(`Concept fidelity audit failed for ${failures} concept pair(s).`);
  process.exit(1);
}

console.log(
  `Concept fidelity audit passed for ${Object.keys(conceptSpecs).length} concept pair(s).`,
);

function assertReadablePng(relativePath) {
  const fullPath = join(repoRoot, relativePath);
  if (!existsSync(fullPath)) {
    throw new Error(`missing ${relativePath}`);
  }

  const { size } = statSync(fullPath);
  if (size < 10000) {
    throw new Error(`${relativePath} is too small at ${size} bytes`);
  }
}

function conceptFidelity(actual, concept) {
  const thumbnail = thumbnailSimilarity(actual, concept);
  const histogram = histogramSimilarity(actual, concept);
  const bands = bandSimilarity(actual, concept);

  return {
    thumbnail,
    histogram,
    bands,
    composite: thumbnail * 0.45 + histogram * 0.35 + bands * 0.2,
  };
}

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

function thumbnailSimilarity(actual, concept) {
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
      const conceptPixel = pixelAtRatio(concept, xRatio, yRatio);
      const redDistance = actualPixel[0] - conceptPixel[0];
      const greenDistance = actualPixel[1] - conceptPixel[1];
      const blueDistance = actualPixel[2] - conceptPixel[2];
      totalDistance += Math.sqrt(
        (redDistance ** 2) + (greenDistance ** 2) + (blueDistance ** 2),
      );
      samples += 1;
    }
  }

  return 1 - totalDistance / samples / maximumDistance;
}

function histogramSimilarity(actual, concept) {
  const actualHistogram = colorHistogram(actual);
  const conceptHistogram = colorHistogram(concept);
  let totalVariation = 0;

  for (let index = 0; index < actualHistogram.length; index += 1) {
    totalVariation += Math.abs(actualHistogram[index] - conceptHistogram[index]);
  }

  return 1 - totalVariation / 2;
}

function colorHistogram(image) {
  const bins = Array(8 * 4 * 4).fill(0);
  const xStep = Math.max(1, Math.floor(image.width / 90));
  const yStep = Math.max(1, Math.floor(image.height / 160));
  let total = 0;

  for (let y = 0; y < image.height; y += yStep) {
    for (let x = 0; x < image.width; x += xStep) {
      const offset = (y * image.width + x) * 4;
      const [hue, saturation, luma] = rgbToHsl(
        image.pixels[offset],
        image.pixels[offset + 1],
        image.pixels[offset + 2],
      );
      const hueBin = Math.min(7, Math.floor(hue * 8));
      const saturationBin = Math.min(3, Math.floor(saturation * 4));
      const lumaBin = Math.min(3, Math.floor(luma * 4));
      bins[(hueBin * 4 + saturationBin) * 4 + lumaBin] += 1;
      total += 1;
    }
  }

  return bins.map((count) => count / total);
}

function bandSimilarity(actual, concept) {
  const actualBands = verticalBands(actual);
  const conceptBands = verticalBands(concept);
  let distance = 0;

  for (let index = 0; index < actualBands.length; index += 1) {
    const actualBand = actualBands[index];
    const conceptBand = conceptBands[index];
    distance += Math.abs(actualBand.saturation - conceptBand.saturation) * 0.55 +
      Math.abs(actualBand.luma - conceptBand.luma) * 0.45;
  }

  return Math.max(0, 1 - distance / actualBands.length);
}

function verticalBands(image) {
  const bands = [];
  const xStep = Math.max(1, Math.floor(image.width / 80));
  const yStep = Math.max(1, Math.floor(image.height / 320));

  for (let bandIndex = 0; bandIndex < 8; bandIndex += 1) {
    const yStart = Math.floor(image.height * bandIndex / 8);
    const yEnd = Math.floor(image.height * (bandIndex + 1) / 8);
    let saturationTotal = 0;
    let lumaTotal = 0;
    let samples = 0;

    for (let y = yStart; y < yEnd; y += yStep) {
      for (let x = 0; x < image.width; x += xStep) {
        const offset = (y * image.width + x) * 4;
        const [, saturation, luma] = rgbToHsl(
          image.pixels[offset],
          image.pixels[offset + 1],
          image.pixels[offset + 2],
        );
        saturationTotal += saturation;
        lumaTotal += luma;
        samples += 1;
      }
    }

    bands.push({
      saturation: saturationTotal / samples,
      luma: lumaTotal / samples,
    });
  }

  return bands;
}

function pixelAtRatio(image, xRatio, yRatio) {
  const x = Math.max(
    0,
    Math.min(image.width - 1, Math.round(xRatio * (image.width - 1))),
  );
  const y = Math.max(
    0,
    Math.min(image.height - 1, Math.round(yRatio * (image.height - 1))),
  );
  const offset = (y * image.width + x) * 4;
  return [
    image.pixels[offset],
    image.pixels[offset + 1],
    image.pixels[offset + 2],
    image.pixels[offset + 3],
  ];
}

function rgbToHsl(redValue, greenValue, blueValue) {
  const red = redValue / 255;
  const green = greenValue / 255;
  const blue = blueValue / 255;
  const max = Math.max(red, green, blue);
  const min = Math.min(red, green, blue);
  let hue = 0;
  let saturation = 0;
  const luma = (max + min) / 2;

  if (max !== min) {
    const delta = max - min;
    saturation = luma > 0.5
      ? delta / (2 - max - min)
      : delta / (max + min);

    if (max === red) {
      hue = (green - blue) / delta + (green < blue ? 6 : 0);
    } else if (max === green) {
      hue = (blue - red) / delta + 2;
    } else {
      hue = (red - green) / delta + 4;
    }

    hue /= 6;
  }

  return [hue, saturation, luma];
}

function format(value) {
  return value.toFixed(3);
}
