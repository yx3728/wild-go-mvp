import AVFoundation
import CoreML
import CoreLocation
import Foundation
import ImageIO
import MapKit
import PhotosUI
import ShaderKit
import SwiftData
import SwiftUI
import UIKit
import Vision

@main
struct WildGoApp: App {
    var body: some Scene {
        WindowGroup {
            WildGoRootView()
        }
        .modelContainer(for: WildObservation.self)
    }
}

@Model
final class WildObservation: Identifiable {
    @Attribute(.unique) var id: UUID
    var commonName: String
    var latinName: String
    var imageName: String
    var rarity: String
    var finish: String
    var stars: Int
    var confidence: Double
    var locality: String
    var note: String
    var latitude: Double?
    var longitude: Double?
    var createdAt: Date
    var uploadedPath: String?

    init(
        id: UUID = UUID(),
        commonName: String,
        latinName: String,
        imageName: String,
        rarity: String,
        finish: String,
        stars: Int,
        confidence: Double,
        locality: String,
        note: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        createdAt: Date = .now,
        uploadedPath: String? = nil
    ) {
        self.id = id
        self.commonName = commonName
        self.latinName = latinName
        self.imageName = imageName
        self.rarity = rarity
        self.finish = finish
        self.stars = stars
        self.confidence = confidence
        self.locality = locality
        self.note = note
        self.latitude = latitude
        self.longitude = longitude
        self.createdAt = createdAt
        self.uploadedPath = uploadedPath
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum WildGoTab: Hashable {
    case explore
    case map
    case capture
    case binder
    case profile

    var qaName: String {
        switch self {
        case .explore:
            return "explore"
        case .map:
            return "map"
        case .capture:
            return "capture"
        case .binder:
            return "binder"
        case .profile:
            return "profile"
        }
    }
}

extension Array where Element == String {
    var qaSelectedTab: WildGoTab? {
        guard let flagIndex = firstIndex(of: "--wildgo-tab") else { return nil }
        let valueIndex = index(after: flagIndex)
        guard indices.contains(valueIndex) else { return nil }

        switch self[valueIndex] {
        case "explore":
            return .explore
        case "map":
            return .map
        case "capture":
            return .capture
        case "binder":
            return .binder
        case "profile":
            return .profile
        default:
            return nil
        }
    }
}

struct SpeciesIdentificationResult: Codable {
    var commonName: String
    var latinName: String
    var rarity: String
    var finish: String
    var stars: Int
    var confidence: Double
    var note: String
    var storagePath: String?
    var alternativeMatches: [String]?

    var resolvedAlternatives: [String] {
        alternativeMatches ?? []
    }
}

enum RecognitionState {
    case idle
    case loading
    case success(SpeciesIdentificationResult)
    case failure(String)
}

struct InteractionToast: Identifiable, Equatable {
    let id = UUID()
    var message: String
}

enum QAInteractionProbe {
    private static let fileName = "wildgo-qa-events.log"

    private static var arguments: [String] {
        ProcessInfo.processInfo.arguments
    }

    static var isEnabled: Bool {
        arguments.contains("--wildgo-qa-interactions")
    }

    static func prepareForLaunch() {
        if arguments.contains("--wildgo-reset-qa-log") {
            try? FileManager.default.removeItem(at: logURL)
        }
    }

    static func record(_ event: String) {
        guard isEnabled else { return }

        let line = "\(Date().timeIntervalSince1970) \(event)\n"
        let data = Data(line.utf8)
        let directory = logURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: logURL.path),
           let handle = try? FileHandle(forWritingTo: logURL) {
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } catch {
                try? data.write(to: logURL, options: .atomic)
            }
        } else {
            try? data.write(to: logURL, options: .atomic)
        }
    }

    private static var logURL: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }
}

@MainActor
final class WildGoViewModel: ObservableObject {
    @Published var selectedTab: WildGoTab = .explore
    @Published var selectedUIImage: UIImage?
    @Published var selectedImageName: String?
    @Published var recognitionState: RecognitionState = .idle
    @Published var toast: InteractionToast?

    let locationManager = LocationManager()
    private let recognizer = SpeciesRecognitionPipeline()

    init() {
        if let qaSelectedTab = ProcessInfo.processInfo.arguments.qaSelectedTab {
            selectedTab = qaSelectedTab
        }
        QAInteractionProbe.prepareForLaunch()
        QAInteractionProbe.record("launch:\(selectedTab.qaName)")
    }

    func identify(imageData: Data, modelContext: ModelContext, accessToken: String? = nil) async {
        recognitionState = .loading

        do {
            let observationID = UUID()
            let normalizedImageData = Self.normalizedJPEGData(from: imageData)
            let savedImageName = (try? ObservationPhotoStore.saveJPEGData(normalizedImageData)) ?? "capture-blue-jay-landscape-gen-v2.png"
            selectedImageName = savedImageName
            let coordinate = locationManager.currentCoordinate
            let result = try await recognizer.identify(
                imageData: normalizedImageData,
                coordinate: coordinate,
                accessToken: accessToken,
                observationID: observationID
            )
            let guide = SpeciesFieldGuide.entry(
                forCommonName: result.commonName,
                latinName: result.latinName,
                stars: result.stars
            )
            let observation = WildObservation(
                id: observationID,
                commonName: result.commonName,
                latinName: result.latinName,
                imageName: savedImageName,
                rarity: result.rarity,
                finish: result.finish,
                stars: result.stars,
                confidence: result.confidence,
                locality: PrivacyLocationPolicy.displayLocality(
                    for: WildObservation(
                        commonName: result.commonName,
                        latinName: result.latinName,
                        imageName: savedImageName,
                        rarity: result.rarity,
                        finish: result.finish,
                        stars: result.stars,
                        confidence: result.confidence,
                        locality: "Approx location",
                        note: result.note,
                        latitude: coordinate?.latitude,
                        longitude: coordinate?.longitude
                    )
                ),
                note: result.note,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                uploadedPath: result.storagePath
            )
            modelContext.insert(observation)
            try? modelContext.save()
            recognitionState = .success(
                SpeciesIdentificationResult(
                    commonName: result.commonName,
                    latinName: result.latinName,
                    rarity: result.rarity,
                    finish: result.finish,
                    stars: result.stars,
                    confidence: result.confidence,
                    note: result.note,
                    storagePath: result.storagePath,
                    alternativeMatches: result.resolvedAlternatives.isEmpty
                        ? guide.alternativeMatches
                        : result.resolvedAlternatives
                )
            )
        } catch {
            recognitionState = .failure(error.localizedDescription)
        }
    }

    func showToast(_ message: String) {
        QAInteractionProbe.record("toast:\(message)")
        let nextToast = InteractionToast(message: message)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            toast = nextToast
        }

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            await MainActor.run {
                guard self?.toast?.id == nextToast.id else { return }
                withAnimation(.easeOut(duration: 0.18)) {
                    self?.toast = nil
                }
            }
        }
    }

    private static func normalizedJPEGData(from imageData: Data) -> Data {
        guard let image = UIImage(data: imageData),
              let jpegData = image.jpegData(compressionQuality: 0.88) else {
            return imageData
        }

        return jpegData
    }
}

enum ObservationPhotoStore {
    private static let referencePrefix = "wildgo-local://"

    static func saveImageData(_ data: Data) throws -> String {
        guard let image = UIImage(data: data),
              let jpegData = image.jpegData(compressionQuality: 0.88) else {
            return try saveJPEGData(data)
        }

        return try saveJPEGData(jpegData)
    }

    static func saveJPEGData(_ data: Data) throws -> String {
        let directory = try observationDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let filename = "\(UUID().uuidString.lowercased()).jpg"
        let url = directory.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic])
        return referencePrefix + filename
    }

    static func image(named reference: String) -> UIImage? {
        guard let url = localURL(for: reference) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func data(named reference: String) -> Data? {
        guard let url = localURL(for: reference) else { return nil }
        return try? Data(contentsOf: url)
    }

    private static func localURL(for reference: String) -> URL? {
        guard reference.hasPrefix(referencePrefix) else { return nil }
        let rawFilename = String(reference.dropFirst(referencePrefix.count))
        let filename = URL(fileURLWithPath: rawFilename).lastPathComponent
        guard !filename.isEmpty else { return nil }

        return try? observationDirectory().appendingPathComponent(filename)
    }

    private static func observationDirectory() throws -> URL {
        try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("ObservationPhotos", isDirectory: true)
    }
}

final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var currentCoordinate: CLLocationCoordinate2D?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func requestLocation() {
        if authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        manager.requestLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.currentCoordinate = locations.last?.coordinate
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.currentCoordinate = self.currentCoordinate ?? CLLocationCoordinate2D(latitude: 40.6602, longitude: -73.9690)
        }
    }
}

final class CameraSession: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var isAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    @Published var isCaptureReady = false

    private let photoOutput = AVCapturePhotoOutput()
    private var captureContinuation: CheckedContinuation<Data, Error>?
    private var hasReadyPhotoConnection: Bool {
        guard session.isRunning,
              session.outputs.contains(photoOutput),
              let connection = photoOutput.connection(with: .video) else {
            return false
        }

        return connection.isEnabled && connection.isActive
    }

    func start() {
        // No capture hardware on Simulator; capture falls back to the demo card.
        guard !Self.isSimulator else {
            isCaptureReady = false
            return
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            configureAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    self.isAuthorized = granted
                    if granted {
                        self.configureAndStart()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    func stop() {
        guard session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.stopRunning()
        }
    }

    private func configureAndStart() {
        if session.isRunning {
            isCaptureReady = hasReadyPhotoConnection
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        if session.inputs.isEmpty,
           let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        if !session.outputs.contains(photoOutput),
           session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            photoOutput.maxPhotoQualityPrioritization = .quality
        }

        session.commitConfiguration()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isCaptureReady = self.hasReadyPhotoConnection
            }
        }
    }

    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    func capturePhotoData() async throws -> Data {
        // The Simulator has no capture hardware; fail fast so the demo fallback runs.
        guard !Self.isSimulator else { throw WildGoError.cameraUnavailable }
        guard isAuthorized else { throw WildGoError.cameraUnavailable }

        if !session.isRunning || !session.outputs.contains(photoOutput) {
            configureAndStart()
        }

        // `startRunning()` runs on a background queue, so the connection may not be
        // ready on the first tap right after the view appears. Poll briefly before
        // giving up and letting the caller fall back.
        if !(await waitForReadyPhotoConnection()) {
            throw WildGoError.cameraUnavailable
        }

        // Guard against an in-flight capture (e.g. rapid double taps).
        guard captureContinuation == nil else {
            throw WildGoError.cameraCaptureFailed
        }

        return try await withCheckedThrowingContinuation { continuation in
            captureContinuation = continuation

            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func waitForReadyPhotoConnection(
        timeout: TimeInterval = 1.5,
        pollInterval: UInt64 = 100_000_000
    ) async -> Bool {
        if hasReadyPhotoConnection { return true }

        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            try? await Task.sleep(nanoseconds: pollInterval)
            if hasReadyPhotoConnection { return true }
        }

        return hasReadyPhotoConnection
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            captureContinuation?.resume(throwing: error)
            captureContinuation = nil
            return
        }

        guard let data = photo.fileDataRepresentation() else {
            captureContinuation?.resume(throwing: WildGoError.cameraCaptureFailed)
            captureContinuation = nil
            return
        }

        captureContinuation?.resume(returning: data)
        captureContinuation = nil
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        uiView.previewLayer.session = session
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}

struct SupabaseConfiguration {
    static var projectURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String else { return nil }
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return URL(string: value)
    }

    static var anonKey: String? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String else { return nil }
        guard !value.isEmpty, !value.hasPrefix("$(") else { return nil }
        return value
    }

    static func edgeFunctionURL(_ name: String) -> URL? {
        projectURL?.appending(path: "functions/v1/\(name)")
    }
}

protocol SpeciesRecognizing {
    func identify(
        imageData: Data,
        coordinate: CLLocationCoordinate2D?,
        accessToken: String?,
        observationID: UUID
    ) async throws -> SpeciesIdentificationResult
}

struct SpeciesRecognitionPipeline: SpeciesRecognizing {
    private let cloud = CloudSpeciesRecognizer()
    private let local = LocalSpeciesRecognizer()

    func identify(
        imageData: Data,
        coordinate: CLLocationCoordinate2D?,
        accessToken: String? = nil,
        observationID: UUID = UUID()
    ) async throws -> SpeciesIdentificationResult {
        do {
            return try await cloud.identify(
                imageData: imageData,
                coordinate: coordinate,
                accessToken: accessToken,
                observationID: observationID
            )
        } catch {
            if let localResult = try? await local.identify(
                imageData: imageData,
                coordinate: coordinate,
                accessToken: accessToken,
                observationID: observationID
            ) {
                return localResult
            }

            if case WildGoError.missingSupabaseConfiguration = error {
                return .sample
            }

            throw error
        }
    }
}

struct CloudSpeciesRecognizer {
    func identify(
        imageData: Data,
        coordinate: CLLocationCoordinate2D?,
        accessToken: String? = nil,
        observationID: UUID = UUID()
    ) async throws -> SpeciesIdentificationResult {
        guard let functionURL = SupabaseConfiguration.edgeFunctionURL("identify-species"),
              let anonKey = SupabaseConfiguration.anonKey else {
            throw WildGoError.missingSupabaseConfiguration
        }

        var request = URLRequest(url: functionURL)
        request.httpMethod = "POST"
        if let accessToken, !accessToken.isEmpty {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        } else {
            request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        }
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(IdentifySpeciesRequest(
            imageBase64: imageData.base64EncodedString(),
            imageMimeType: "image/jpeg",
            clientId: DeviceIdentity.clientId,
            observationId: observationID.uuidString.lowercased(),
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude,
            capturedAt: ISO8601DateFormatter().string(from: Date())
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            throw WildGoError.identificationFailed
        }

        return try JSONDecoder().decode(SpeciesIdentificationResult.self, from: data)
    }
}

struct LocalSpeciesRecognizer: SpeciesRecognizing {
    func identify(
        imageData: Data,
        coordinate: CLLocationCoordinate2D?,
        accessToken: String? = nil,
        observationID: UUID = UUID()
    ) async throws -> SpeciesIdentificationResult {
        guard let image = UIImage(data: imageData),
              let cgImage = image.cgImage else {
            throw WildGoError.localRecognitionUnavailable
        }

        guard let modelURL = Self.bundledModelURL() else {
            throw WildGoError.localRecognitionUnavailable
        }

        let mlModel = try MLModel(contentsOf: modelURL, configuration: MLModelConfiguration())
        let visionModel = try VNCoreMLModel(for: mlModel)
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = .centerCrop

        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            orientation: CGImagePropertyOrientation(image.imageOrientation),
            options: [:]
        )
        try requestHandler.perform([request])

        guard let topClassification = (request.results as? [VNClassificationObservation])?.first else {
            throw WildGoError.localRecognitionUnavailable
        }

        return LocalSpeciesCatalog.result(
            for: topClassification.identifier,
            confidence: Double(topClassification.confidence)
        )
    }

    private static func bundledModelURL() -> URL? {
        if let namedURL = Bundle.main.url(forResource: "WildGoSpeciesClassifier", withExtension: "mlmodelc") {
            return namedURL
        }

        // Models dropped into the bundled GeneratedAssets folder (see ios/ml/build-model.sh).
        if let generatedURL = Bundle.main.url(
            forResource: "WildGoSpeciesClassifier",
            withExtension: "mlmodelc",
            subdirectory: "GeneratedAssets"
        ) {
            return generatedURL
        }

        if let topLevelModel = Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: nil)?.first {
            return topLevelModel
        }

        return Bundle.main.urls(forResourcesWithExtension: "mlmodelc", subdirectory: "GeneratedAssets")?.first
    }
}

enum LocalSpeciesCatalog {
    static func result(for identifier: String, confidence: Double) -> SpeciesIdentificationResult {
        let normalizedIdentifier = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .lowercased()
        let clampedConfidence = min(max(confidence, 0.05), 0.99)

        if let known = knownSpecies.first(where: { species in
            species.matches.contains { normalizedIdentifier.contains($0) }
        }) {
            return SpeciesIdentificationResult(
                commonName: known.commonName,
                latinName: known.latinName,
                rarity: known.rarity,
                finish: known.finish,
                stars: known.stars,
                confidence: clampedConfidence,
                note: known.note,
                storagePath: nil
            )
        }

        let displayName = identifier
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { word in word.prefix(1).uppercased() + word.dropFirst().lowercased() }
            .joined(separator: " ")

        return SpeciesIdentificationResult(
            commonName: displayName.isEmpty ? "Urban Nature Find" : displayName,
            latinName: "Local classifier match",
            rarity: "Common",
            finish: "Matte",
            stars: 1,
            confidence: clampedConfidence,
            note: "Classified locally on device with the bundled Vision/Core ML model.",
            storagePath: nil
        )
    }

    private struct SpeciesTemplate {
        var matches: [String]
        var commonName: String
        var latinName: String
        var rarity: String
        var finish: String
        var stars: Int
        var note: String
    }

    private static let knownSpecies: [SpeciesTemplate] = [
        SpeciesTemplate(
            matches: ["blue jay", "cyanocitta cristata"],
            commonName: "Blue Jay",
            latinName: "Cyanocitta cristata",
            rarity: "City Legend",
            finish: "Holo Foil",
            stars: 6,
            note: "Classified locally as a bold city bird often found near mature trees."
        ),
        SpeciesTemplate(
            matches: ["northern cardinal", "cardinalis cardinalis"],
            commonName: "Northern Cardinal",
            latinName: "Cardinalis cardinalis",
            rarity: "City Legend",
            finish: "Holo Foil",
            stars: 6,
            note: "Classified locally as a bright neighborhood trophy card."
        ),
        SpeciesTemplate(
            matches: ["eastern gray squirrel", "grey squirrel", "sciurus carolinensis", "squirrel"],
            commonName: "Eastern Gray Squirrel",
            latinName: "Sciurus carolinensis",
            rarity: "Rare",
            finish: "Metallic",
            stars: 3,
            note: "Classified locally as a quick park regular around old trees and fence lines."
        ),
        SpeciesTemplate(
            matches: ["black eyed susan", "rudbeckia hirta", "oxeye daisy", "daisy", "flower"],
            commonName: "Black-eyed Susan",
            latinName: "Rudbeckia hirta",
            rarity: "Uncommon",
            finish: "Colored Edge",
            stars: 2,
            note: "Classified locally as a sunny urban garden find."
        ),
        SpeciesTemplate(
            matches: ["rock pigeon", "columba livia", "pigeon"],
            commonName: "Rock Pigeon",
            latinName: "Columba livia",
            rarity: "Common",
            finish: "Matte",
            stars: 1,
            note: "Classified locally as an everyday city bird with surprising variation."
        ),
        SpeciesTemplate(
            matches: ["monarch butterfly", "danaus plexippus", "butterfly"],
            commonName: "Monarch Butterfly",
            latinName: "Danaus plexippus",
            rarity: "Seasonal",
            finish: "Iridescent",
            stars: 4,
            note: "Classified locally as a seasonal pollinator highlight."
        ),
        SpeciesTemplate(
            matches: ["turkey tail", "trametes versicolor", "mushroom", "fungus"],
            commonName: "Turkey Tail",
            latinName: "Trametes versicolor",
            rarity: "Local Special",
            finish: "Foil",
            stars: 5,
            note: "Classified locally as a local special best logged respectfully."
        )
    ]
}

