#!/usr/bin/env swift
// Trains the Wild Go on-device species classifier with Create ML and writes a
// `WildGoSpeciesClassifier.mlmodel` that the app can compile and bundle.
//
// Create ML ships with the macOS Xcode toolchain, so this runs with:
//   swift ios/ml/train_species_classifier.swift <dataset_dir> [output_dir]
//
// Dataset layout (one subfolder per label, images inside):
//   dataset/
//     blue_jay/*.jpg
//     northern_cardinal/*.jpg
//     eastern_gray_squirrel/*.jpg
//     ...
//
// Label folder names should normalize (underscores/dashes -> spaces, lowercased)
// to a match string in LocalSpeciesCatalog so predictions map onto card metadata.

import CreateML
import Foundation

let arguments = CommandLine.arguments

guard arguments.count >= 2 else {
    FileHandle.standardError.write(Data("""
    Usage: swift train_species_classifier.swift <dataset_dir> [output_dir]

      <dataset_dir>  Folder with one labeled subfolder of images per species.
      [output_dir]   Where to write WildGoSpeciesClassifier.mlmodel (default: cwd).

    """.utf8))
    exit(2)
}

let datasetURL = URL(fileURLWithPath: arguments[1], isDirectory: true)
let outputDirectory = URL(
    fileURLWithPath: arguments.count >= 3 ? arguments[2] : FileManager.default.currentDirectoryPath,
    isDirectory: true
)

var isDirectory: ObjCBool = false
guard FileManager.default.fileExists(atPath: datasetURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
    FileHandle.standardError.write(Data("Dataset directory not found: \(datasetURL.path)\n".utf8))
    exit(1)
}

try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

print("Wild Go species classifier training")
print("  dataset: \(datasetURL.path)")
print("  output:  \(outputDirectory.path)")

do {
    let trainingData = MLImageClassifier.DataSource.labeledDirectories(at: datasetURL)

    // Light augmentation keeps a small urban-nature dataset from overfitting.
    let parameters = MLImageClassifier.ModelParameters(
        validation: .split(strategy: .automatic),
        maxIterations: 25,
        augmentation: [.flip, .rotation, .blur, .exposure],
        algorithm: .transferLearning(
            featureExtractor: .scenePrint(revision: 2),
            classifier: .logisticRegressor
        )
    )

    let classifier = try MLImageClassifier(trainingData: trainingData, parameters: parameters)

    let trainingAccuracy = (1.0 - classifier.trainingMetrics.classificationError) * 100
    let validationAccuracy = (1.0 - classifier.validationMetrics.classificationError) * 100
    print(String(format: "  training accuracy:   %.1f%%", trainingAccuracy))
    print(String(format: "  validation accuracy: %.1f%%", validationAccuracy))

    let metadata = MLModelMetadata(
        author: "Wild Go",
        shortDescription: "Urban nature species classifier for offline Wild Go card identification.",
        version: "1.0"
    )

    let modelURL = outputDirectory.appendingPathComponent("WildGoSpeciesClassifier.mlmodel")
    try classifier.write(to: modelURL, metadata: metadata)
    print("Wrote model: \(modelURL.path)")
} catch {
    FileHandle.standardError.write(Data("Training failed: \(error.localizedDescription)\n".utf8))
    exit(1)
}
