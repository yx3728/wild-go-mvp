#!/usr/bin/env swift

import CoreML
import Foundation
import ImageIO
import Vision

let minimumConfidence: VNConfidence = 0.5

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("Core ML verification failed: \(message)\n".utf8))
    exit(1)
}

let arguments = Array(CommandLine.arguments.dropFirst())
guard arguments.count >= 3, arguments.count.isMultiple(of: 2) == false else {
    fail("usage: verify_species_classifier.swift <model.mlmodelc> <expected-label> <image> [...]")
}

let modelURL = URL(fileURLWithPath: arguments[0])
guard FileManager.default.fileExists(atPath: modelURL.path) else {
    fail("missing compiled model at \(modelURL.path)")
}

var samples: [(expectedLabel: String, imageURL: URL)] = []
for index in stride(from: 1, to: arguments.count, by: 2) {
    samples.append((
        expectedLabel: arguments[index],
        imageURL: URL(fileURLWithPath: arguments[index + 1])
    ))
}

let configuration = MLModelConfiguration()
configuration.computeUnits = .cpuOnly

let model: MLModel
let visionModel: VNCoreMLModel
do {
    model = try MLModel(contentsOf: modelURL, configuration: configuration)
    visionModel = try VNCoreMLModel(for: model)
} catch {
    fail("could not load \(modelURL.lastPathComponent): \(error.localizedDescription)")
}

let modelLabels = Set(model.modelDescription.classLabels?.compactMap { $0 as? String } ?? [])
let expectedLabels = Set(samples.map(\.expectedLabel))
let missingLabels = expectedLabels.subtracting(modelLabels).sorted()
guard missingLabels.isEmpty else {
    fail("model metadata is missing labels: \(missingLabels.joined(separator: ", "))")
}

for sample in samples {
    guard FileManager.default.fileExists(atPath: sample.imageURL.path) else {
        fail("missing verification image at \(sample.imageURL.path)")
    }
    guard let source = CGImageSourceCreateWithURL(sample.imageURL as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("could not decode \(sample.imageURL.lastPathComponent)")
    }

    let request = VNCoreMLRequest(model: visionModel)
    request.imageCropAndScaleOption = .centerCrop

    do {
        try VNImageRequestHandler(cgImage: image).perform([request])
    } catch {
        fail("Vision request failed for \(sample.imageURL.lastPathComponent): \(error.localizedDescription)")
    }

    guard let classification = (request.results as? [VNClassificationObservation])?.first else {
        fail("no classification returned for \(sample.imageURL.lastPathComponent)")
    }
    guard classification.identifier == sample.expectedLabel else {
        fail(
            "\(sample.imageURL.lastPathComponent) predicted \(classification.identifier), " +
            "expected \(sample.expectedLabel)"
        )
    }
    guard classification.confidence >= minimumConfidence else {
        fail(
            "\(sample.imageURL.lastPathComponent) confidence " +
            "\(String(format: "%.4f", classification.confidence)) is below " +
            "\(String(format: "%.2f", minimumConfidence))"
        )
    }

    print(
        "ok \(sample.expectedLabel): \(sample.imageURL.lastPathComponent), " +
        "confidence \(String(format: "%.4f", classification.confidence))"
    )
}

print("Core ML runtime verification passed for \(samples.count) bundled species samples.")