struct IdentifySpeciesRequest: Encodable {
    var imageBase64: String
    var imageMimeType: String
    var clientId: String
    var observationId: String
    var latitude: Double?
    var longitude: Double?
    var capturedAt: String
}

enum DeviceIdentity {
    private static let key = "wild-go-client-id"

    static var clientId: String {
        let defaults = UserDefaults.standard
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return existing
        }

        let created = UUID().uuidString.lowercased()
        defaults.set(created, forKey: key)
        return created
    }
}

struct SpeciesFieldGuideEntry {
    var habitat: String
    var seasonality: String
    var safetyGuidance: String
    var alternativeMatches: [String]
    var isSensitive: Bool
}

enum SpeciesFieldGuide {
    static func entry(for observation: WildObservation) -> SpeciesFieldGuideEntry {
        entry(forCommonName: observation.commonName, latinName: observation.latinName, stars: observation.stars)
    }

    static func entry(forCommonName commonName: String, latinName: String, stars: Int) -> SpeciesFieldGuideEntry {
        let normalized = commonName.lowercased()
        if let known = catalog.first(where: { entry in
            entry.matches.contains { normalized.contains($0) }
        }) {
            return SpeciesFieldGuideEntry(
                habitat: known.habitat,
                seasonality: known.seasonality,
                safetyGuidance: known.safetyGuidance,
                alternativeMatches: known.alternativeMatches,
                isSensitive: known.isSensitive || stars >= 5
            )
        }

        return SpeciesFieldGuideEntry(
            habitat: "Nearby urban habitat",
            seasonality: stars >= 4 ? "Seasonal highlight" : "Year-round urban resident",
            safetyGuidance: "Observe, photograph, and leave space.",
            alternativeMatches: ["Check lighting and angle", "Compare leaf or feather detail"],
            isSensitive: stars >= 5
        )
    }

    private struct Template {
        var matches: [String]
        var habitat: String
        var seasonality: String
        var safetyGuidance: String
        var alternativeMatches: [String]
        var isSensitive: Bool
    }

    private static let catalog: [Template] = [
        Template(
            matches: ["blue jay"],
            habitat: "Mature street trees, railings, city parks",
            seasonality: "Year-round; loudest on cool mornings",
            safetyGuidance: "Keep distance from active nests and feeding fledglings.",
            alternativeMatches: ["Steller's Jay", "Blue Grosbeak"],
            isSensitive: false
        ),
        Template(
            matches: ["cardinal"],
            habitat: "Shrubs, gardens, backyard edges",
            seasonality: "Year-round resident; brightest in winter",
            safetyGuidance: "Avoid playback calls near nesting pairs.",
            alternativeMatches: ["Summer Tanager", "House Finch"],
            isSensitive: false
        ),
        Template(
            matches: ["squirrel"],
            habitat: "Old trees, fence lines, park lawns",
            seasonality: "Active year-round; busiest at dawn",
            safetyGuidance: "Do not feed or corner animals for a closer photo.",
            alternativeMatches: ["Eastern Chipmunk", "Red Squirrel"],
            isSensitive: false
        ),
        Template(
            matches: ["susan", "daisy", "flower"],
            habitat: "Sunny garden beds, medians, meadow edges",
            seasonality: "Peak bloom mid-summer through early fall",
            safetyGuidance: "Photograph without picking or trampling plantings.",
            alternativeMatches: ["Oxeye Daisy", "Black-eyed Susan"],
            isSensitive: false
        ),
        Template(
            matches: ["pigeon"],
            habitat: "Rooftops, bridges, plaza ledges",
            seasonality: "Year-round city regular",
            safetyGuidance: "Avoid disturbing roosting groups in tight spaces.",
            alternativeMatches: ["Mourning Dove", "Eurasian Collared-Dove"],
            isSensitive: false
        ),
        Template(
            matches: ["monarch", "butterfly"],
            habitat: "Milkweed patches, sunny garden edges",
            seasonality: "Late summer migration window",
            safetyGuidance: "Do not net or handle; sensitive pollinator species.",
            alternativeMatches: ["Viceroy", "Gulf Fritillary"],
            isSensitive: true
        ),
        Template(
            matches: ["turkey tail", "mushroom", "fungus"],
            habitat: "Decaying logs, shaded tree bases",
            seasonality: "Cool, damp weeks in fall and spring",
            safetyGuidance: "Never harvest or taste wild fungi from a photo ID.",
            alternativeMatches: ["False Turkey Tail", "Trametes hirsuta"],
            isSensitive: true
        )
    ]
}

enum PrivacyLocationPolicy {
    static func isSensitiveSpecies(_ observation: WildObservation) -> Bool {
        SpeciesFieldGuide.entry(for: observation).isSensitive || observation.stars >= 5
    }

    static func displayLocality(for observation: WildObservation) -> String {
        if isSensitiveSpecies(observation) {
            return "Softened neighborhood"
        }
        return observation.locality.isEmpty ? "Approx location" : observation.locality
    }

    static func softenedCoordinate(for observation: WildObservation) -> CLLocationCoordinate2D? {
        guard let latitude = observation.latitude, let longitude = observation.longitude else {
            return nil
        }

        guard isSensitiveSpecies(observation) else {
            return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        }

        let seed = observation.id.uuidString.utf8.reduce(0) { partial, byte in
            partial &+ Int(byte)
        }
        let angle = Double(seed % 360) * .pi / 180
        let distance = 0.012 + Double(seed % 7) * 0.0018
        return CLLocationCoordinate2D(
            latitude: latitude + cos(angle) * distance,
            longitude: longitude + sin(angle) * distance
        )
    }
}

struct SupabaseSession: Codable {
    var accessToken: String
    var refreshToken: String
    var userId: UUID
    var email: String
    var expiresAt: Date?

    func needsRefresh(leeway: TimeInterval = 120) -> Bool {
        guard let expiresAt else { return true }
        return expiresAt <= Date().addingTimeInterval(leeway)
    }
}

@MainActor
final class SupabaseAuthService: ObservableObject {
    @Published private(set) var session: SupabaseSession?
    @Published var isBusy = false
    @Published var statusMessage: String?

    private let storageKey = "wild-go-supabase-session"

    init() {
        restoreSession()
    }

    var isSignedIn: Bool { session != nil }
    var accessToken: String? { session?.accessToken }

    func validAccessToken(leeway: TimeInterval = 120) async throws -> String {
        guard let currentSession = session else {
            throw WildGoError.authFailed("Sign in again to sync your binder.")
        }

        guard currentSession.needsRefresh(leeway: leeway) else {
            return currentSession.accessToken
        }

        return try await refreshSession()
    }

    func validSession(leeway: TimeInterval = 120) async throws -> SupabaseSession {
        _ = try await validAccessToken(leeway: leeway)
        guard let session else {
            throw WildGoError.authFailed("Sign in again to sync your binder.")
        }
        return session
    }

    func restoreSession() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let restored = try? JSONDecoder().decode(SupabaseSession.self, from: data) else {
            return
        }
        session = restored
    }

    func signIn(email: String, password: String) async throws {
        try await authenticate(email: email, password: password, grantType: "password")
    }

    func signUp(email: String, password: String) async throws {
        guard let projectURL = SupabaseConfiguration.projectURL,
              let anonKey = SupabaseConfiguration.anonKey else {
            throw WildGoError.missingSupabaseConfiguration
        }

        isBusy = true
        defer { isBusy = false }

        var request = URLRequest(url: projectURL.appending(path: "auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            throw WildGoError.authFailed(Self.errorMessage(from: data))
        }

        if let tokenResponse = try? JSONDecoder().decode(SupabaseTokenResponse.self, from: data),
           let nextSession = Self.session(from: tokenResponse) {
            persistSession(nextSession)
            statusMessage = "Account created"
            return
        }

        statusMessage = "Check your email to confirm, then sign in."
    }

    func signOut() {
        session = nil
        UserDefaults.standard.removeObject(forKey: storageKey)
        statusMessage = "Signed out"
    }

    private func authenticate(email: String, password: String, grantType: String) async throws {
        guard let projectURL = SupabaseConfiguration.projectURL,
              let anonKey = SupabaseConfiguration.anonKey else {
            throw WildGoError.missingSupabaseConfiguration
        }

        isBusy = true
        defer { isBusy = false }

        var components = URLComponents(url: projectURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: grantType)]

        var request = URLRequest(url: components?.url ?? projectURL.appending(path: "auth/v1/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode([
            "email": email,
            "password": password
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            throw WildGoError.authFailed(Self.errorMessage(from: data))
        }

        let tokenResponse = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
        guard let nextSession = Self.session(from: tokenResponse) else {
            throw WildGoError.authFailed("Supabase did not return a session.")
        }

        persistSession(nextSession)
        statusMessage = "Signed in as \(nextSession.email)"
    }

    private func refreshSession() async throws -> String {
        guard let currentSession = session else {
            throw WildGoError.authFailed("Sign in again to sync your binder.")
        }
        guard let projectURL = SupabaseConfiguration.projectURL,
              let anonKey = SupabaseConfiguration.anonKey else {
            throw WildGoError.missingSupabaseConfiguration
        }

        isBusy = true
        defer { isBusy = false }

        var components = URLComponents(url: projectURL.appending(path: "auth/v1/token"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]

        var request = URLRequest(url: components?.url ?? projectURL.appending(path: "auth/v1/token"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode([
            "refresh_token": currentSession.refreshToken
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            signOut()
            throw WildGoError.authFailed(Self.errorMessage(from: data))
        }

        let tokenResponse = try JSONDecoder().decode(SupabaseTokenResponse.self, from: data)
        guard let refreshedSession = Self.session(from: tokenResponse, fallback: currentSession) else {
            throw WildGoError.authFailed("Supabase did not refresh the session.")
        }

        persistSession(refreshedSession)
        return refreshedSession.accessToken
    }

    private func persistSession(_ nextSession: SupabaseSession) {
        session = nextSession
        if let data = try? JSONEncoder().encode(nextSession) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private static func errorMessage(from data: Data) -> String {
        if let payload = try? JSONDecoder().decode(SupabaseErrorResponse.self, from: data) {
            return payload.errorDescription ?? payload.msg ?? payload.message ?? "Authentication failed."
        }
        return "Authentication failed."
    }

    private static func session(from tokenResponse: SupabaseTokenResponse, fallback: SupabaseSession? = nil) -> SupabaseSession? {
        guard let accessToken = tokenResponse.accessToken,
              let refreshToken = tokenResponse.refreshToken else {
            return nil
        }

        let userId = tokenResponse.user?.id ?? fallback?.userId
        let email = tokenResponse.user?.email ?? fallback?.email
        guard let userId, let email else { return nil }

        return SupabaseSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userId: userId,
            email: email,
            expiresAt: expirationDate(from: tokenResponse) ?? fallback?.expiresAt
        )
    }

    private static func expirationDate(from tokenResponse: SupabaseTokenResponse) -> Date? {
        if let expiresAt = tokenResponse.expiresAt {
            return Date(timeIntervalSince1970: expiresAt)
        }
        if let expiresIn = tokenResponse.expiresIn {
            return Date().addingTimeInterval(expiresIn)
        }
        return nil
    }
}

struct SupabaseTokenResponse: Decodable {
    var accessToken: String?
    var refreshToken: String?
    var expiresIn: TimeInterval?
    var expiresAt: TimeInterval?
    var user: SupabaseAuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

struct SupabaseAuthUser: Decodable {
    var id: UUID
    var email: String?
}

struct SupabaseErrorResponse: Decodable {
    var msg: String?
    var message: String?
    var errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case msg
        case message
        case errorDescription = "error_description"
    }
}

enum CollectionSyncService {
    struct Summary {
        var pushed: Int = 0
        var pulled: Int = 0
        var updated: Int = 0

        var changedCount: Int {
            pushed + pulled + updated
        }

        var toastMessage: String {
            if pushed > 0 && pulled > 0 {
                return "Synced \(pushed) up, \(pulled) down"
            }
            if pulled > 0 {
                return "Pulled \(pulled) cards from your account"
            }
            if pushed > 0 {
                return "Synced \(pushed) cards to your account"
            }
            if updated > 0 {
                return "Updated \(updated) cloud cards"
            }
            return "Collection already synced"
        }
    }

    @MainActor
    static func syncCollection(_ observations: [WildObservation], modelContext: ModelContext, session: SupabaseSession) async -> Summary {
        let pushed = await pushUnsyncedObservations(observations, session: session)
        let pullSummary = await pullRemoteObservations(existing: observations, modelContext: modelContext, session: session)

        if pushed > 0 || pullSummary.pulled > 0 || pullSummary.updated > 0 {
            try? modelContext.save()
        }

        return Summary(pushed: pushed, pulled: pullSummary.pulled, updated: pullSummary.updated)
    }

    @MainActor
    private static func pushUnsyncedObservations(_ observations: [WildObservation], session: SupabaseSession) async -> Int {
        guard let projectURL = SupabaseConfiguration.projectURL,
              let anonKey = SupabaseConfiguration.anonKey else {
            return 0
        }

        var syncedCount = 0
        for observation in observations where needsAuthenticatedUpload(observation) {
            let pendingStoragePath = await uploadLocalObservationImage(observation, session: session)

            var components = URLComponents(url: projectURL.appending(path: "rest/v1/observations"), resolvingAgainstBaseURL: false)
            components?.queryItems = [URLQueryItem(name: "on_conflict", value: "id")]

            var request = URLRequest(url: components?.url ?? projectURL.appending(path: "rest/v1/observations"))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue(anonKey, forHTTPHeaderField: "apikey")
            request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("resolution=merge-duplicates,return=minimal", forHTTPHeaderField: "Prefer")

            let payload: [String: Any?] = [
                "id": observation.id.uuidString,
                "user_id": session.userId.uuidString,
                "client_id": DeviceIdentity.clientId,
                "common_name": observation.commonName,
                "latin_name": observation.latinName,
                "rarity": observation.rarity,
                "finish": observation.finish,
                "stars": observation.stars,
                "confidence": observation.confidence,
                "locality": PrivacyLocationPolicy.displayLocality(for: observation),
                "note": observation.note,
                "latitude": observation.latitude,
                "longitude": observation.longitude,
                "image_path": pendingStoragePath,
                "source": "cloud_api",
                "captured_at": ISO8601DateFormatter().string(from: observation.createdAt)
            ]

            request.httpBody = try? JSONSerialization.data(withJSONObject: payload.compactMapValues { $0 })
            if let (_, response) = try? await URLSession.shared.data(for: request),
               (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 {
                observation.uploadedPath = pendingStoragePath
                syncedCount += 1
            }
        }

        return syncedCount
    }

    @MainActor
    private static func pullRemoteObservations(existing observations: [WildObservation], modelContext: ModelContext, session: SupabaseSession) async -> Summary {
        guard let rows = await remoteObservationRows(session: session) else {
            return Summary()
        }

        var localById = Dictionary(uniqueKeysWithValues: observations.map { ($0.id, $0) })
        var localByUploadedPath: [String: WildObservation] = [:]
        for observation in observations {
            if let uploadedPath = observation.uploadedPath {
                localByUploadedPath[uploadedPath] = observation
            }
        }

        var importedCount = 0
        var updatedCount = 0

        for row in rows {
            let matchedObservation = localById[row.id] ?? row.imagePath.flatMap { localByUploadedPath[$0] }
            if let matchedObservation {
                if await apply(row, to: matchedObservation, session: session) {
                    updatedCount += 1
                }
                localById[matchedObservation.id] = matchedObservation
                if let uploadedPath = matchedObservation.uploadedPath {
                    localByUploadedPath[uploadedPath] = matchedObservation
                }
                continue
            }

            let imageName = await localImageReference(for: row, session: session)
            let observation = WildObservation(
                id: row.id,
                commonName: row.commonName,
                latinName: row.latinName,
                imageName: imageName,
                rarity: row.rarity,
                finish: row.finish,
                stars: row.stars,
                confidence: row.confidence,
                locality: row.locality,
                note: row.note,
                latitude: row.latitude,
                longitude: row.longitude,
                createdAt: row.capturedDate,
                uploadedPath: row.imagePath
            )
            modelContext.insert(observation)
            localById[row.id] = observation
            if let uploadedPath = row.imagePath {
                localByUploadedPath[uploadedPath] = observation
            }
            importedCount += 1
        }

        return Summary(pulled: importedCount, updated: updatedCount)
    }

    private static func remoteObservationRows(session: SupabaseSession) async -> [RemoteObservationRow]? {
        guard let projectURL = SupabaseConfiguration.projectURL,
              let anonKey = SupabaseConfiguration.anonKey else {
            return nil
        }

        var components = URLComponents(url: projectURL.appending(path: "rest/v1/observations"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "select", value: "id,common_name,latin_name,rarity,finish,stars,confidence,locality,note,latitude,longitude,image_path,captured_at,created_at"),
            URLQueryItem(name: "user_id", value: "eq.\(session.userId.uuidString)"),
            URLQueryItem(name: "order", value: "captured_at.desc"),
            URLQueryItem(name: "limit", value: "200")
        ]

        guard let url = components?.url else { return nil }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            return nil
        }

        return try? JSONDecoder().decode([RemoteObservationRow].self, from: data)
    }

    private static func uploadLocalObservationImage(_ observation: WildObservation, session: SupabaseSession) async -> String? {
        guard let imageData = ObservationPhotoStore.data(named: observation.imageName),
              let uploadURL = storageObjectURL(path: storagePath(for: observation, session: session)),
              let anonKey = SupabaseConfiguration.anonKey else {
            return nil
        }

        let storagePath = storagePath(for: observation, session: session)
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.setValue("true", forHTTPHeaderField: "x-upsert")
        request.httpBody = imageData

        guard let (_, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            return nil
        }

        return storagePath
    }

    private static func needsAuthenticatedUpload(_ observation: WildObservation) -> Bool {
        guard let uploadedPath = observation.uploadedPath else { return true }
        return uploadedPath.hasPrefix("devices/")
    }

    @MainActor
    private static func apply(_ row: RemoteObservationRow, to observation: WildObservation, session: SupabaseSession) async -> Bool {
        var changed = false
        func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<WildObservation, Value>, _ value: Value) {
            if observation[keyPath: keyPath] != value {
                observation[keyPath: keyPath] = value
                changed = true
            }
        }

        update(\.commonName, row.commonName)
        update(\.latinName, row.latinName)
        update(\.rarity, row.rarity)
        update(\.finish, row.finish)
        update(\.stars, row.stars)
        update(\.confidence, row.confidence)
        update(\.locality, row.locality)
        update(\.note, row.note)
        update(\.latitude, row.latitude)
        update(\.longitude, row.longitude)
        update(\.createdAt, row.capturedDate)
        update(\.uploadedPath, row.imagePath)

        if !observation.imageName.hasPrefix("wildgo-local://"),
           row.imagePath != nil {
            let imageName = await localImageReference(for: row, session: session)
            if imageName.hasPrefix("wildgo-local://") {
                update(\.imageName, imageName)
            }
        }

        return changed
    }

    private static func localImageReference(for row: RemoteObservationRow, session: SupabaseSession) async -> String {
        if let imagePath = row.imagePath,
           let data = await downloadObservationImage(path: imagePath, session: session),
           let localReference = try? ObservationPhotoStore.saveImageData(data) {
            return localReference
        }

        return fallbackImageName(for: row)
    }

    private static func downloadObservationImage(path: String, session: SupabaseSession) async -> Data? {
        guard let url = storageObjectURL(path: path),
              let anonKey = SupabaseConfiguration.anonKey else {
            return nil
        }

        var request = URLRequest(url: url)
        request.setValue(anonKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode ?? 500 < 300 else {
            return nil
        }

        return data
    }

    private static func storagePath(for observation: WildObservation, session: SupabaseSession) -> String {
        "\(session.userId.uuidString.lowercased())/\(observation.id.uuidString.lowercased()).jpg"
    }

    private static func storageObjectURL(path: String) -> URL? {
        guard let projectURL = SupabaseConfiguration.projectURL else { return nil }

        var url = projectURL.appendingPathComponent("storage")
            .appendingPathComponent("v1")
            .appendingPathComponent("object")
            .appendingPathComponent("observations")
        for component in path.split(separator: "/") {
            url.appendPathComponent(String(component))
        }

        return url
    }

    private static func fallbackImageName(for row: RemoteObservationRow) -> String {
        let name = row.commonName.lowercased()
        if name.contains("cardinal") { return "binder-cardinal-gen.png" }
        if name.contains("squirrel") { return "binder-squirrel-gen.png" }
        if name.contains("susan") || name.contains("flower") { return "binder-flower-gen.png" }
        if name.contains("pigeon") { return "binder-pigeon-gen.png" }
        if name.contains("monarch") || name.contains("butterfly") { return "binder-butterfly-gen.png" }
        if name.contains("turkey tail") || name.contains("mushroom") || name.contains("fungus") { return "binder-turkey-tail-gen.png" }
        return "capture-blue-jay-landscape-gen-v2.png"
    }

    private struct RemoteObservationRow: Decodable {
        var id: UUID
        var commonName: String
        var latinName: String
        var rarity: String
        var finish: String
        var stars: Int
        var confidence: Double
        var locality: String
        var note: String
        var latitude: Double?
        var longitude: Double?
        var imagePath: String?
        var capturedAt: String?
        var createdAt: String?

        var capturedDate: Date {
            RemoteDateParser.date(from: capturedAt) ?? RemoteDateParser.date(from: createdAt) ?? .now
        }

        enum CodingKeys: String, CodingKey {
            case id
            case commonName = "common_name"
            case latinName = "latin_name"
            case rarity
            case finish
            case stars
            case confidence
            case locality
            case note
            case latitude
            case longitude
            case imagePath = "image_path"
            case capturedAt = "captured_at"
            case createdAt = "created_at"
        }
    }

    private enum RemoteDateParser {
        private static let fractionalFormatter: ISO8601DateFormatter = {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter
        }()

        private static let standardFormatter = ISO8601DateFormatter()

        static func date(from value: String?) -> Date? {
            guard let value else { return nil }
            return fractionalFormatter.date(from: value) ?? standardFormatter.date(from: value)
        }
    }
}

enum WildCardShareExporter {
    @MainActor
    static func shareItems(for observation: WildObservation) -> [Any] {
        let text = "Wild Go card: \(observation.commonName) (\(observation.latinName)), \(observation.stars)-star \(observation.rarity), \(Int(observation.confidence * 100))% AI confidence."
        if let image = renderShareImage(for: observation) {
            return [image, text]
        }
        return [text]
    }

    @MainActor
    static func renderShareImage(for observation: WildObservation) -> UIImage? {
        let renderer = ImageRenderer(content: WildCardShareArtboard(observation: observation))
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct WildCardShareArtboard: View {
    var observation: WildObservation

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("WILD GO")
                .font(.caption.weight(.black))
                .tracking(2.2)
                .foregroundStyle(Color.wildLime)

            HeroCollectibleCard(observation: observation)
                .frame(width: 306)

            Text(PrivacyLocationPolicy.displayLocality(for: observation))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.wildInk, .black],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .frame(width: 346)
    }
}

enum WildGoError: LocalizedError {
    case cameraUnavailable
    case cameraCaptureFailed
    case missingSupabaseConfiguration
    case identificationFailed
    case localRecognitionUnavailable
    case authFailed(String)

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            "Camera capture is unavailable on this device."
        case .cameraCaptureFailed:
            "Could not capture a camera photo."
        case .missingSupabaseConfiguration:
            "Missing SUPABASE_URL or SUPABASE_ANON_KEY in the app configuration."
        case .identificationFailed:
            "The cloud species identifier did not return a valid result."
        case .localRecognitionUnavailable:
            "Local Vision and Core ML recognition is not bundled yet."
        case .authFailed(let message):
            message
        }
    }
}

extension SpeciesIdentificationResult {
    static let sample = SpeciesIdentificationResult(
        commonName: "Blue Jay",
        latinName: "Cyanocitta cristata",
        rarity: "City Legend",
        finish: "Holo Foil",
        stars: 6,
        confidence: 0.92,
        note: "Bold, noisy, and usually spotted near mature street trees.",
        storagePath: nil
    )
}

extension WildObservation {
    static let samples: [WildObservation] = [
        WildObservation(
            commonName: "Northern Cardinal",
            latinName: "Cardinalis cardinalis",
            imageName: "binder-cardinal-gen.png",
            rarity: "City Legend",
            finish: "Holo Foil",
            stars: 6,
            confidence: 0.94,
            locality: "Brooklyn, NY",
            note: "A bright neighborhood trophy card with a strong seasonal signal.",
            latitude: 40.6602,
            longitude: -73.9690
        ),
        WildObservation(
            commonName: "Eastern Gray Squirrel",
            latinName: "Sciurus carolinensis",
            imageName: "binder-squirrel-gen.png",
            rarity: "Rare",
            finish: "Metallic",
            stars: 3,
            confidence: 0.86,
            locality: "Prospect Park",
            note: "Fast park regular. Look for fence lines and old oaks.",
            latitude: 40.6650,
            longitude: -73.9654
        ),
        WildObservation(
            commonName: "Black-eyed Susan",
            latinName: "Rudbeckia hirta",
            imageName: "binder-flower-gen.png",
            rarity: "Uncommon",
            finish: "Colored Edge",
            stars: 2,
            confidence: 0.88,
            locality: "Fort Greene Park",
            note: "A sunny summer find along paths and open garden beds.",
            latitude: 40.6915,
            longitude: -73.9750
        ),
        WildObservation(
            commonName: "Rock Pigeon",
            latinName: "Columba livia",
            imageName: "binder-pigeon-gen.png",
            rarity: "Common",
            finish: "Matte",
            stars: 1,
            confidence: 0.91,
            locality: "Downtown Brooklyn",
            note: "An everyday city companion with surprising plumage variety.",
            latitude: 40.6943,
            longitude: -73.9866
        ),
        WildObservation(
            commonName: "Monarch Butterfly",
            latinName: "Danaus plexippus",
            imageName: "binder-butterfly-gen.png",
            rarity: "Seasonal",
            finish: "Iridescent",
            stars: 4,
            confidence: 0.89,
            locality: "Prospect Park",
            note: "A seasonal garden highlight around milkweed and sunny edges.",
            latitude: 40.6615,
            longitude: -73.9712
        ),
        WildObservation(
            commonName: "Turkey Tail",
            latinName: "Trametes versicolor",
            imageName: "binder-turkey-tail-gen.png",
            rarity: "Local Special",
            finish: "Foil",
            stars: 5,
            confidence: 0.83,
            locality: "Greenpoint",
            note: "A local special best logged from a respectful distance.",
            latitude: 40.6558,
            longitude: -73.9900
        )
    ]

    var accentColor: Color {
        switch stars {
        case 1:
            return Color(red: 0.62, green: 0.78, blue: 0.55)
        case 2:
            return Color.wildGold
        case 3:
            return Color.wildCyan
        case 4:
            return Color.purple.opacity(0.88)
        case 5:
            return Color.orange
        default:
            return Color.wildGold
        }
    }

    var cardSurface: LinearGradient {
        switch stars {
        case 1:
            return LinearGradient(
                colors: [Color(red: 0.08, green: 0.24, blue: 0.14), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 2:
            return LinearGradient(
                colors: [Color(red: 0.25, green: 0.24, blue: 0.06), Color.black.opacity(0.9)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 3:
            return LinearGradient(
                colors: [Color(red: 0.05, green: 0.25, blue: 0.34), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 4:
            return LinearGradient(
                colors: [Color(red: 0.27, green: 0.12, blue: 0.31), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case 5:
            return LinearGradient(
                colors: [Color(red: 0.32, green: 0.15, blue: 0.04), Color.black.opacity(0.92)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            return LinearGradient(
                colors: [Color.black.opacity(0.72), Color.wildInk.opacity(0.84), Color.black.opacity(0.86)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    var cardBorder: AngularGradient {
        if stars >= 6 {
            return AngularGradient(
                colors: [
                    Color.white,
                    Color.wildGold,
                    Color.wildLime,
                    Color.wildCyan,
                    Color.purple,
                    Color.pink,
                    Color.wildGold,
                    Color.white
                ],
                center: .center
            )
        }

        return AngularGradient(
            colors: [
                accentColor.opacity(0.9),
                Color.white.opacity(0.62),
                accentColor.opacity(0.64),
                Color.black.opacity(0.2),
                accentColor.opacity(0.9)
            ],
            center: .center
        )
    }

    var cardDateText: String {
        switch commonName {
        case "Northern Cardinal":
            return "Jul 4, 2026"
        case "Eastern Gray Squirrel":
            return "Jul 1, 2026"
        case "Black-eyed Susan":
            return "Jul 2, 2026"
        case "Rock Pigeon":
            return "Jun 30, 2026"
        case "Monarch Butterfly":
            return "Jun 28, 2026"
        case "Turkey Tail":
            return "Jun 27, 2026"
        default:
            return createdAt.formatted(.dateTime.month(.abbreviated).day().year())
        }
    }

    var shortDateText: String {
        switch commonName {
        case "Black-eyed Susan":
            return "Jul 2"
        case "Rock Pigeon":
            return "Jun 30"
        case "Monarch Butterfly":
            return "Jun 28"
        case "Turkey Tail":
            return "Jun 27"
        default:
            return createdAt.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

struct WildGoRootView: View {
    @StateObject private var viewModel = WildGoViewModel()
    @StateObject private var auth = SupabaseAuthService()

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                TabView(selection: $viewModel.selectedTab) {
                    ExploreScreen()
                        .tag(WildGoTab.explore)

                    SoftMapScreen()
                        .tag(WildGoTab.map)

                    CaptureScreen()
                        .tag(WildGoTab.capture)

                    BinderScreen()
                        .tag(WildGoTab.binder)

                    ProfileScreen()
                        .tag(WildGoTab.profile)
                }
                .toolbar(.hidden, for: .tabBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if viewModel.selectedTab != .capture {
                        WildGoBottomTabBar(selection: $viewModel.selectedTab)
                    }
                }

                if let toast = viewModel.toast {
                    WildToastView(message: toast.message)
                        .id(toast.id)
                        .padding(.top, proxy.safeAreaInsets.top + 12)
                        .padding(.horizontal, 18)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(20)
                }
            }
        }
        .onChange(of: viewModel.selectedTab) { _, selectedTab in
            QAInteractionProbe.record("tab:\(selectedTab.qaName)")
        }
        .environmentObject(viewModel)
        .environmentObject(auth)
        .tint(Color.wildInk)
    }
}

struct WildGoBottomTabBar: View {
    @Binding var selection: WildGoTab

    private let tabs: [(WildGoTab, String, String)] = [
        (.explore, "Explore", "safari.fill"),
        (.map, "Map", "mappin.and.ellipse"),
        (.capture, "Capture", "camera.fill"),
        (.binder, "Cards", "rectangle.stack.fill"),
        (.profile, "Profile", "person.crop.circle.fill")
    ]

    private var usesLightMaterial: Bool {
        selection == .profile
    }

    private var visibleTabs: [(WildGoTab, String, String)] {
        guard usesLightMaterial else { return tabs }
        // The concept's white Profile bar labels the binder destination "Collection".
        return tabs.filter { $0.0 != .capture }.map { tab, title, icon in
            tab == .binder ? (tab, "Collection", icon) : (tab, title, icon)
        }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(visibleTabs, id: \.0) { tab, title, systemName in
                Button {
                    selection = tab
                } label: {
                    if tab == .capture {
                        captureItem(title: title, systemName: systemName)
                    } else {
                        standardItem(tab: tab, title: title, systemName: systemName)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: usesLightMaterial ? 54 : 50)
                .contentShape(Rectangle())
                .accessibilityLabel(title)
                .accessibilityIdentifier("tab.\(tab.qaName)")
            }
        }
        .frame(height: usesLightMaterial ? 66 : 62)
        .padding(.horizontal, usesLightMaterial ? 8 : 10)
        .background {
            if usesLightMaterial {
                RoundedRectangle(cornerRadius: 30, style: .continuous)
                    .fill(Color.white.opacity(0.97))
                    .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: -2)
            } else {
                Color(red: 0.025, green: 0.105, blue: 0.075).opacity(0.98)
            }
        }
        .overlay(alignment: .top) {
            if !usesLightMaterial {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .padding(.horizontal, usesLightMaterial ? 12 : 0)
        .padding(.top, usesLightMaterial ? 4 : 0)
        .padding(.bottom, usesLightMaterial ? 6 : 0)
    }

    private func standardItem(tab: WildGoTab, title: String, systemName: String) -> some View {
        let isSelected = selection == tab
        let selectedColor = usesLightMaterial ? Color(red: 0.12, green: 0.37, blue: 0.22) : Color.wildLime
        let inactiveColor = usesLightMaterial ? Color.wildInk.opacity(0.62) : Color.white.opacity(0.52)

        return VStack(spacing: 4) {
            Image(systemName: systemName)
                .font(.system(size: 22, weight: isSelected ? .bold : .medium))
                .frame(height: 25)
            Text(title)
                .font(.caption2.weight(isSelected ? .bold : .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isSelected ? selectedColor : inactiveColor)
        .frame(maxWidth: .infinity, minHeight: 52)
    }

    private func captureItem(title: String, systemName: String) -> some View {
        let fill = usesLightMaterial
            ? Color(red: 0.18, green: 0.49, blue: 0.3)
            : Color.wildLime
        let foreground = usesLightMaterial ? Color.white : Color.wildInk

        return VStack(spacing: 1) {
            Image(systemName: systemName)
                .font(.system(size: 23, weight: .black))
                .foregroundStyle(foreground)
                .frame(width: 54, height: 54)
                .background(fill, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(usesLightMaterial ? 0.9 : 0.24), lineWidth: 3))
                .shadow(color: Color.black.opacity(0.22), radius: 6, x: 0, y: 3)

            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(usesLightMaterial ? Color.wildInk.opacity(0.78) : Color.white.opacity(0.78))
                .lineLimit(1)
        }
        .offset(y: -10)
        .frame(maxWidth: .infinity, minHeight: 66)
    }
}

struct CaptureScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: WildGoViewModel
    @EnvironmentObject private var auth: SupabaseAuthService
    @StateObject private var camera = CameraSession()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCapturing = false
    @State private var isShowingShareSheet = false
    @State private var isCardFlipped = false
    @State private var isDepthPreviewing = false
    @State private var activeCardIndex = 0
    private var demoObservation: WildObservation {
        WildObservation(
            commonName: "Blue Jay",
            latinName: "Cyanocitta cristata",
            imageName: "capture-blue-jay-landscape-gen-v2.png",
            rarity: "City Legend",
            finish: "Holo Foil",
            stars: 6,
            confidence: 0.92,
            locality: "Approx location",
            note: "Common and bold in the city. Often seen in parks and tree-lined streets.",
            createdAt: demoDate
        )
    }

    private var displayObservation: WildObservation {
        guard case .success(let result) = viewModel.recognitionState else {
            return demoObservation
        }

        return WildObservation(
            commonName: result.commonName,
            latinName: result.latinName,
            imageName: viewModel.selectedImageName ?? demoObservation.imageName,
            rarity: result.rarity,
            finish: result.finish,
            stars: result.stars,
            confidence: result.confidence,
            locality: "Approx location",
            note: result.note,
            latitude: viewModel.locationManager.currentCoordinate?.latitude,
            longitude: viewModel.locationManager.currentCoordinate?.longitude,
            uploadedPath: result.storagePath
        )
    }

    private var carouselObservations: [WildObservation] {
        let primary = displayObservation
        let supporting = WildObservation.samples
            .filter { $0.commonName != primary.commonName }
            .prefix(3)
        return [primary] + supporting
    }

    private var activeObservation: WildObservation {
        let observations = carouselObservations
        return observations[min(max(activeCardIndex, 0), observations.count - 1)]
    }

    private var demoDate: Date {
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 4
        components.hour = 8
        components.minute = 47
        return Calendar.current.date(from: components) ?? Date(timeIntervalSince1970: 1_783_256_820)
    }

    private var shareCardText: String {
        "Wild Go card: \(activeObservation.commonName) (\(activeObservation.latinName)), \(activeObservation.stars)-star \(activeObservation.rarity), \(Int(activeObservation.confidence * 100))% AI confidence."
    }

    private var shareCardItems: [Any] {
        WildCardShareExporter.shareItems(for: activeObservation)
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                let compactHeight = proxy.size.height < 880
                let cardWidth: CGFloat = 324
                let maximumCardScale: CGFloat = compactHeight ? 1.17 : 1.2
                let minimumCardScale: CGFloat = proxy.size.height < 780 ? 0.84 : (compactHeight ? 0.98 : 1.02)
                let widthScale = (proxy.size.width - (compactHeight ? 22 : 18)) / cardWidth
                let heightScale = (proxy.size.height - (compactHeight ? 340 : 360)) / 472
                let cardScale = max(minimumCardScale, min(maximumCardScale, widthScale, heightScale))
                let stageWidth: CGFloat = cardWidth * cardScale + 6
                let stageHeight: CGFloat = 472 * cardScale + 26

                ZStack(alignment: .top) {
                    CameraHeroBackground(camera: camera)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: compactHeight ? 5 : 9) {
                            CaptureTopBar(selectedPhoto: $selectedPhoto) {
                                viewModel.selectedTab = .explore
                                viewModel.showToast("Back to Explore")
                            }
                                .padding(.top, compactHeight ? -16 : -10)

                            UnlockTitle()
                                .padding(.top, compactHeight ? 0 : 2)

                            CaptureCardStage(
                                observation: activeObservation,
                                isFlipped: $isCardFlipped,
                                isDepthPreviewing: isDepthPreviewing,
                                cardWidth: cardWidth,
                                canSwipeBackward: activeCardIndex > 0,
                                canSwipeForward: activeCardIndex < carouselObservations.count - 1,
                                onPageChange: changeCardPage
                            )
                            .scaleEffect(cardScale)
                            .frame(width: stageWidth, height: stageHeight)
                            .padding(.top, compactHeight ? -8 : -2)

                            InteractionStrip(
                                state: viewModel.recognitionState,
                                isCardFlipped: $isCardFlipped,
                                isDepthPreviewing: $isDepthPreviewing
                            )
                                .padding(.top, compactHeight ? -6 : 0)

                            PageDots(activeIndex: activeCardIndex)
                                .padding(.top, compactHeight ? 7 : 8)

                            VStack(spacing: compactHeight ? 9 : 14) {
                                Button {
                                    viewModel.showToast("Capturing card...")
                                    Task {
                                        await captureCameraImage()
                                    }
                                } label: {
                                    Label(isCapturing ? "Capturing" : "Add to Binder", systemImage: "rectangle.stack.badge.plus")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.wildPrimary)
                                .disabled(isCapturing)
                                .accessibilityIdentifier("capture.addToBinder")

                                Button {
                                    isShowingShareSheet = true
                                    viewModel.showToast("Opening share sheet")
                                } label: {
                                    Label("Share Card", systemImage: "square.and.arrow.up")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.wildSecondary)
                                .accessibilityIdentifier("capture.shareCard")
                            }
                            .frame(maxWidth: 350)
                            .padding(.top, compactHeight ? 0 : 2)
                        }
                        .padding(.horizontal, compactHeight ? 24 : 28)
                        .padding(.bottom, compactHeight ? 24 : 34)
                        .frame(width: proxy.size.width, alignment: .center)
                    }
                    .frame(width: proxy.size.width)
                }
                .frame(width: proxy.size.width)
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .toolbar(.hidden, for: .tabBar)
            .statusBarHidden(true)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: shareCardItems)
        }
        .onAppear {
            camera.start()
            viewModel.locationManager.requestLocation()
        }
        .onDisappear {
            camera.stop()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                viewModel.showToast("Importing photo...")
                if let data = try? await item.loadTransferable(type: Data.self) {
                    viewModel.selectedUIImage = UIImage(data: data)
                    let accessToken = await accessTokenForCloudRequest()
                    await viewModel.identify(
                        imageData: data,
                        modelContext: modelContext,
                        accessToken: accessToken
                    )
                    if case .success(let result) = viewModel.recognitionState {
                        viewModel.showToast("\(result.commonName) added to Binder")
                    }
                } else {
                    viewModel.showToast("Photo import was cancelled")
                }
            }
        }
        .onChange(of: displayObservation.commonName) { _, _ in
            activeCardIndex = 0
            isCardFlipped = false
        }
    }

    private func changeCardPage(_ delta: Int) {
        let nextIndex = min(max(activeCardIndex + delta, 0), carouselObservations.count - 1)
        guard nextIndex != activeCardIndex else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.82)) {
            activeCardIndex = nextIndex
            isCardFlipped = false
            isDepthPreviewing = false
        }
        recordCapturePage(nextIndex)
        viewModel.showToast("Card \(nextIndex + 1) of \(carouselObservations.count)")
    }

    private func recordCapturePage(_ index: Int) {
        switch index {
        case 0:
            QAInteractionProbe.record("carousel:capture:1")
        case 1:
            QAInteractionProbe.record("carousel:capture:2")
        case 2:
            QAInteractionProbe.record("carousel:capture:3")
        case 3:
            QAInteractionProbe.record("carousel:capture:4")
        default:
            break
        }
    }

    private func identifyDemoImage() async {
        guard let image = UIImage.namedInWildGoBundle("capture-blue-jay-landscape-gen-v2.png"),
              let data = image.jpegData(compressionQuality: 0.88) else { return }
        let accessToken = await accessTokenForCloudRequest()
        await viewModel.identify(
            imageData: data,
            modelContext: modelContext,
            accessToken: accessToken
        )
    }

    @MainActor
    private func captureCameraImage() async {
        guard !isCapturing else { return }
        isCapturing = true
        defer { isCapturing = false }

        do {
            let data = try await camera.capturePhotoData()
            viewModel.selectedUIImage = UIImage(data: data)
            let accessToken = await accessTokenForCloudRequest()
            await viewModel.identify(
                imageData: data,
                modelContext: modelContext,
                accessToken: accessToken
            )
            if case .success(let result) = viewModel.recognitionState {
                viewModel.showToast("\(result.commonName) added to Binder")
            }
        } catch WildGoError.cameraUnavailable {
            await identifyDemoImage()
            viewModel.showToast("Simulator fallback card added")
        } catch {
            viewModel.recognitionState = .failure(error.localizedDescription)
            viewModel.showToast("Capture failed")
        }
    }

    @MainActor
    private func accessTokenForCloudRequest() async -> String? {
        guard auth.isSignedIn else { return nil }

        do {
            return try await auth.validAccessToken()
        } catch {
            viewModel.showToast("Sign in again to sync")
            return nil
        }
    }
}

struct CaptureTopBar: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    var onBack: () -> Void

    var body: some View {
        ZStack {
            HStack(spacing: 10) {
                Image(systemName: "leaf")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(Color.wildLime)
                Text("Wild Go")
                    .font(.title3.weight(.heavy))
                    .foregroundStyle(.white)
            }
                .foregroundStyle(.white)

            HStack {
                Button(action: onBack) {
                    CircleIconButton(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to Explore")
                .accessibilityIdentifier("capture.back")

                Spacer()
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    CircleIconButton(systemName: "rectangle.stack")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Choose photo")
                .accessibilityIdentifier("capture.choosePhoto")
            }
        }
        .frame(width: min(UIScreen.main.bounds.width - 68, 360))
    }
}

struct CircleIconButton: View {
    var systemName: String

    var body: some View {
        Image(systemName: systemName)
            .font(.headline.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 42, height: 42)
            .background(.black.opacity(0.32), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.22), lineWidth: 1.5))
    }
}

struct UnlockTitle: View {
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                LeafRule(flipped: false)
                Text("New card unlocked")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                LeafRule(flipped: true)
            }

            Text("Move phone to catch the foil")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
        }
    }
}

struct LeafRule: View {
    var flipped: Bool

    var body: some View {
        HStack(spacing: 3) {
            Rectangle()
                .frame(width: 22, height: 1)
            Image(systemName: "leaf")
                .font(.caption2.weight(.bold))
        }
        .foregroundStyle(Color.wildLime)
        .scaleEffect(x: flipped ? -1 : 1, y: 1)
    }
}

struct CameraHeroBackground: View {
    @ObservedObject var camera: CameraSession

    var body: some View {
        ZStack {
            BundleImage(name: "capture-blue-jay-landscape-gen-v2.png")
                .scaledToFill()
                .scaleEffect(1.2)
                .blur(radius: 12)
                .saturation(1.18)
                .ignoresSafeArea()

            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .opacity(0.24)
                    .blendMode(.screen)
                    .ignoresSafeArea()
            }

            LinearGradient(
                colors: [
                    .black.opacity(0.66),
                    Color.wildInk.opacity(0.38),
                    .black.opacity(0.7)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [.clear, .black.opacity(0.56)],
                center: .center,
                startRadius: 80,
                endRadius: 430
            )
            .ignoresSafeArea()
        }
    }
}

struct CaptureCardStage: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    var observation: WildObservation
    @Binding var isFlipped: Bool
    var isDepthPreviewing: Bool
    var cardWidth: CGFloat = 324
    var canSwipeBackward = false
    var canSwipeForward = false
    var onPageChange: (Int) -> Void = { _ in }
    @GestureState private var dragTranslation: CGSize = .zero

    private var alternativeMatches: [String] {
        if case .success(let result) = viewModel.recognitionState, !result.resolvedAlternatives.isEmpty {
            return result.resolvedAlternatives
        }
        return SpeciesFieldGuide.entry(for: observation).alternativeMatches
    }

    private var shaderTilt: CGPoint {
        CGPoint(
            x: min(max(dragTranslation.width / 120, -1), 1),
            y: min(max(dragTranslation.height / 120, -1), 1)
        )
    }

    var body: some View {
        ZStack {
            HeroCollectibleCard(
                observation: observation,
                localityLabel: "Approx location",
                cardWidth: cardWidth,
                foilTilt: shaderTilt
            )
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.62)

            CaptureCardBack(
                observation: observation,
                alternativeMatches: alternativeMatches,
                cardWidth: cardWidth,
                foilTilt: shaderTilt
            )
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        }
        .frame(width: cardWidth, height: 472)
        .rotationEffect(.degrees(isFlipped ? 1.4 : -2.5))
        .rotation3DEffect(
            .degrees((isDepthPreviewing ? 13 : 6) + Double(dragTranslation.width / 22)),
            axis: (
                x: isDepthPreviewing ? 0.18 : Double(-dragTranslation.height / 150),
                y: 1.0,
                z: 0.0
            ),
            perspective: 0.62
        )
        .scaleEffect(isDepthPreviewing ? 1.035 : (dragTranslation == .zero ? 1 : 1.012))
        .offset(x: dragTranslation.width * 0.08, y: dragTranslation.height * 0.025)
        .shadow(color: .black.opacity(isDepthPreviewing ? 0.56 : 0.28), radius: isDepthPreviewing ? 30 : 10, x: 0, y: isDepthPreviewing ? 20 : 4)
        .contentShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        .onTapGesture {
            let willShowBack = !isFlipped
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                isFlipped = willShowBack
            }
            viewModel.showToast(willShowBack ? "Card details side shown" : "Card front shown")
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 12, coordinateSpace: .local)
                .updating($dragTranslation) { value, state, _ in
                    state = value.translation
                }
                .onEnded { value in
                    let horizontal = value.predictedEndTranslation.width
                    let vertical = value.predictedEndTranslation.height
                    guard abs(horizontal) > 72, abs(horizontal) > abs(vertical) * 1.25 else { return }

                    if horizontal < 0, canSwipeForward {
                        onPageChange(1)
                    } else if horizontal > 0, canSwipeBackward {
                        onPageChange(-1)
                    }
                }
        )
        .accessibilityIdentifier("capture.heroCard")
        .animation(.spring(response: 0.46, dampingFraction: 0.82), value: isFlipped)
        .animation(.spring(response: 0.28, dampingFraction: 0.74), value: isDepthPreviewing)
    }
}

struct CaptureCardBack: View {
    var observation: WildObservation
    var alternativeMatches: [String] = []
    var cardWidth: CGFloat = 306
    var foilTilt: CGPoint = .zero

    private var guide: SpeciesFieldGuideEntry {
        SpeciesFieldGuide.entry(for: observation)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .center) {
                Label("Field Notes", systemImage: "doc.text.magnifyingglass")
                    .font(.caption.weight(.heavy))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.wildLime)

                Spacer()

                Text("#WGO-26-0704-1178")
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.wildGold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .overlay(Capsule().stroke(Color.wildGold.opacity(0.62), lineWidth: 1))
            }

            HStack(spacing: 12) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(width: 82, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.wildGold.opacity(0.72), lineWidth: 1.4))
                    .overlay(
                        HoloShine(
                            cornerRadius: 16,
                            starCount: observation.stars,
                            tilt: foilTilt
                        )
                        .opacity(observation.stars >= 5 ? 0.34 : 0.12)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(observation.commonName)
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    Text(observation.latinName)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(Color.wildLime)
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                    StarStrip(count: observation.stars, font: .caption)
                    Text("\(observation.rarity) · \(observation.finish)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.wildGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Text(observation.note)
                .font(.caption.weight(.medium))
                .foregroundStyle(.white.opacity(0.84))
                .lineSpacing(2)
                .lineLimit(3)

            VStack(alignment: .leading, spacing: 8) {
                CaptureBackFact(icon: "tree", label: "Habitat", value: guide.habitat)
                CaptureBackFact(icon: "calendar", label: "Seasonality", value: guide.seasonality)
                CaptureBackFact(icon: "location.slash", label: "Privacy", value: PrivacyLocationPolicy.displayLocality(for: observation))
                CaptureBackFact(icon: "exclamationmark.triangle", label: "Safety", value: guide.safetyGuidance)
            }

            if !resolvedAlternatives.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Also consider")
                        .font(.caption2.weight(.heavy))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.48))
                    Text(resolvedAlternatives.joined(separator: " • "))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.wildLime.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                MetricPill(label: "AI Match", value: "\(Int(observation.confidence * 100))%")
                MetricPill(label: "Saved", value: observation.cardDateText)
            }
        }
        .padding(15)
        .frame(width: cardWidth, height: 472)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.76))
                LinearGradient(
                    colors: [Color.wildInk.opacity(0.74), .black.opacity(0.92), Color(red: 0.13, green: 0.05, blue: 0.18).opacity(0.8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                HoloShine(
                    cornerRadius: 28,
                    starCount: observation.stars,
                    tilt: foilTilt
                )
                    .opacity(0.38)
            }
        )
        .overlay(
            RarityMetalBorder(
                starCount: observation.stars,
                cornerRadius: 28,
                lineWidth: 10,
                tilt: foilTilt
            )
            .opacity(0.9)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.wildGold.opacity(0.6), lineWidth: 1.1)
                .padding(14)
        )
    }

    private var resolvedAlternatives: [String] {
        alternativeMatches.isEmpty ? guide.alternativeMatches : alternativeMatches
    }
}

struct CaptureBackFact: View {
    var icon: String
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.wildLime)
                .frame(width: 22, height: 22)
                .background(.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(.white.opacity(0.1), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.48))
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
    }
}

struct InteractionStrip: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    var state: RecognitionState
    @Binding var isCardFlipped: Bool
    @Binding var isDepthPreviewing: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 0) {
                Button {
                    viewModel.showToast("Tilt shimmer is active")
                } label: {
                    ControlTile(icon: "iphone.gen3.radiowaves.left.and.right", title: "Tilt", subtitle: "Catch the foil")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("capture.tilt")

                Divider()
                    .frame(height: 68)
                    .overlay(.white.opacity(0.26))
                Button {
                    let willPreview = !isDepthPreviewing
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                        isDepthPreviewing = willPreview
                    }
                    viewModel.showToast(willPreview ? "Depth preview opened" : "Depth preview released")
                } label: {
                    ControlTile(icon: "hand.tap", title: "Press & Hold", subtitle: "See depth")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("capture.depth")
                .onLongPressGesture(
                    minimumDuration: 0.18,
                    maximumDistance: 24,
                    pressing: { pressing in
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.76)) {
                            isDepthPreviewing = pressing
                        }
                    },
                    perform: {
                        viewModel.showToast("Holding for depth")
                    }
                )

                Divider()
                    .frame(height: 68)
                    .overlay(.white.opacity(0.26))
                Button {
                    let willShowBack = !isCardFlipped
                    withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                        isCardFlipped = willShowBack
                    }
                    viewModel.showToast(willShowBack ? "Card details side shown" : "Card front shown")
                } label: {
                    ControlTile(icon: "rectangle.portrait.rotate", title: "Flip", subtitle: "View details")
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("capture.flip")
            }
            .frame(maxWidth: .infinity)

            statusLine
        }
        .font(.footnote.weight(.semibold))
        .foregroundStyle(.white.opacity(0.9))
    }

    @ViewBuilder
    private var statusLine: some View {
        switch state {
        case .idle:
            EmptyView()
        case .loading:
            ProgressView("Identifying with cloud API...")
                .tint(.white)
        case .success(let result):
            Text("\(result.commonName) saved locally with SwiftData.")
        case .failure(let message):
            Text(message)
        }
    }
}

struct ControlTile: View {
    var icon: String
    var title: String
    var subtitle: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2.weight(.semibold))
                .frame(height: 30)
            Text(title)
                .font(.caption.weight(.heavy))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(width: 90, height: 84)
    }
}

struct PageDots: View {
    var activeIndex: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(index == activeIndex ? Color.wildLime : .white.opacity(0.34))
                    .frame(width: 8, height: 8)
                    .animation(.easeOut(duration: 0.18), value: activeIndex)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Card \(activeIndex + 1) of 4")
    }
}

enum BinderLayoutMode {
    case grid
    case list
}

struct BinderScreen: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Query(sort: \WildObservation.createdAt, order: .reverse) private var observations: [WildObservation]
    @State private var selectedMode = "My Binder"
    @State private var sortLabel = "Recent"
    @State private var layoutMode: BinderLayoutMode = .grid
    @State private var isShowingBinderTips = false

    private var cardsByName: [String: WildObservation] {
        observations.reduce(into: [:]) { cardsByName, observation in
            if cardsByName[observation.commonName] == nil {
                cardsByName[observation.commonName] = observation
            }
        }
    }

    private var referenceCards: [WildObservation] {
        WildObservation.samples.map { sample in
            cardsByName[sample.commonName] ?? sample
        }
    }

    private var binderCards: [WildObservation] {
        [
            referenceCard(named: "Northern Cardinal"),
            referenceCard(named: "Eastern Gray Squirrel"),
            referenceCard(named: "Rock Pigeon"),
            referenceCard(named: "Black-eyed Susan"),
            referenceCard(named: "Monarch Butterfly"),
            referenceCard(named: "Turkey Tail")
        ]
    }

    private var visibleCards: [WildObservation] {
        switch sortLabel {
        case "Rarity":
            return binderCards.sorted {
                if $0.stars == $1.stars {
                    return $0.confidence > $1.confidence
                }
                return $0.stars > $1.stars
            }
        case "Confidence":
            return binderCards.sorted {
                if $0.confidence == $1.confidence {
                    return $0.stars > $1.stars
                }
                return $0.confidence > $1.confidence
            }
        default:
            return binderCards
        }
    }

    private var primaryCard: WildObservation {
        visibleCards.first ?? referenceCard(named: "Northern Cardinal")
    }

    private var secondaryCard: WildObservation {
        visibleCards.dropFirst().first ?? referenceCard(named: "Eastern Gray Squirrel")
    }

    private var smallCards: [WildObservation] {
        Array(visibleCards.dropFirst(2).prefix(4))
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    VStack(spacing: 4) {
                        BinderTopBar()
                            .padding(.top, 0)
                            .padding(.horizontal, 18)

                        BinderModeTabs(selectedMode: $selectedMode)
                    }
                    .padding(.bottom, 0)
                    .background(
                        LinearGradient(
                            colors: [
                                Color.wildInk.opacity(0.98),
                                Color(red: 0.02, green: 0.11, blue: 0.08),
                                Color.wildInk.opacity(0.94)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(.white.opacity(0.08))
                            .frame(height: 1)
                    }

                    VStack(spacing: 7) {
                        BinderFilterBar(sortLabel: $sortLabel, layoutMode: $layoutMode)
                            .padding(.top, 5)
                            .padding(.horizontal, 16)

                        if layoutMode == .grid {
                            BinderBoard(
                                primary: primaryCard,
                                secondary: secondaryCard,
                                smallCards: smallCards
                            )
                            .padding(.horizontal, 3)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            BinderListBoard(cards: visibleCards)
                                .padding(.horizontal, 3)
                                .transition(.opacity.combined(with: .move(edge: .trailing)))
                        }

                        BinderRarityGuideStrip()
                            .padding(.horizontal, 14)

                        BinderTipRow {
                            isShowingBinderTips = true
                            viewModel.showToast("Binder tips opened")
                        }
                            .padding(.horizontal, 18)
                            .padding(.bottom, 98)
                    }
                }
            }
            .background(BinderNightBackground())
            .toolbar(.hidden, for: .navigationBar)
            .toolbarBackground(Color.wildInk, for: .tabBar)
            .toolbarColorScheme(.dark, for: .tabBar)
            .statusBarHidden(true)
            .onAppear {
                seedIfNeeded()
            }
            .alert("Binder Tips", isPresented: $isShowingBinderTips) {
                Button("Got it", role: .cancel) {
                    viewModel.showToast("Binder tips closed")
                }
            } message: {
                Text("Tilt cards to shimmer, switch sort order from Recent, and use the layout toggle to compare grid/list views.")
            }
        }
        .saturation(0.8)
    }

    private func referenceCard(named name: String) -> WildObservation {
        referenceCards.first { $0.commonName == name }
            ?? WildObservation.samples.first { $0.commonName == name }
            ?? WildObservation.samples[0]
    }

    private func seedIfNeeded() {
        guard observations.isEmpty else { return }
        WildObservation.samples.forEach(modelContext.insert)
        try? modelContext.save()
    }
}

struct BinderNightBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.1, blue: 0.07),
                Color.wildInk,
                Color.black.opacity(0.96)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(alignment: .topLeading) {
            RadialGradient(
                colors: [Color.wildLime.opacity(0.2), .clear],
                center: .topLeading,
                startRadius: 20,
                endRadius: 360
            )
            .frame(width: 360, height: 320)
        }
        .overlay(alignment: .topTrailing) {
            RadialGradient(
                colors: [Color.wildCyan.opacity(0.09), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 260
            )
            .frame(width: 260, height: 260)
        }
        .ignoresSafeArea()
    }
}

struct BinderTopBar: View {
    @EnvironmentObject private var viewModel: WildGoViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("Wild Go")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .frame(width: 108, alignment: .leading)

            VStack(alignment: .leading, spacing: 5) {
                Button {
                    viewModel.showToast("Collection selector opened")
                } label: {
                    HStack(spacing: 5) {
                        Text("NYC Collection")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                            .layoutPriority(2)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.heavy))
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("binder.collectionSelector")

                ProgressView(value: 0.49)
                    .tint(Color.wildLime)
                    .frame(width: 112)

                Text("243 / 500 species")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(0.82))
            .frame(width: 124, alignment: .leading)
            .padding(.top, 4)

            Spacer(minLength: 0)

            LevelBadge()
                .padding(.top, 0)

            Button {
                viewModel.showToast("Notifications opened")
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(Color.wildCoral)
                        .frame(width: 8, height: 8)
                        .offset(x: 1, y: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("binder.notifications")
            .padding(.top, 6)
        }
    }
}

struct BinderModeTabs: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Binding var selectedMode: String

    private let items = [
        ("My Binder", "rectangle.stack.fill"),
        ("Stacks", "square.stack.3d.up.fill"),
        ("Missions", "flag"),
        ("Friends", "person.2.fill")
    ]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.0) { item in
                Button {
                    selectedMode = item.0
                    if item.0 == "Friends" {
                        viewModel.selectedTab = .profile
                        viewModel.showToast("Opening Friends")
                    } else if item.0 == "Stacks" {
                        viewModel.showToast("Stacks selected")
                    } else if item.0 == "Missions" {
                        viewModel.showToast("Missions selected")
                    } else {
                        viewModel.showToast("\(item.0) selected")
                    }
                } label: {
                    VStack(spacing: 7) {
                        HStack(spacing: 7) {
                            Image(systemName: item.1)
                                .font(.caption.weight(.semibold))
                            Text(item.0)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .foregroundStyle(selectedMode == item.0 ? Color.wildLime : .white.opacity(0.52))
                        .frame(maxWidth: .infinity)

                        Rectangle()
                            .fill(selectedMode == item.0 ? Color.wildLime : .clear)
                            .frame(height: 3)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.0)
                .accessibilityIdentifier("binder.tab.\(item.0.replacingOccurrences(of: " ", with: ""))")
            }
        }
        .padding(.horizontal, 22)
    }
}

struct BinderFilterBar: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Binding var sortLabel: String
    @Binding var layoutMode: BinderLayoutMode

    var body: some View {
        HStack {
            Menu {
                Button("Recent") {
                    sortLabel = "Recent"
                    viewModel.showToast("Sorted by Recent")
                }
                Button("Rarity") {
                    sortLabel = "Rarity"
                    viewModel.showToast("Sorted by Rarity")
                }
                Button("Confidence") {
                    sortLabel = "Confidence"
                    viewModel.showToast("Sorted by Confidence")
                }
            } label: {
                HStack(spacing: 8) {
                    Text(sortLabel)
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.1), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("binder.sortMenu")

            Spacer()

            Text("134 Cards")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)

            Spacer()

            HStack(spacing: 14) {
                Button {
                    layoutMode = .grid
                    viewModel.showToast("Grid view selected")
                } label: {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundStyle(layoutMode == .grid ? Color.wildLime : .white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Grid view")
                .accessibilityIdentifier("binder.layout.grid")

                Button {
                    layoutMode = .list
                    viewModel.showToast("List view selected")
                } label: {
                    Image(systemName: "list.bullet")
                        .foregroundStyle(layoutMode == .list ? Color.wildLime : .white.opacity(0.48))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("List view")
                .accessibilityIdentifier("binder.layout.list")
            }
            .font(.headline.weight(.bold))
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
    }
}

struct BinderBoard: View {
    var primary: WildObservation
    var secondary: WildObservation
    var smallCards: [WildObservation]

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = min(max(proxy.size.width - 34, 326), 368)
            let topSpacing: CGFloat = 10
            let primaryWidth = min((contentWidth - topSpacing) * 0.57, 204)
            let secondaryWidth = contentWidth - primaryWidth - topSpacing
            let smallSpacing: CGFloat = 5
            let smallWidth = (contentWidth - smallSpacing * 3) / 4

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.09, green: 0.09, blue: 0.08),
                                Color.black.opacity(0.9),
                                Color(red: 0.16, green: 0.15, blue: 0.13)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.52), radius: 18, x: 0, y: 14)

                BinderRings()
                    .offset(x: -14)

                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: topSpacing) {
                        BinderFeatureCard(
                            observation: primary,
                            role: .primary,
                            cardWidth: primaryWidth,
                            cardHeight: 276
                        )
                            .zIndex(1)

                        BinderFeatureCard(
                            observation: secondary,
                            role: .secondary,
                            cardWidth: secondaryWidth,
                            cardHeight: 268
                        )
                    }
                    .frame(width: contentWidth, alignment: .center)

                    HStack(spacing: smallSpacing) {
                        ForEach(smallCards.prefix(4)) { observation in
                            BinderSmallCard(
                                observation: observation,
                                cardWidth: smallWidth,
                                cardHeight: 164
                            )
                        }
                    }
                    .frame(width: contentWidth, alignment: .center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.leading, 20)
                .padding(.trailing, 14)
            }
            .clipped()
        }
        .frame(height: 468)
    }
}

struct BinderListBoard: View {
    var cards: [WildObservation]

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.08, green: 0.09, blue: 0.08),
                            Color.black.opacity(0.9),
                            Color(red: 0.14, green: 0.16, blue: 0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.52), radius: 18, x: 0, y: 14)

            BinderRings()
                .offset(x: -14)

            VStack(spacing: 8) {
                ForEach(cards.prefix(6)) { observation in
                    BinderListRow(observation: observation)
                }
            }
            .padding(.vertical, 16)
            .padding(.leading, 26)
            .padding(.trailing, 16)
        }
        .frame(height: 482)
        .accessibilityIdentifier("binder.listBoard")
    }
}

struct BinderListRow: View {
    var observation: WildObservation

    var body: some View {
        HStack(spacing: 11) {
            BundleImage(name: observation.imageName)
                .scaledToFill()
                .frame(width: 58, height: 58)
                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    HoloShine(cornerRadius: 11, starCount: observation.stars)
                        .opacity(observation.stars >= 5 ? 0.24 : 0.1)
                )
                .overlay(
                    RarityMetalBorder(starCount: observation.stars, cornerRadius: 11, lineWidth: 2.2)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text(observation.commonName)
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.94))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Spacer(minLength: 6)

                    StarStrip(count: observation.stars, font: .system(size: 8))
                }

                Text(observation.latinName)
                    .font(.system(size: 9, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                HStack(spacing: 10) {
                    Label(observation.rarity, systemImage: observation.stars >= 5 ? "sparkles" : "leaf.fill")
                        .foregroundStyle(observation.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text("\(Int(observation.confidence * 100))% AI")
                        .foregroundStyle(.white.opacity(0.68))

                    Spacer(minLength: 4)

                    Text(observation.cardDateText)
                        .foregroundStyle(.white.opacity(0.48))
                }
                .font(.system(size: 9, weight: .bold))
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(observation.accentColor.opacity(0.28), lineWidth: 1))
    }
}

struct BinderRings: View {
    var body: some View {
        VStack(spacing: 112) {
            ForEach(0..<3, id: \.self) { _ in
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.95), .gray.opacity(0.52), .white.opacity(0.72)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 5
                    )
                    .frame(width: 34, height: 15)
                    .shadow(color: .black.opacity(0.38), radius: 3, x: 1, y: 2)
            }
        }
    }
}

enum BinderCardRole {
    case primary
    case secondary
}

struct BinderFeatureCard: View {
    var observation: WildObservation
    var role: BinderCardRole
    var cardWidth: CGFloat
    var cardHeight: CGFloat

    private var isPrimary: Bool {
        role == .primary
    }

    private var imageHeight: CGFloat {
        isPrimary ? 144 : 146
    }

    private var cornerRadius: CGFloat {
        isPrimary ? 20 : 16
    }

    private var imageWidth: CGFloat {
        cardWidth - (isPrimary ? 18 : 14)
    }

    private var detailWidth: CGFloat {
        cardWidth - (isPrimary ? 26 : 20)
    }

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(width: imageWidth, height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius - 5, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: cornerRadius - 5, style: .continuous).stroke(.white.opacity(0.52), lineWidth: 1))
                    .overlay(
                        HoloShine(cornerRadius: cornerRadius - 5, starCount: observation.stars)
                            .opacity(observation.stars >= 5 ? (isPrimary ? 0.28 : 0.2) : 0.12)
                    )

                HStack(alignment: .top) {
                    if isPrimary {
                        VStack(spacing: 0) {
                            Text("\(observation.stars)")
                                .font(.title3.weight(.black))
                            Text("STARS")
                                .font(.system(size: 8, weight: .heavy))
                        }
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 44)
                        .background(Color.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.white.opacity(0.62), lineWidth: 1))
                    }

                    StarStrip(
                        count: observation.stars,
                        font: isPrimary ? .caption : .caption2
                    )
                        .padding(.top, isPrimary ? 10 : 4)

                    Spacer()

                    Image(systemName: observation.stars >= 5 ? "pawprint.fill" : "leaf.fill")
                        .font(.caption.weight(.black))
                        .foregroundStyle(observation.stars >= 5 ? Color.wildGold : Color.wildLime)
                        .frame(width: isPrimary ? 34 : 30, height: isPrimary ? 34 : 30)
                        .background(Color.black.opacity(0.82), in: Circle())
                        .overlay(Circle().stroke(observation.accentColor, lineWidth: 1.6))
                }
                .padding(isPrimary ? 10 : 7)
                .frame(width: imageWidth)

                if isPrimary {
                    Label("Tilt to shimmer", systemImage: "hand.tap")
                        .font(.system(size: 9, weight: .bold))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.86))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.36), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).stroke(.white.opacity(0.32), lineWidth: 1))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                        .padding(12)
                }
            }
            .padding(isPrimary ? 9 : 7)
            .padding(.bottom, 0)

            VStack(alignment: .leading, spacing: isPrimary ? 6 : 4) {
                Text(observation.commonName)
                    .font(.system(size: isPrimary ? 17 : 13, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(isPrimary ? 1 : 2)
                    .minimumScaleFactor(0.72)

                Text(observation.latinName)
                .font(.system(size: isPrimary ? 10 : 9, weight: .medium))
                    .italic()
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Rectangle()
                    .fill(.white.opacity(0.14))
                    .frame(height: 1)

                HStack(spacing: isPrimary ? 14 : 8) {
                    BinderMetric(label: "App rarity", value: observation.rarity, tint: observation.accentColor)

                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(width: 1, height: isPrimary ? 38 : 30)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI Confidence")
                            .font(.system(size: isPrimary ? 8 : 7, weight: .bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                        Text("\(Int(observation.confidence * 100))%")
                            .font(.system(size: isPrimary ? 14 : 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                        ProgressView(value: observation.confidence)
                            .tint(Color.wildLime)
                            .frame(width: isPrimary ? 48 : 34)
                    }
                }

                HStack {
                    Text(observation.locality)
                    Spacer()
                    Text(observation.cardDateText)
                }
                .font(.system(size: isPrimary ? 9 : 7, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            }
            .padding(.horizontal, isPrimary ? 11 : 9)
            .padding(.bottom, isPrimary ? 9 : 8)
            .frame(width: detailWidth, alignment: .leading)
        }
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(observation.cardSurface)
        )
        .overlay(
            RarityMetalBorder(
                starCount: observation.stars,
                cornerRadius: cornerRadius,
                lineWidth: isPrimary ? 5 : 4
            )
            .opacity(isPrimary ? 0.9 : 0.78)
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius - 5, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
                .padding(isPrimary ? 7 : 5)
        )
        .shadow(color: observation.accentColor.opacity(isPrimary ? 0.28 : 0.18), radius: isPrimary ? 16 : 10, x: 0, y: isPrimary ? 9 : 6)
    }
}

struct BinderMetric: View {
    var label: String
    var value: String
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.56))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct BinderSmallCard: View {
    var observation: WildObservation
    var cardWidth: CGFloat
    var cardHeight: CGFloat

    private var contentWidth: CGFloat {
        max(cardWidth - 12, 40)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ZStack(alignment: .top) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(width: cardWidth - 10, height: 74)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(observation.accentColor.opacity(0.72), lineWidth: 1))

                HStack(alignment: .top) {
                    StarStrip(count: observation.stars, font: .system(size: 6))
                    Spacer()
                    Image(systemName: observation.stars >= 4 ? "leaf.fill" : "star.fill")
                        .font(.system(size: 8, weight: .black))
                        .foregroundStyle(observation.accentColor)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.82), in: Circle())
                        .overlay(Circle().stroke(observation.accentColor, lineWidth: 1.2))
                }
                .padding(5)
            }

            Text(observation.commonName)
                .font(.system(size: 8, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.leading)
                .frame(width: contentWidth, alignment: .leading)

            Text(observation.latinName)
                .font(.system(size: 6, weight: .medium))
                .italic()
                .foregroundStyle(.white.opacity(0.58))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: contentWidth, alignment: .leading)

            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(height: 1)

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("App rarity")
                        .font(.system(size: 5, weight: .bold))
                        .textCase(.uppercase)
                    Text(observation.rarity)
                        .font(.system(size: 7, weight: .semibold))
                        .foregroundStyle(observation.accentColor)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.58)

                Spacer(minLength: 2)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("AI")
                        .font(.system(size: 5, weight: .bold))
                        .textCase(.uppercase)
                    Text("\(Int(observation.confidence * 100))%")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                }
            }
            .foregroundStyle(.white.opacity(0.58))
            .frame(width: contentWidth)

            HStack {
                Text(observation.locality)
                Spacer()
                Text(observation.shortDateText)
            }
            .font(.system(size: 6, weight: .medium))
            .foregroundStyle(.white.opacity(0.52))
            .lineLimit(1)
            .minimumScaleFactor(0.55)
            .frame(width: contentWidth)
        }
        .padding(5)
        .frame(width: cardWidth, height: cardHeight, alignment: .topLeading)
        .clipped()
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(observation.cardSurface)
        )
        .overlay(
            RarityMetalBorder(starCount: observation.stars, cornerRadius: 13, lineWidth: 2.6)
                .opacity(0.78)
        )
        .shadow(color: observation.accentColor.opacity(0.18), radius: 8, x: 0, y: 5)
    }
}

struct BinderRarityGuideStrip: View {
    private let rows: [(Int, String, String, Color)] = [
        (1, "Common", "Matte", .white.opacity(0.74)),
        (2, "Uncommon", "Colored", .wildGold),
        (3, "Rare", "Metallic", .wildCyan),
        (4, "Seasonal", "Iridescent", .purple.opacity(0.86)),
        (5, "Local Special", "Foil", .orange),
        (6, "City Legend", "Holo Foil", .wildGold)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RARITY GUIDE")
                .font(.system(size: 9, weight: .heavy))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.62))

            HStack(spacing: 0) {
                ForEach(rows, id: \.0) { row in
                    VStack(spacing: 4) {
                        HStack(spacing: 0) {
                            ForEach(0..<row.0, id: \.self) { _ in
                                Image(systemName: "star.fill")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(row.3)
                            }
                        }
                        Text("\(row.0)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundStyle(row.3)
                        Text(row.1)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.72))
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                        Text(row.2)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.56))
                            .lineLimit(1)
                            .minimumScaleFactor(0.64)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(height: 74)
        .background(Color.black.opacity(0.14), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .foregroundStyle(Color.wildGold.opacity(0.42))
        )
    }
}

struct BinderTipRow: View {
    var onTips: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.gen2.radiowaves.left.and.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.wildLime)
                .rotationEffect(.degrees(-12))

            Text("Tilt your phone slowly to see the holo cards shimmer.")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.52))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer()

            Button(action: onTips) {
                Label("Binder Tips", systemImage: "info.circle")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.54))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.wildLime.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).stroke(Color.wildLime.opacity(0.2), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("binder.tips")
        }
    }
}

struct SoftMapScreen: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Query(sort: \WildObservation.createdAt, order: .reverse) private var observations: [WildObservation]
    @State private var cameraPosition: MapCameraPosition = .region(Self.region(center: Self.defaultCoordinate))

    private static let defaultCoordinate = CLLocationCoordinate2D(latitude: 40.6602, longitude: -73.9690)

    private static func region(center: CLLocationCoordinate2D) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.06, longitudeDelta: 0.06)
        )
    }

    var cards: [WildObservation] {
        observations.isEmpty ? WildObservation.samples : observations
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HeaderLockup(title: "Soft Map", subtitle: "Never exact rare-card pins")
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                Map(position: $cameraPosition) {
                    ForEach(cards) { observation in
                        if let coordinate = PrivacyLocationPolicy.softenedCoordinate(for: observation) {
                            Annotation(observation.commonName, coordinate: coordinate) {
                                Image(systemName: PrivacyLocationPolicy.isSensitiveSpecies(observation) ? "shield.lefthalf.filled" : "leaf")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                    .padding(9)
                                    .background(observation.stars >= 5 ? Color.wildCoral : Color.wildInk, in: Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                        }
                    }
                }
                .mapStyle(.standard(elevation: .flat))
                .frame(height: 330)
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                .overlay(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Privacy-safe map", systemImage: "lock")
                            .font(.caption.weight(.bold))
                        Text("Brooklyn nature map")
                            .font(.headline)
                        Text("Sensitive finds show approximate neighborhoods by default.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(16)
                }
                .padding(.horizontal, 16)

                HStack(spacing: 10) {
                    MapActionButton(icon: "location.fill", title: "Near me") {
                        let coordinate = viewModel.locationManager.currentCoordinate ?? Self.defaultCoordinate
                        viewModel.locationManager.requestLocation()
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                            cameraPosition = .region(Self.region(center: coordinate))
                        }
                        viewModel.showToast("Map centered nearby")
                    }
                    .accessibilityIdentifier("map.nearMe")

                    MapActionButton(icon: "camera.viewfinder", title: "Capture") {
                        viewModel.selectedTab = .capture
                        viewModel.showToast("Opening Capture from Map")
                    }
                    .accessibilityIdentifier("map.capture")

                    MapActionButton(icon: "rectangle.stack", title: "Cards") {
                        viewModel.selectedTab = .binder
                        viewModel.showToast("Opening Binder from Map")
                    }
                    .accessibilityIdentifier("map.cards")
                }
                .padding(.horizontal, 16)

                VStack(spacing: 18) {
                    SafetyRow(icon: "shield.checkered", title: "Location softened automatically", detail: "Rare and sensitive finds are widened to a safer area before sharing.")
                    SafetyRow(icon: "viewfinder", title: "Observation first", detail: "The map supports recall and learning, not exact public collection routes.")
                }
                .padding(18)
                .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.wildInk, lineWidth: 1))
                .padding(.horizontal, 16)

                Spacer()
            }
            .background(WildGoBackground())
            .toolbar(.hidden, for: .navigationBar)
        }
        .onReceive(viewModel.locationManager.$currentCoordinate.compactMap { $0 }) { coordinate in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                cameraPosition = .region(Self.region(center: coordinate))
            }
        }
    }
}

struct MapActionButton: View {
    var icon: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.footnote.weight(.heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.74)
                .foregroundStyle(Color.wildInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.wildInk.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

struct ExploreScreen: View {
    @Query(sort: \WildObservation.createdAt, order: .reverse) private var observations: [WildObservation]

    private var cards: [WildObservation] {
        observations.isEmpty ? WildObservation.samples : observations
    }

    private var featuredCard: WildObservation {
        WildObservation(
            commonName: "Blue Jay",
            latinName: "Cyanocitta cristata",
            imageName: "capture-blue-jay-landscape-gen-v2.png",
            rarity: "City Legend",
            finish: "Holo Foil",
            stars: 6,
            confidence: 0.92,
            locality: "Approx location",
            note: "Location softened to protect wildlife.",
            createdAt: Calendar.current.date(from: DateComponents(year: 2026, month: 7, day: 4)) ?? .now
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ComboHeroBand(featured: featuredCard)

                    VStack(spacing: 18) {
                        BinderPreviewSection(cards: Array(cards.prefix(5)))
                        FriendsFindSection()
                        WildlifeSafetyBanner()
                    }
                    .padding(.horizontal, 14)
                    .padding(.top, 18)
                    .padding(.bottom, 120)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                    .offset(y: -18)
                }
            }
            .background(Color.wildInk)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ComboHeroBand: View {
    var featured: WildObservation

    var body: some View {
        VStack(spacing: 18) {
            DashboardTopBar()
                .padding(.top, 8)

            DashboardHeroCard(observation: featured)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 34)
        .background(
            ZStack {
                BundleImage(name: featured.imageName)
                    .scaledToFill()
                    .blur(radius: 14)
                    .saturation(1.1)
                    .opacity(0.34)
                LinearGradient(
                    colors: [Color.wildInk, .black.opacity(0.9), Color.wildInk.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                RadialGradient(
                    colors: [Color.wildLime.opacity(0.18), .clear],
                    center: .topLeading,
                    startRadius: 20,
                    endRadius: 320
                )
            }
            .ignoresSafeArea()
        )
    }
}

struct DashboardTopBar: View {
    @EnvironmentObject private var viewModel: WildGoViewModel

    var body: some View {
        HStack(spacing: 8) {
            Text("Wild Go")
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(width: 106, alignment: .leading)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "leaf.fill")
                        .font(.caption)
                        .foregroundStyle(Color.wildLime)
                        .offset(x: 10, y: -2)
                }

            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1, height: 54)
                .padding(.leading, 8)

            VStack(alignment: .leading, spacing: 7) {
                Button {
                    viewModel.showToast("Collection selector opened")
                } label: {
                    HStack(spacing: 5) {
                        Text("NYC Collection")
                            .font(.subheadline.weight(.bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.heavy))
                    }
                    .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("explore.collectionSelector")

                ProgressView(value: 0.49)
                    .tint(Color.wildLime)
                    .frame(width: 96)

                Text("243 / 500 species")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            LevelBadge()

            Button {
                viewModel.showToast("Notifications opened")
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                    Circle()
                        .fill(Color.wildCoral)
                        .frame(width: 8, height: 8)
                        .offset(x: 2, y: 2)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("explore.notifications")
        }
    }
}

struct LevelBadge: View {
    var body: some View {
        VStack(spacing: 0) {
            Text("Lv.")
                .font(.caption2.weight(.bold))
            Text("23")
                .font(.title3.weight(.black))
        }
        .foregroundStyle(.white)
        .frame(width: 52, height: 52)
        .background(
            Hexagon()
                .stroke(Color.wildLime, lineWidth: 2)
                .background(Hexagon().fill(Color.wildInk.opacity(0.82)))
        )
    }
}

struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let width = rect.width
        let height = rect.height
        let points = [
            CGPoint(x: width * 0.5, y: 0),
            CGPoint(x: width, y: height * 0.25),
            CGPoint(x: width, y: height * 0.75),
            CGPoint(x: width * 0.5, y: height),
            CGPoint(x: 0, y: height * 0.75),
            CGPoint(x: 0, y: height * 0.25)
        ]

        var path = Path()
        path.move(to: points[0])
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }
}

struct DashboardHeroCard: View {
    var observation: WildObservation

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(height: 282)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay(HoloShine(cornerRadius: 22, starCount: observation.stars).opacity(0.58))

                VStack(spacing: 0) {
                    Spacer()
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(observation.commonName)
                                .font(.system(size: 30, weight: .bold, design: .serif))
                                .foregroundStyle(.white)
                            Text(observation.latinName)
                                .font(.subheadline.weight(.semibold))
                                .italic()
                                .foregroundStyle(.white)
                        }

                        Spacer()

                        Label("Approx location", systemImage: "location")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(.black.opacity(0.42), in: Capsule())
                    }
                    .padding(14)
                    .background(
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.72)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
            }

            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Text("6\nSTARS")
                        .font(.caption.weight(.black))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(Color.wildInk, in: Hexagon())
                        .overlay(Hexagon().stroke(Color.wildGold, lineWidth: 1.5))

                    StarStrip(count: observation.stars)
                        .scaleEffect(1.32)

                    Spacer()

                    Text("CITY LEGEND")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(.black.opacity(0.58), in: Capsule())
                }

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("APP RARITY")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.62))
                        Text(observation.rarity)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.wildGold)
                    }

                    Rectangle()
                        .fill(Color.wildGold.opacity(0.42))
                        .frame(width: 1, height: 34)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI CONFIDENCE")
                            .font(.caption2.weight(.heavy))
                            .foregroundStyle(.white.opacity(0.62))
                        HStack(spacing: 8) {
                            Text("\(Int(observation.confidence * 100))%")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.white)
                            ProgressView(value: observation.confidence)
                                .tint(Color.wildLime)
                                .frame(width: 58)
                        }
                    }

                    Spacer()
                }

                Label("Location softened to protect wildlife", systemImage: "lock")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.36), in: Capsule())
            }
            .padding(14)
        }
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.76))
                HoloShine(cornerRadius: 28, starCount: observation.stars)
                    .opacity(0.5)
            }
        )
        .overlay(
            RarityMetalBorder(starCount: observation.stars, cornerRadius: 28, lineWidth: 7)
                .opacity(0.88)
        )
        .shadow(color: .black.opacity(0.42), radius: 24, x: 0, y: 16)
    }
}

struct BinderPreviewSection: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    var cards: [WildObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your Binder")
                    .font(.title3.weight(.bold))
                Text("134 cards")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.wildGreen)
                Spacer()
                Button {
                    viewModel.selectedTab = .binder
                    viewModel.showToast("Opening Binder")
                } label: {
                    Label("See all", systemImage: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.wildInk)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("explore.binderSeeAll")
            }
            .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(cards) { card in
                        Button {
                            viewModel.showToast("\(card.commonName) card selected")
                        } label: {
                            MiniBinderCard(observation: card)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("explore.card.\(card.commonName.replacingOccurrences(of: " ", with: ""))")
                    }
                }
                .padding(.horizontal, 4)
                .padding(.bottom, 6)
            }
        }
    }
}

struct MiniBinderCard: View {
    var observation: WildObservation

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack(alignment: .topLeading) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(width: 78, height: 82)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text("\(observation.stars)★")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.wildInk.opacity(0.86), in: Capsule())
                    .padding(5)
            }

            Text(observation.commonName)
                .font(.caption.weight(.heavy))
                .lineLimit(2)
                .foregroundStyle(.white)

            Label(shortRarity(observation.rarity), systemImage: "leaf")
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(observation.stars >= 4 ? Color.wildGold : Color.wildLime)
        }
        .padding(7)
        .frame(width: 92, height: 132, alignment: .topLeading)
        .background(miniGradient, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(observation.stars >= 5 ? Color.wildGold : Color.wildLime.opacity(0.7), lineWidth: 1.2))
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 5)
    }

    private var miniGradient: LinearGradient {
        LinearGradient(
            colors: observation.stars >= 5
                ? [Color.wildInk, Color(red: 0.47, green: 0.23, blue: 0.05)]
                : [Color.wildInk, Color.wildGreen.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func shortRarity(_ value: String) -> String {
        switch value {
        case "Local Special":
            "Special"
        case "City Legend":
            "Legend"
        default:
            value
        }
    }
}

struct FriendsFindSection: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @State private var isShowingShareSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Friends' Finds")
                    .font(.title3.weight(.bold))
                Spacer()
                Button {
                    viewModel.selectedTab = .profile
                    viewModel.showToast("Opening Friends")
                } label: {
                    Label("See all", systemImage: "chevron.right")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.wildInk)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("explore.friendsSeeAll")
            }

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        BundleImage(name: "friends-maya-gen.png")
                            .scaledToFill()
                            .frame(width: 56, height: 56)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.wildGreen, lineWidth: 2))

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Maya unlocked a 5-star\nMonarch Butterfly")
                                .font(.subheadline.weight(.semibold))
                                .lineLimit(2)
                            Text("Prospect Park · 2h ago")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text("+50 XP")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(Color.wildCoral)
                }

                Spacer(minLength: 4)

                FriendStackPreview()
            }

            HStack(spacing: 10) {
                Button {
                    isShowingShareSheet = true
                    viewModel.showToast("Opening share sheet")
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.comboCompact(.filled))
                .accessibilityIdentifier("explore.shareFriendFind")

                Button {
                    viewModel.selectedTab = .profile
                    viewModel.showToast("Added to Showcase")
                } label: {
                    Label("Showcase", systemImage: "star")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.comboCompact(.outline))
                .accessibilityIdentifier("explore.showcaseFriendFind")
            }
        }
        .padding(16)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .sheet(isPresented: $isShowingShareSheet) {
            ShareSheet(activityItems: ["Wild Go friends find: Maya unlocked a 5-star Monarch Butterfly in Prospect Park."])
        }
    }
}

struct FriendStackPreview: View {
    var body: some View {
        ZStack {
            MiniStackCard(imageName: "binder-flower-gen.png", stars: 2)
                .rotationEffect(.degrees(-8))
                .offset(x: -24, y: 6)
            MiniStackCard(imageName: "binder-squirrel-gen.png", stars: 3)
                .rotationEffect(.degrees(-1))
                .offset(x: -4, y: 0)
            MiniStackCard(imageName: "binder-butterfly-gen.png", stars: 5)
                .rotationEffect(.degrees(9))
                .offset(x: 20, y: -1)
        }
        .frame(width: 126, height: 98)
    }
}

struct MiniStackCard: View {
    var imageName: String
    var stars: Int

    var body: some View {
        BundleImage(name: imageName)
            .scaledToFill()
            .frame(width: 64, height: 82)
            .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
            .overlay(alignment: .topLeading) {
                Text("\(stars)★")
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(Color.wildInk.opacity(0.86), in: Capsule())
                    .padding(4)
            }
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.wildGold, lineWidth: 1.2))
            .shadow(color: .black.opacity(0.2), radius: 6, x: 0, y: 4)
    }
}

struct WildlifeSafetyBanner: View {
    @EnvironmentObject private var viewModel: WildGoViewModel

    var body: some View {
        Button {
            viewModel.showToast("Safety guide opened")
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "leaf")
                    .font(.headline.weight(.bold))
                Text("Rarity is discovery difficulty, not conservation status.")
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(Color.wildInk)
            .padding(14)
            .background(Color.wildMist, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("explore.safetyGuide")
    }
}

extension ButtonStyle where Self == ComboCompactButtonStyle {
    static func comboCompact(_ kind: ComboCompactButtonStyle.Kind) -> ComboCompactButtonStyle {
        ComboCompactButtonStyle(kind: kind)
    }
}

struct ComboCompactButtonStyle: ButtonStyle {
    enum Kind {
        case filled
        case outline
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .padding(.vertical, 11)
            .padding(.horizontal, 12)
            .foregroundStyle(kind == .filled ? .white : Color.wildInk)
            .background(kind == .filled ? Color.wildInk : Color.clear, in: Capsule())
            .overlay(Capsule().stroke(Color.wildInk.opacity(kind == .filled ? 0 : 0.4), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct ProfileScreen: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WildObservation.createdAt, order: .reverse) private var observations: [WildObservation]
    @State private var isShowcaseFlipped = false
    @State private var isShowcaseDropped = false
    @State private var isShowingAuthSheet = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 8) {
                    FriendsHeader()
                    FriendsProfileStats(onAccountTap: {
                        isShowingAuthSheet = true
                        viewModel.showToast("Account sheet opened")
                    })
                    if auth.isSignedIn {
                        SignedInAccountBanner(email: auth.session?.email ?? "Signed in")
                    }
                    FriendsShowcaseDeck(
                        isFlipped: isShowcaseFlipped,
                        isShowcaseDropped: isShowcaseDropped
                    )
                    FriendsShowcaseControls()
                        .environment(\.showcaseControlState, ShowcaseControlState(
                            isFlipped: $isShowcaseFlipped,
                            isDropped: $isShowcaseDropped
                        ))
                        .padding(.top, -10)
                    FriendsActivitySection()
                        .padding(.top, -12)
                }
                .padding(.horizontal, 18)
                .padding(.top, -16)
                .padding(.bottom, 114)
            }
            .background(Color(.systemBackground))
            .safeAreaInset(edge: .bottom) {
                FriendsActionRail(isShowcaseDropped: $isShowcaseDropped)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 16)
            }
            .toolbar(.hidden, for: .navigationBar)
            .statusBarHidden(true)
        }
        .sheet(isPresented: $isShowingAuthSheet) {
            AuthSheet()
                .environmentObject(auth)
                .environmentObject(viewModel)
        }
        .task(id: auth.session?.userId) {
            guard auth.isSignedIn else { return }
            do {
                let session = try await auth.validSession()
                let summary = await CollectionSyncService.syncCollection(
                    observations,
                    modelContext: modelContext,
                    session: session
                )
                if summary.changedCount > 0 {
                    viewModel.showToast(summary.toastMessage)
                }
            } catch {
                viewModel.showToast(error.localizedDescription)
            }
        }
    }
}

struct SignedInAccountBanner: View {
    var email: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(Color.wildGreen)
            VStack(alignment: .leading, spacing: 2) {
                Text("Collection synced")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.wildInk)
                Text(email)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.wildMist.opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct AuthSheet: View {
    @EnvironmentObject private var auth: SupabaseAuthService
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var isCreatingAccount = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                } header: {
                    Text(isCreatingAccount ? "Create account" : "Sign in")
                } footer: {
                    Text("Sign in to sync your binder across devices. Configure SUPABASE_URL and SUPABASE_ANON_KEY in ios/debug.xcconfig first.")
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(Color.wildCoral)
                    }
                }

                Section {
                    Button(isCreatingAccount ? "Create account" : "Sign in") {
                        Task { await submit() }
                    }
                    .disabled(email.isEmpty || password.count < 6 || auth.isBusy)

                    Button(isCreatingAccount ? "Already have an account? Sign in" : "Need an account? Create one") {
                        isCreatingAccount.toggle()
                        errorMessage = nil
                    }
                    .font(.footnote.weight(.semibold))

                    if auth.isSignedIn {
                        Button("Sign out", role: .destructive) {
                            auth.signOut()
                            viewModel.showToast("Signed out")
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Wild Go Account")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    @MainActor
    private func submit() async {
        errorMessage = nil
        do {
            if isCreatingAccount {
                try await auth.signUp(email: email, password: password)
            } else {
                try await auth.signIn(email: email, password: password)
            }
            if auth.isSignedIn {
                viewModel.showToast(auth.statusMessage ?? "Signed in")
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct FriendsHeader: View {
    @EnvironmentObject private var viewModel: WildGoViewModel

    var body: some View {
        HStack(alignment: .center) {
            Text("Wild Go")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(Color.wildInk)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "leaf.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.wildGreen)
                        .offset(x: 10, y: -2)
                }

            Spacer()

            Text("Friends' Finds")
                .font(.system(size: 23, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .lineLimit(1)
                .minimumScaleFactor(0.78)

            Spacer()

            Button {
                viewModel.showToast("Notifications opened")
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 44, height: 44)
                        .background(.white, in: Circle())
                        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)

                    Circle()
                        .fill(Color.wildCoral)
                        .frame(width: 9, height: 9)
                        .offset(x: -4, y: 5)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Notifications")
            .accessibilityIdentifier("profile.notifications")
        }
    }
}

struct FriendsProfileStats: View {
    var onAccountTap: () -> Void = {}

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onAccountTap) {
                ZStack(alignment: .bottomTrailing) {
                    BundleImage(name: "friends-leo-gen.png")
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.wildGreen, lineWidth: 2.5))

                    Text("24")
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white)
                        .frame(width: 26, height: 26)
                        .background(Color.wildGreen, in: Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.account")

            VStack(alignment: .leading, spacing: 8) {
                Text("Level 24  •  City Explorer")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                ProgressView(value: 0.78)
                    .tint(Color.wildGreen)
                    .frame(width: 128)

                HStack(spacing: 4) {
                    Text("2,340")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.wildGreen)
                    Text("/ 3,000 XP")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 12) {
                FriendsStat(icon: "rectangle.stack", value: "248", label: "Cards")
                Rectangle()
                    .fill(Color(.separator))
                    .frame(width: 1, height: 52)
                FriendsStat(icon: "mappin.circle", value: "34", label: "Places")
            }
        }
    }
}

struct FriendsStat: View {
    var icon: String
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: icon)
                .font(.title3.weight(.medium))
                .foregroundStyle(Color.wildGreen)
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.black)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct FriendsShowcaseDeck: View {
    var isFlipped: Bool
    var isShowcaseDropped: Bool

    var body: some View {
        ZStack(alignment: .center) {
            if isShowcaseDropped {
                Capsule()
                    .stroke(style: StrokeStyle(lineWidth: 1.6, dash: [8, 8]))
                    .foregroundStyle(Color.wildGreen.opacity(0.34))
                    .frame(width: 254, height: 74)
                    .offset(x: 26, y: 132)
                    .transition(.scale.combined(with: .opacity))
            }

            FriendsSmallDeckCard(
                imageName: "binder-flower-gen.png",
                title: "Oxeye Daisy",
                subtitle: "Leucanthemum",
                stars: 1,
                tint: Color(red: 0.18, green: 0.35, blue: 0.24)
            )
            .rotationEffect(.degrees(-11))
            .offset(x: -116, y: 22)

            FriendsSmallDeckCard(
                imageName: "binder-squirrel-gen.png",
                title: "Eastern Gray",
                subtitle: "Sciurus carolinensis",
                stars: 3,
                tint: Color(red: 0.54, green: 0.42, blue: 0.22)
            )
            .rotationEffect(.degrees(-6))
            .offset(x: -76, y: -4)

            FriendsHeroShowcaseCard(isFlipped: isFlipped)
                .rotationEffect(.degrees(isShowcaseDropped ? 0.6 : 3.2))
                .offset(x: isShowcaseDropped ? 18 : 28, y: isShowcaseDropped ? -15 : -5)
                .scaleEffect(isShowcaseDropped ? 0.96 : 1)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 326)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isFlipped)
        .animation(.spring(response: 0.46, dampingFraction: 0.78), value: isShowcaseDropped)
    }
}

struct FriendsSmallDeckCard: View {
    var imageName: String
    var title: String
    var subtitle: String
    var stars: Int
    var tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(stars)★")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.black.opacity(0.74), in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomTrailingRadius: 14))

            Spacer()

            Text(title)
                .font(.system(size: 15, weight: .heavy, design: .serif))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text(subtitle)
                .font(.system(size: 10, weight: .medium, design: .serif))
                .italic()
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
                .minimumScaleFactor(0.64)

            StarStrip(count: stars)
                .font(.caption)
        }
        .padding(12)
        .frame(width: 118, height: 242)
        .background {
            ZStack {
                BundleImage(name: imageName)
                    .scaledToFill()
                    .overlay(.black.opacity(0.24))
                LinearGradient(
                    colors: [.clear, tint.opacity(0.74), .black.opacity(0.82)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(tint.opacity(0.88), lineWidth: 3))
        .shadow(color: .black.opacity(0.22), radius: 12, x: 0, y: 8)
    }
}

struct FriendsHeroShowcaseCard: View {
    var isFlipped: Bool = false

    var body: some View {
        ZStack {
            frontCard
                .opacity(isFlipped ? 0 : 1)
                .rotation3DEffect(.degrees(isFlipped ? -180 : 0), axis: (x: 0, y: 1, z: 0), perspective: 0.62)

            FriendsShowcaseBack()
                .opacity(isFlipped ? 1 : 0)
                .rotation3DEffect(.degrees(isFlipped ? 0 : 180), axis: (x: 0, y: 1, z: 0), perspective: 0.62)
        }
        .animation(.spring(response: 0.46, dampingFraction: 0.82), value: isFlipped)
    }

    private var frontCard: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                BundleImage(name: "binder-cardinal-gen.png")
                    .scaledToFill()
                    .frame(height: 208)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(HoloShine(cornerRadius: 18, starCount: 6).opacity(0.3))

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("6★")
                            .font(.title2.weight(.black))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.62), in: UnevenRoundedRectangle(topLeadingRadius: 18, bottomTrailingRadius: 14))

                        Spacer()

                        Text("URBAN LEGEND")
                            .font(.caption.weight(.heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.76), in: Capsule())
                    }

                    Spacer()

                    Text("Northern Cardinal")
                        .font(.system(size: 23, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Text("Cardinalis cardinalis")
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.white.opacity(0.92))
                    StarStrip(count: 6)
                        .font(.headline)
                }
                .padding(12)

                PhotoStamp()
                    .frame(width: 40, height: 40)
                    .padding(.trailing, 12)
                    .padding(.bottom, 92)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            HStack(spacing: 0) {
                FriendsCardMetric(icon: "sparkles", label: "Rarity (App)", value: "Six Star", detail: "Extremely rare find")
                Rectangle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: 1, height: 62)
                FriendsCardMetric(icon: "brain.head.profile", label: "AI Confidence", value: "92%", detail: "")
                Rectangle()
                    .fill(Color.white.opacity(0.42))
                    .frame(width: 1, height: 62)
                FriendsCardMetric(icon: "calendar", label: "Captured", value: "Today", detail: "7:42 AM")
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(.white.opacity(0.36))

            Label("Location Privacy: City Level", systemImage: "lock")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.wildInk)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(.white.opacity(0.42), in: Capsule())
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
        }
        .frame(width: 228, height: 338)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.white.opacity(0.86))
                HoloShine(cornerRadius: 24, starCount: 6)
                    .opacity(0.5)
            }
        )
        .overlay(
            RarityMetalBorder(starCount: 6, cornerRadius: 24, lineWidth: 7)
                .opacity(0.95)
        )
        .shadow(color: .black.opacity(0.2), radius: 18, x: 0, y: 12)
    }
}

struct FriendsShowcaseBack: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Showcase Back", systemImage: "sparkles")
                    .font(.caption.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(Color.wildInk)
                Spacer()
                Text("6★")
                    .font(.title3.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.wildInk, in: Capsule())
            }

            Text("Northern Cardinal")
                .font(.system(size: 23, weight: .bold, design: .serif))
                .foregroundStyle(Color.wildInk)
                .lineLimit(1)
                .minimumScaleFactor(0.76)
            Text("Cardinalis cardinalis")
                .font(.subheadline.weight(.medium))
                .italic()
                .foregroundStyle(Color.wildGreen)

            VStack(alignment: .leading, spacing: 8) {
                FriendsBackFact(icon: "tree", label: "Habitat", value: "Parks, gardens, shrubby edges")
                FriendsBackFact(icon: "calendar", label: "Best season", value: "Year-round urban resident")
                FriendsBackFact(icon: "lock", label: "Privacy", value: "Shared at city level only")
                FriendsBackFact(icon: "person.2", label: "From Leo", value: "Showcase card can be sent or compared")
            }

            Spacer()

            Label("Flip again to return to the photo card", systemImage: "rectangle.2.swap")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.wildGreen, in: Capsule())
        }
        .padding(16)
        .frame(width: 228, height: 338)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color.white.opacity(0.9))
                HoloShine(cornerRadius: 24, starCount: 6)
                    .opacity(0.36)
            }
        )
        .overlay(
            RarityMetalBorder(starCount: 6, cornerRadius: 24, lineWidth: 7)
                .opacity(0.64)
        )
        .shadow(color: .black.opacity(0.18), radius: 18, x: 0, y: 12)
    }
}

struct FriendsBackFact: View {
    var icon: String
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.wildGreen)
                .frame(width: 18, height: 18)
                .background(Color.wildMist, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2.weight(.heavy))
                    .textCase(.uppercase)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.wildInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)
            }
        }
    }
}

struct PhotoStamp: View {
    var body: some View {
        Circle()
            .stroke(.white.opacity(0.92), lineWidth: 1.3)
            .overlay {
                VStack(spacing: 1) {
                    Text("MY PHOTO")
                        .font(.system(size: 5, weight: .black))
                    Image(systemName: "camera.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text("BROOKLYN, NY")
                        .font(.system(size: 4.5, weight: .black))
                }
                .foregroundStyle(.white.opacity(0.94))
                .rotationEffect(.degrees(-18))
            }
    }
}

struct FriendsShowcaseControls: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Environment(\.showcaseControlState) private var showcaseState

    var body: some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    showcaseState.isDropped.wrappedValue.toggle()
                }
                viewModel.showToast(showcaseState.isDropped.wrappedValue ? "Added to Showcase" : "Removed from Showcase")
            } label: {
                Label(showcaseState.isDropped.wrappedValue ? "In showcase" : "Drag to showcase", systemImage: showcaseState.isDropped.wrappedValue ? "checkmark.circle" : "hand.raised")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(showcaseState.isDropped.wrappedValue ? Color.wildGreen : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .overlay(
                        Capsule()
                            .stroke(style: StrokeStyle(lineWidth: 1.4, dash: [7, 7]))
                            .foregroundStyle(Color.wildGreen.opacity(showcaseState.isDropped.wrappedValue ? 0.6 : 0.26))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.dragToShowcase")

            Button {
                let willShowBack = !showcaseState.isFlipped.wrappedValue
                withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                    showcaseState.isFlipped.wrappedValue = willShowBack
                }
                viewModel.showToast(willShowBack ? "Showcase card flipped" : "Showcase front shown")
            } label: {
                Label("Flip", systemImage: "rectangle.2.swap")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 9)
                    .background(Color.black.opacity(0.78), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.flipShowcase")
        }
        .padding(.horizontal, 28)
    }
}

struct ShowcaseControlState {
    var isFlipped: Binding<Bool>
    var isDropped: Binding<Bool>

    static let inactive = ShowcaseControlState(isFlipped: .constant(false), isDropped: .constant(false))
}

private struct ShowcaseControlStateKey: EnvironmentKey {
    static let defaultValue = ShowcaseControlState.inactive
}

extension EnvironmentValues {
    var showcaseControlState: ShowcaseControlState {
        get { self[ShowcaseControlStateKey.self] }
        set { self[ShowcaseControlStateKey.self] = newValue }
    }
}

struct FriendsCardMetric: View {
    var icon: String
    var label: String
    var value: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(label, systemImage: icon)
                .font(.system(size: 7, weight: .bold))
                .foregroundStyle(Color.blue)
                .lineLimit(1)
                .minimumScaleFactor(0.45)
            Text(value)
                .font(.system(size: 13, weight: .black))
                .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.36))
                .lineLimit(1)
                .minimumScaleFactor(0.62)
            if !detail.isEmpty {
                Text(detail)
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color(red: 0.08, green: 0.08, blue: 0.36).opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.52)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 7)
    }
}

struct FriendsActivitySection: View {
    @EnvironmentObject private var viewModel: WildGoViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack {
                Text("Friend Activity")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                Spacer()
                Button {
                    viewModel.showToast("All friend activity opened")
                } label: {
                    Text("See all")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.wildGreen)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile.activitySeeAll")
            }

            Button {
                viewModel.showToast("Maya's Monarch Butterfly opened")
            } label: {
                FriendActivityRow(
                    avatar: "friends-maya-gen.png",
                    title: "Maya unlocked a 5-Star!",
                    subtitle: "Monarch Butterfly",
                    detail: "Prospect Park · 2h ago",
                    cardImage: "friends-butterfly-gen.png",
                    stars: "5★",
                    xp: "+50 XP"
                )
                .padding(.top, 2)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.activity.maya")

            Divider()

            Button {
                viewModel.showToast("Leo's Honey Mushroom opened")
            } label: {
                FriendActivityRow(
                    avatar: "friends-leo-gen.png",
                    title: "Leo added a new card",
                    subtitle: "Honey Mushroom",
                    detail: "Bushwick · 3h ago",
                    cardImage: "friends-mushroom-gen.png",
                    stars: "2★",
                    xp: "+20 XP"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("profile.activity.leo")
        }
        .padding(.top, 2)
    }
}

struct FriendActivityRow: View {
    var avatar: String
    var title: String
    var subtitle: String
    var detail: String
    var cardImage: String
    var stars: String
    var xp: String

    var body: some View {
        HStack(spacing: 9) {
            BundleImage(name: avatar)
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.wildCoral.opacity(0.8), lineWidth: 2.5))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)

            Spacer(minLength: 2)

            ZStack(alignment: .topTrailing) {
                BundleImage(name: cardImage)
                    .scaledToFill()
                    .frame(width: 50, height: 38)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.wildCoral, lineWidth: 2))

                Text(stars)
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.76), in: Capsule())
                    .offset(x: 6, y: -7)
            }

            Text(xp)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.wildCoral)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(Color.wildCoral.opacity(0.14), in: Capsule())
        }
    }
}

struct FriendsActionRail: View {
    @EnvironmentObject private var viewModel: WildGoViewModel
    @Binding var isShowcaseDropped: Bool

    var body: some View {
        HStack(spacing: 0) {
            FriendsRailButton(icon: "paperplane", title: "Send Card") {
                viewModel.showToast("Send Card opened")
            }
            RailDivider()
            FriendsRailButton(icon: "rectangle.stack", title: "Compare") {
                viewModel.showToast("Compare mode opened")
            }
            Button {
                viewModel.selectedTab = .capture
                viewModel.showToast("Opening Capture")
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.wildGreen)
                        .frame(width: 48, height: 48)
                        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 5)
                    Image(systemName: "camera.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 64)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Capture")
            .accessibilityIdentifier("profile.rail.capture")
            FriendsRailButton(icon: "star", title: "Add to Showcase") {
                withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                    isShowcaseDropped = true
                }
                viewModel.showToast("Added to Showcase")
            }
            RailDivider()
            FriendsRailButton(icon: "person.2", title: "Trade Later") {
                viewModel.showToast("Trade reminder saved")
            }
        }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(.black.opacity(0.08), lineWidth: 1))
        .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: 9)
    }
}

struct FriendsRailButton: View {
    var icon: String
    var title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.wildGreen)
                Text(title)
                    .font(.system(size: 8.2, weight: .medium))
                    .foregroundStyle(.black)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .allowsTightening(true)
            }
            .frame(width: 73, height: 52)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityIdentifier("profile.rail.\(title.replacingOccurrences(of: " ", with: ""))")
    }
}

struct RailDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 32)
    }
}

struct MissionPanel: View {
    private let missions = [
        ("Morning Flyers", "Capture one bird before 10 AM", "2 / 3", "bolt"),
        ("Yellow Bloom", "Find one yellow flower", "1 / 1", "leaf"),
        ("Soft Map", "Record from 2 approximate areas", "1 / 2", "map")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Nearby", systemImage: "binoculars")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.wildInk, in: Capsule())
                .foregroundStyle(.white)

            Text("Three gentle missions for today")
                .font(.title2.weight(.bold))

            Text("Wild Go nudges everyday observation without turning the map into a race.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(missions, id: \.0) { mission in
                HStack(spacing: 12) {
                    Image(systemName: mission.3)
                        .font(.headline)
                        .frame(width: 34, height: 34)
                        .background(Color.wildMist, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text(mission.0)
                            .font(.subheadline.weight(.bold))
                        Text(mission.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Text(mission.2)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(.white, in: Capsule())
                }
                .padding(10)
                .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
        .padding(18)
        .background(.white.opacity(0.82), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct HeaderLockup: View {
    enum Scheme {
        case light
        case dark
    }

    var title: String
    var subtitle: String
    var colorScheme: Scheme = .light

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Label("Wild Go", systemImage: "leaf")
                    .font(.caption.weight(.heavy))
                Text(title)
                    .font(.title.bold())
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(colorScheme == .dark ? .white.opacity(0.86) : .secondary)
            }
            Spacer()
            Text("Lv. 23")
                .font(.caption.weight(.bold))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(colorScheme == .dark ? 0.22 : 0.72), in: Capsule())
        }
        .foregroundStyle(colorScheme == .dark ? Color.white : Color.wildInk)
    }
}

enum CardSize {
    case hero
    case feature
    case compact
}

struct CollectibleCard: View {
    var observation: WildObservation
    var size: CardSize

    var body: some View {
        if size == .hero {
            HeroCollectibleCard(observation: observation)
        } else {
            standardCard
        }
    }

    private var standardCard: some View {
        VStack(alignment: .leading, spacing: size == .compact ? 8 : 12) {
            HStack {
                Text(observation.rarity)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.black, in: Capsule())
                    .foregroundStyle(.white)
                Spacer()
                StarStrip(count: observation.stars)
            }

            ZStack(alignment: .bottom) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .frame(height: imageHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(.white.opacity(0.74), lineWidth: 1))

                Label(observation.locality, systemImage: "location")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity)
                    .background(.white.opacity(0.86), in: Capsule())
                    .padding(10)
            }

            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(observation.commonName)
                        .font(size == .compact ? .headline.weight(.black) : .title3.weight(.black))
                        .lineLimit(2)
                    Text(observation.latinName)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.wildGreen)
                }

                Spacer()

                Text(observation.finish)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.75), in: Capsule())
                    .overlay(Capsule().stroke(Color.wildInk, lineWidth: 1))
            }

            if size != .compact {
                HStack(spacing: 8) {
                    MetricPill(label: "AI Match", value: "\(Int(observation.confidence * 100))%")
                    MetricPill(label: "First Seen", value: observation.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .padding(size == .compact ? 10 : 16)
        .frame(maxWidth: .infinity)
        .background(cardGradient, in: RoundedRectangle(cornerRadius: size == .hero ? 28 : 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: size == .hero ? 28 : 22).stroke(.white.opacity(0.7), lineWidth: 1))
        .shadow(color: .black.opacity(size == .hero ? 0.28 : 0.12), radius: size == .hero ? 26 : 14, x: 0, y: size == .hero ? 16 : 8)
        .frame(maxWidth: size == .hero ? 308 : nil)
    }

    private var imageHeight: CGFloat {
        switch size {
        case .hero:
            222
        case .feature:
            170
        case .compact:
            116
        }
    }

    private var cardGradient: LinearGradient {
        LinearGradient(
            colors: observation.stars >= 5
                ? [Color.wildGold, Color.wildMist, Color.wildCyan]
                : [Color.wildPaper, Color.wildMist.opacity(0.9)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct HeroCollectibleCard: View {
    var observation: WildObservation
    var localityLabel: String? = nil
    var cardWidth: CGFloat = 306
    var foilTilt: CGPoint = .zero

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text(observation.rarity.uppercased())
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.black.opacity(0.48), in: Capsule())
                    .overlay(Capsule().stroke(Color.wildGold.opacity(0.66), lineWidth: 1))

                Spacer()

                StarStrip(count: observation.stars, font: .headline)
            }
            .padding(.horizontal, 6)

            ZStack(alignment: .bottomTrailing) {
                BundleImage(name: observation.imageName)
                    .scaledToFill()
                    .scaleEffect(1.35)
                    .frame(height: 224)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.wildGold.opacity(0.92), lineWidth: 1.5))
                    .overlay(
                        RarityMetalSurface(
                            starCount: observation.stars,
                            cornerRadius: 18,
                            tilt: foilTilt
                        )
                        .opacity(observation.stars >= 5 ? 0.56 : 0.18)
                    )

                Label(localityLabel ?? PrivacyLocationPolicy.displayLocality(for: observation), systemImage: "location")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(.black.opacity(0.42), in: Capsule())
                    .overlay(Capsule().stroke(.white.opacity(0.38), lineWidth: 1))
                    .padding(12)
            }
            .padding(.horizontal, 5)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .bottom, spacing: 9) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(observation.commonName)
                            .font(.system(size: 26, weight: .bold, design: .serif))
                            .foregroundStyle(.white)
                        Text(observation.latinName)
                            .font(.subheadline)
                            .italic()
                            .foregroundStyle(Color.wildLime)
                    }

                    Spacer(minLength: 2)

                    Divider()
                        .overlay(Color.wildGold.opacity(0.34))
                        .frame(height: 68)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("Likely match")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.wildGold)
                        Text("\(Int(observation.confidence * 100))%")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        ProgressView(value: observation.confidence)
                            .tint(Color.wildLime)
                            .frame(width: 64)
                        Text("AI confidence")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.62))
                    }
                }

                Text(observation.note)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.86))
                    .lineSpacing(2)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)

                Divider()
                    .overlay(Color.wildGold.opacity(0.36))

                HStack(alignment: .center, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label("First seen", systemImage: "leaf")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.wildLime)
                            .lineLimit(1)

                        Text("Jul 4, 2026 • 8:47 AM")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.78))
                            .lineLimit(1)
                    }

                    Spacer()

                    Text("#WGO-26-0704-1178")
                        .font(.system(size: 8, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.wildGold)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .layoutPriority(2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .overlay(Capsule().stroke(Color.wildGold.opacity(0.68), lineWidth: 1))
                }
            }
            .padding(.horizontal, 12)
        }
        .padding(14)
        .frame(width: cardWidth, height: 472, alignment: .top)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(Color.black.opacity(0.72))
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [.black.opacity(0.18), Color.wildInk.opacity(0.62), .black.opacity(0.34)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                HoloShine(
                    cornerRadius: 28,
                    starCount: observation.stars,
                    tilt: foilTilt
                )
                    .opacity(0.16)
            }
        )
        .overlay(
            RarityMetalBorder(
                starCount: observation.stars,
                cornerRadius: 28,
                lineWidth: 10,
                tilt: foilTilt
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.wildGold.opacity(0.78), lineWidth: 1.2)
                .padding(14)
        )
        .shadow(color: .black.opacity(0.48), radius: 26, x: 0, y: 18)
    }
}

private enum RarityMetalTier: Int {
    case matteSteel = 1
    case coloredAlloy = 2
    case crosshatchedSilver = 3
    case iridescentPearl = 4
    case invertedFoil = 5
    case rainbowHolo = 6

    init(starCount: Int) {
        self = RarityMetalTier(rawValue: min(max(starCount, 1), 6)) ?? .matteSteel
    }

    var colors: [Color] {
        switch self {
        case .matteSteel:
            return [Color(white: 0.24), Color(white: 0.88), Color(white: 0.38), Color(white: 0.72)]
        case .coloredAlloy:
            return [Color(red: 0.08, green: 0.38, blue: 0.3), Color(red: 0.62, green: 0.86, blue: 0.7), Color(red: 0.82, green: 0.66, blue: 0.24)]
        case .crosshatchedSilver:
            return [Color(red: 0.28, green: 0.43, blue: 0.6), Color(white: 0.96), Color(red: 0.36, green: 0.68, blue: 0.74), Color(white: 0.52)]
        case .iridescentPearl:
            return [Color(red: 0.68, green: 0.42, blue: 0.86), Color(red: 0.38, green: 0.84, blue: 0.9), Color(red: 0.96, green: 0.58, blue: 0.72), Color(red: 0.72, green: 0.64, blue: 0.96)]
        case .invertedFoil:
            return [Color(red: 0.34, green: 0.12, blue: 0.04), Color(red: 0.98, green: 0.78, blue: 0.3), Color(red: 0.78, green: 0.3, blue: 0.08), Color(red: 1, green: 0.92, blue: 0.62)]
        case .rainbowHolo:
            return [Color.red, Color.orange, Color.yellow, Color.green, Color.cyan, Color.blue, Color.purple, Color.pink, Color.red]
        }
    }

    var glowColor: Color {
        switch self {
        case .matteSteel: return .white
        case .coloredAlloy: return Color(red: 0.42, green: 0.86, blue: 0.64)
        case .crosshatchedSilver: return Color.wildCyan
        case .iridescentPearl: return Color(red: 0.8, green: 0.5, blue: 0.94)
        case .invertedFoil: return Color.orange
        case .rainbowHolo: return Color.wildGold
        }
    }
}

private struct RarityMetalShader: ViewModifier {
    var tier: RarityMetalTier
    var tilt: CGPoint

    @ViewBuilder
    func body(content: Content) -> some View {
        switch tier {
        case .matteSteel:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.polishedAluminum(intensity: 0.3))
        case .coloredAlloy:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.polishedAluminum(intensity: 0.46))
                .shader(.edgeShine)
        case .crosshatchedSilver:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.metallicCrosshatch(intensity: 0.58))
                .shader(.lightSweep)
        case .iridescentPearl:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.diagonalHolo(intensity: 0.64))
                .shader(.rainbowGlitter(intensity: 0.22))
        case .invertedFoil:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.invertedFoil(intensity: 0.76))
                .shader(.shimmer(intensity: 0.34))
                .shader(.lightSweep)
        case .rainbowHolo:
            content
                .shaderContext(tilt: tilt, time: 0)
                .shader(.foil(intensity: 0.94))
                .shader(.rainbowGlitter(intensity: 0.62))
                .shader(.shimmer(intensity: 0.52))
                .shader(.edgeShine)
        }
    }
}

struct RarityMetalBorder: View {
    var starCount: Int
    var cornerRadius: CGFloat
    var lineWidth: CGFloat
    var tilt: CGPoint = .zero

    private var tier: RarityMetalTier {
        RarityMetalTier(starCount: starCount)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        ZStack {
            shape
                .strokeBorder(
                    LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: lineWidth
                )
                .modifier(RarityMetalShader(tier: tier, tilt: tilt))

            shape
                .strokeBorder(.white.opacity(starCount >= 4 ? 0.66 : 0.42), lineWidth: max(lineWidth * 0.12, 0.8))
                .padding(lineWidth * 0.18)

            shape
                .strokeBorder(.black.opacity(0.42), lineWidth: max(lineWidth * 0.11, 0.7))
                .padding(lineWidth * 0.72)
        }
        .shadow(color: tier.glowColor.opacity(starCount >= 5 ? 0.34 : 0.18), radius: max(lineWidth * 1.05, 3))
        .allowsHitTesting(false)
    }
}

struct RarityMetalSurface: View {
    var starCount: Int
    var cornerRadius: CGFloat
    var tilt: CGPoint = .zero

    private var tier: RarityMetalTier {
        RarityMetalTier(starCount: starCount)
    }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(LinearGradient(colors: tier.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            .modifier(RarityMetalShader(tier: tier, tilt: tilt))
            .mask(shape)
            .allowsHitTesting(false)
    }
}

struct HoloShine: View {
    var cornerRadius: CGFloat
    var starCount: Int = 6
    var tilt: CGPoint = .zero
    var layerOpacity: Double = 0.58
    var blendMode: BlendMode = .softLight

    var body: some View {
        RarityMetalSurface(starCount: starCount, cornerRadius: cornerRadius, tilt: tilt)
            .opacity(layerOpacity)
            .blendMode(blendMode)
            .allowsHitTesting(false)
    }
}

struct BundleImage: View {
    var name: String

    var body: some View {
        Group {
            if let image = UIImage.wildGoImage(named: name) {
                Image(uiImage: image)
                    .resizable()
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.wildMist)
                    Image(systemName: "leaf")
                        .font(.largeTitle)
                        .foregroundStyle(Color.wildInk.opacity(0.5))
                }
            }
        }
    }
}

struct StarStrip: View {
    var count: Int
    var font: Font = .caption2

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<6, id: \.self) { index in
                Image(systemName: "star.fill")
                    .font(font)
                    .foregroundStyle(index < count ? Color.wildGold : Color.wildGold.opacity(0.28))
            }
        }
    }
}

struct MetricPill: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.68), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

struct CollectionProgressCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("NYC Collection")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("243 / 500 species")
                        .font(.title3.weight(.black))
                }
                Spacer()
                Text("49%")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white, in: Capsule())
                    .overlay(Capsule().stroke(Color.wildInk, lineWidth: 1))
            }
            ProgressView(value: 0.49)
                .tint(Color.wildGreen)
        }
        .padding(18)
        .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 18, x: 0, y: 10)
    }
}

struct RarityGuide: View {
    private let rows = [
        ("1", "Common", "Matte"),
        ("2", "Uncommon", "Colored"),
        ("3", "Rare", "Metallic"),
        ("4", "Seasonal", "Iridescent"),
        ("5", "Local Special", "Foil"),
        ("6", "City Legend", "Holo")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rarity Guide")
                .font(.title3.weight(.bold))
            Text("Discovery difficulty maps to card finish.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(rows, id: \.0) { row in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.0)
                            .font(.caption.weight(.black))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Color.wildInk, in: Circle())
                        Text(row.1)
                            .font(.caption.weight(.bold))
                        Text(row.2)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(Color.wildPaper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.76), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.wildInk, lineWidth: 1))
    }
}

struct SafetyRow: View {
    var icon: String
    var title: String
    var detail: String

    var bodyView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .frame(width: 38, height: 38)
                .background(Color.wildMist, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    var body: some View {
        bodyView
    }
}

struct StatCell: View {
    var value: String
    var label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.black))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.wildPaper, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct WildGoBackground: View {
    var body: some View {
        LinearGradient(colors: [Color.wildPaper, Color.wildMist, Color.white], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(alignment: .topTrailing) {
                Circle()
                    .fill(Color.wildCyan.opacity(0.2))
                    .frame(width: 260, height: 260)
                    .blur(radius: 18)
                    .offset(x: 90, y: -80)
            }
            .ignoresSafeArea()
    }
}

struct WildToastView: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
            .frame(maxWidth: 360)
            .background(.black.opacity(0.82), in: Capsule())
            .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 8)
            .accessibilityAddTraits(.isStaticText)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

extension ButtonStyle where Self == WildButtonStyle {
    static var wildPrimary: WildButtonStyle {
        WildButtonStyle(kind: .primary)
    }

    static var wildSecondary: WildButtonStyle {
        WildButtonStyle(kind: .secondary)
    }
}

struct WildButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    var kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .padding(.vertical, 13)
            .padding(.horizontal, 14)
            .background(kind == .primary ? Color.wildLime.opacity(0.86) : Color.black.opacity(0.18), in: Capsule())
            .foregroundStyle(.white)
            .overlay(Capsule().stroke(kind == .primary ? Color.wildLime : Color.wildLime.opacity(0.82), lineWidth: 1.6))
            .shadow(color: kind == .primary ? Color.wildLime.opacity(0.24) : .clear, radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

extension UIImage {
    static func wildGoImage(named name: String) -> UIImage? {
        ObservationPhotoStore.image(named: name) ?? namedInWildGoBundle(name)
    }

    static func namedInWildGoBundle(_ name: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }

        let base = name.replacingOccurrences(of: ".png", with: "")
        if let image = UIImage(named: base) {
            return image
        }

        guard let path = Bundle.main.path(forResource: base, ofType: "png", inDirectory: "GeneratedAssets") else {
            return nil
        }

        return UIImage(contentsOfFile: path)
    }
}

extension CGImagePropertyOrientation {
    init(_ imageOrientation: UIImage.Orientation) {
        switch imageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .left:
            self = .left
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        @unknown default:
            self = .up
        }
    }
}

extension Color {
    static let wildInk = Color(red: 0.05, green: 0.17, blue: 0.12)
    static let wildGreen = Color(red: 0.23, green: 0.52, blue: 0.37)
    static let wildLime = Color(red: 0.58, green: 0.82, blue: 0.16)
    static let wildGold = Color(red: 0.96, green: 0.72, blue: 0.28)
    static let wildCyan = Color(red: 0.21, green: 0.69, blue: 0.82)
    static let wildCoral = Color(red: 0.88, green: 0.36, blue: 0.27)
    static let wildPaper = Color(red: 0.97, green: 0.96, blue: 0.9)
    static let wildMist = Color(red: 0.83, green: 0.9, blue: 0.82)
}
