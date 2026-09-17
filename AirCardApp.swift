import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Models

struct DeviceInfo: Codable {
    var udid: String?
    var name: String?
    var version: String?
    var product: String?
    var airlift_compatible: Bool?
    var connected: Bool
}

struct CardItem: Identifiable, Hashable {
    let id: String
    var isSelected: Bool = true
    var customImageURL: URL? = nil
    var customImage: NSImage? = nil
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: CardItem, rhs: CardItem) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected && lhs.customImageURL == rhs.customImageURL
    }
}

enum AppTab: String, CaseIterable, Identifiable {
    case walletCards = "Apple Wallet"
    case passcodeThemes = "Passcode (.passthm)"
    var id: String { rawValue }
}

struct PasscodeThemeInfo: Identifiable {
    var id: String { filePath }
    let name: String
    let filePath: String
    let detectedVersion: String
    let fileCount: Int
    let keysPreview: [String: NSImage]
}

enum PasscodeTabMode: String, CaseIterable, Identifiable {
    case applyTheme = "Apply .passthm"
    case themeCreator = "Theme Creator"
    var id: String { rawValue }
}

enum CreatorSubMode: String, CaseIterable, Identifiable {
    case posterSlice = "Poster Slice (Puzzle)"
    case individualKeys = "Individual Keys"
    var id: String { rawValue }
}

struct KeypadButtonGeometry: Identifiable {
    var id: String { digit }
    let digit: String
    let letters: String
    let row: Int
    let col: Int
}

struct KeypadLayout {
    static let buttonDiameter: CGFloat = 75.0
    static let colWidth: CGFloat = 101.67 // 305.0 / 3
    static let rowHeight: CGFloat = 95.67 // 287.0 / 3
    static let horizontalSpacing: CGFloat = 24.0
    static let verticalSpacing: CGFloat = 18.0
    
    static let gridWidth: CGFloat = 305.0 // 915.0 / 3
    static let gridHeight: CGFloat = 382.67 // 1148.0 / 3
    
    static let allButtons: [KeypadButtonGeometry] = [
        KeypadButtonGeometry(digit: "1", letters: "", row: 0, col: 0),
        KeypadButtonGeometry(digit: "2", letters: "A B C", row: 0, col: 1),
        KeypadButtonGeometry(digit: "3", letters: "D E F", row: 0, col: 2),
        KeypadButtonGeometry(digit: "4", letters: "G H I", row: 1, col: 0),
        KeypadButtonGeometry(digit: "5", letters: "J K L", row: 1, col: 1),
        KeypadButtonGeometry(digit: "6", letters: "M N O", row: 1, col: 2),
        KeypadButtonGeometry(digit: "7", letters: "P Q R S", row: 2, col: 0),
        KeypadButtonGeometry(digit: "8", letters: "T U V", row: 2, col: 1),
        KeypadButtonGeometry(digit: "9", letters: "W X Y Z", row: 2, col: 2),
        KeypadButtonGeometry(digit: "0", letters: "+", row: 3, col: 1)
    ]
    
    static let keypadSubtexts: [String: String] = [
        "0": "+",
        "1": "",
        "2": "A B C",
        "3": "D E F",
        "4": "G H I",
        "5": "J K L",
        "6": "M N O",
        "7": "P Q R S",
        "8": "T U V",
        "9": "W X Y Z"
    ]
    
    static func cellFrame(for button: KeypadButtonGeometry) -> CGRect {
        let x = CGFloat(button.col) * colWidth
        let y = CGFloat(button.row) * rowHeight
        return CGRect(x: x, y: y, width: colWidth, height: rowHeight)
    }
}

// MARK: - Keypad Slicing Engine

class KeypadSlicer {
    static func cgImage(from image: NSImage) -> CGImage? {
        var rect = CGRect(origin: .zero, size: image.size)
        if let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            return cg
        }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(image.size.width)),
            pixelsHigh: max(1, Int(image.size.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.cgImage
    }
    
    static func slicePoster(
        image: NSImage,
        zoom: Double = 1.0,
        offset: CGPoint = .zero,
        maskToCircles: Bool = false
    ) -> [String: NSImage] {
        guard let cgImg = cgImage(from: image) else { return [:] }
        let imgW = CGFloat(cgImg.width)
        let imgH = CGFloat(cgImg.height)
        guard imgW > 0 && imgH > 0 else { return [:] }
        
        // Standard iOS TelephonyUI @3x grid dimensions
        let gridW: CGFloat = 915.0
        let gridH: CGFloat = 1148.0
        let colW: CGFloat = 305.0
        let rowH: CGFloat = 287.0
        
        let baseScale = max(gridW / imgW, gridH / imgH)
        let scale = baseScale * CGFloat(max(0.1, zoom))
        let scaledW = imgW * scale
        let scaledH = imgH * scale
        
        // Match user's pan offset in SwiftUI points (scaled to 3x)
        let imageX = (gridW - scaledW) / 2.0 + offset.x * 3.0
        let imageY = (gridH - scaledH) / 2.0 + offset.y * 3.0
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var results: [String: NSImage] = [:]
        
        for button in KeypadLayout.allButtons {
            let isZeroSeamless = (!maskToCircles && button.digit == "0")
            let tileW: CGFloat = isZeroSeamless ? gridW : colW
            let tileH: CGFloat = rowH
            
            let cellX: CGFloat = isZeroSeamless ? 0.0 : CGFloat(button.col) * colW
            let cellY: CGFloat = CGFloat(button.row) * rowH
            
            let relX = imageX - cellX
            let relY = imageY - cellY
            let destCGY = tileH - relY - scaledH
            
            guard let ctx = CGContext(
                data: nil,
                width: Int(tileW),
                height: Int(tileH),
                bitsPerComponent: 8,
                bytesPerRow: Int(tileW) * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }
            
            ctx.clear(CGRect(x: 0, y: 0, width: tileW, height: tileH))
            
            if maskToCircles {
                let circleDiameter: CGFloat = 225.0
                let circleX = (tileW - circleDiameter) / 2.0
                let circleY = (tileH - circleDiameter) / 2.0
                ctx.addEllipse(in: CGRect(x: circleX, y: circleY, width: circleDiameter, height: circleDiameter))
                ctx.clip()
            }
            
            ctx.draw(cgImg, in: CGRect(x: relX, y: destCGY, width: scaledW, height: scaledH))
            
            if let outCG = ctx.makeImage() {
                results[button.digit] = NSImage(cgImage: outCG, size: NSSize(width: tileW, height: tileH))
            }
        }
        return results
    }
    
    static func cropToCircle(image: NSImage, targetSize: CGSize = CGSize(width: 300, height: 300)) -> NSImage? {
        guard let cgImg = cgImage(from: image) else { return nil }
        let imgW = CGFloat(cgImg.width)
        let imgH = CGFloat(cgImg.height)
        guard imgW > 0 && imgH > 0 else { return nil }
        
        let baseScale = max(targetSize.width / imgW, targetSize.height / imgH)
        let scaledW = imgW * baseScale
        let scaledH = imgH * baseScale
        let destX = (targetSize.width - scaledW) / 2.0
        let destY = (targetSize.height - scaledH) / 2.0
        let destCGY = targetSize.height - destY - scaledH
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: Int(targetSize.width),
            height: Int(targetSize.height),
            bitsPerComponent: 8,
            bytesPerRow: Int(targetSize.width) * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.clear(CGRect(origin: .zero, size: targetSize))
        ctx.addEllipse(in: CGRect(origin: .zero, size: targetSize))
        ctx.clip()
        ctx.draw(cgImg, in: CGRect(x: destX, y: destCGY, width: scaledW, height: scaledH))
        
        guard let outCG = ctx.makeImage() else { return nil }
        return NSImage(cgImage: outCG, size: targetSize)
    }
}

// MARK: - Passcode Theme Exporter

class PasscodeThemeExporter {
    static func pngData(from image: NSImage) -> Data? {
        if let tiff = image.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let png = rep.representation(using: .png, properties: [:]) {
            return png
        }
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: max(1, Int(image.size.width)),
            pixelsHigh: max(1, Int(image.size.height)),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        
        NSGraphicsContext.saveGraphicsState()
        guard let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return nil
        }
        NSGraphicsContext.current = ctx
        image.draw(in: NSRect(origin: .zero, size: image.size))
        NSGraphicsContext.restoreGraphicsState()
        return rep.representation(using: .png, properties: [:])
    }
    
    static func exportTheme(keys: [String: NSImage], targetURL: URL) throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("passthm_\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        for ver in ["TelephonyUI-10", "TelephonyUI-9"] {
            let verDir = tempDir.appendingPathComponent(ver)
            try FileManager.default.createDirectory(at: verDir, withIntermediateDirectories: true)
            
            let markerFile = verDir.appendingPathComponent("_big")
            FileManager.default.createFile(atPath: markerFile.path, contents: Data())
            
            for (digit, image) in keys {
                guard let pngData = pngData(from: image) else { continue }
                let subtext = KeypadLayout.keypadSubtexts[digit] ?? ""
                
                var filenames = [
                    "en-\(digit)---white.png",
                    "other-\(digit)---white.png"
                ]
                if !subtext.isEmpty {
                    filenames.append("en-\(digit)-\(subtext)--white.png")
                    filenames.append("other-\(digit)-\(subtext)--white.png")
                }
                
                for fn in filenames {
                    let fileURL = verDir.appendingPathComponent(fn)
                    try pngData.write(to: fileURL)
                }
            }
        }
        
        if FileManager.default.fileExists(atPath: targetURL.path) {
            try FileManager.default.removeItem(at: targetURL)
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = tempDir
        process.arguments = ["-r", "-q", targetURL.path, "TelephonyUI-10", "TelephonyUI-9"]
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw NSError(
                domain: "PasscodeThemeExporter",
                code: Int(process.terminationStatus),
                userInfo: [NSLocalizedDescriptionKey: "Failed to create .passthm zip archive (exit code \(process.terminationStatus))"]
            )
        }
    }
    
    static func stageTemporaryTheme(keys: [String: NSImage]) -> URL? {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("AirCard_Custom_\(UUID().uuidString).passthm")
        do {
            try exportTheme(keys: keys, targetURL: tempURL)
            return tempURL
        } catch {
            print("Failed to stage temporary theme: \(error)")
            return nil
        }
    }
}

// MARK: - View Model

@MainActor
class AppViewModel: ObservableObject {
    @Published var selectedTab: AppTab = .walletCards
    @Published var loadedPasscodeTheme: PasscodeThemeInfo? = nil
    @Published var isInspectingTheme = false
    @Published var targetTelephonyVersion: String = "TelephonyUI-10"
    
    // Theme Creator Properties
    @Published var passcodeTabMode: PasscodeTabMode = .applyTheme
    @Published var creatorSubMode: CreatorSubMode = .posterSlice
    @Published var creatorPosterImage: NSImage? = nil
    @Published var creatorPosterZoom: Double = 1.0
    @Published var creatorPosterOffset: CGPoint = .zero
    @Published var creatorMaskToCircles: Bool = false
    @Published var creatorCustomKeys: [String: NSImage] = [:]
    @Published var creatorSlicedKeys: [String: NSImage] = [:]
    
    @Published var device: DeviceInfo?
    @Published var isCheckingDevice = false
    @Published var isScanningCards = false
    @Published var cards: [CardItem] = []
    
    @Published var isFlashing = false
    @Published var progress: Double = 0.0
    @Published var statusText: String = "Ready"
    @Published var logs: [String] = []
    @Published var showSuccessAlert = false
    @Published var errorMessage: String?
    
    @Published var showAddCardSheet = false
    @Published var manualHashInput = ""
    @Published var showLogs = false
    
    private var scanProcess: Process?
    private let scriptDir: String
    private let storageKey = "mak5er.aircard.savedCards"
    private let legacyStorageKey1 = "mak5er.savedCards"
    private let legacyStorageKey2 = "LumiCards.savedCards"
    
    nonisolated static let cardRegexes: [NSRegularExpression] = [
        try! NSRegularExpression(pattern: "/(?:Cards|Passes/Cards)/([-A-Za-z0-9_+=]{20,44})(?:\\.pkpass|\\.cache|\\.pkcache|/|\\s|\"|'|\\)|,|$)"),
        try! NSRegularExpression(pattern: "/([-A-Za-z0-9_+=]{20,44})\\.(?:pkpass|cache|pkcache)"),
        try! NSRegularExpression(pattern: "(?<![A-Za-z0-9+/_-])([A-Za-z0-9+/_-]{27}=)(?![A-Za-z0-9+/_-])")
    ]
    
    init() {
        let cwd = FileManager.default.currentDirectoryPath
        let defaultWorkspace = "/Users/mak5er/Dev/IOS/AirCard"
        if FileManager.default.fileExists(atPath: cwd + "/aircard_backend.py") {
            self.scriptDir = cwd
        } else if let resPath = Bundle.main.resourcePath, FileManager.default.fileExists(atPath: resPath + "/aircard_backend.py") {
            self.scriptDir = resPath
        } else if FileManager.default.fileExists(atPath: defaultWorkspace + "/aircard_backend.py") {
            self.scriptDir = defaultWorkspace
        } else {
            self.scriptDir = Bundle.main.bundleURL.deletingLastPathComponent().path
        }
        
        loadSavedCards()
        checkDevice()
    }
    
    func log(_ message: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        logs.append("[\(timestamp)] \(message)")
    }
    
    nonisolated private static var pythonExecutableURL: URL {
        let candidates = [
            "/usr/bin/python3",
            "/opt/homebrew/bin/python3",
            "/usr/local/bin/python3"
        ]
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: "/usr/bin/python3")
    }
    
    nonisolated private static var syslogExecutableURL: URL {
        var candidates: [String] = []
        if let res = Bundle.main.resourceURL {
            candidates.append(res.appendingPathComponent("bin/idevicesyslog").path)
        }
        candidates.append("/Applications/AirCard.app/Contents/Resources/bin/idevicesyslog")
        candidates.append("/opt/homebrew/bin/idevicesyslog")
        candidates.append("/usr/local/bin/idevicesyslog")
        candidates.append("/usr/bin/idevicesyslog")
        for path in candidates {
            if FileManager.default.isExecutableFile(atPath: path) {
                return URL(fileURLWithPath: path)
            }
        }
        return URL(fileURLWithPath: "/usr/bin/idevicesyslog")
    }
    
    nonisolated private static var processEnvironment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? ""
        var extraPaths = [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin"
        ]
        if let res = Bundle.main.resourceURL {
            extraPaths.insert(res.appendingPathComponent("bin").path, at: 0)
        }
        extraPaths.insert("/Applications/AirCard.app/Contents/Resources/bin", at: 0)
        env["PATH"] = (extraPaths + [path]).joined(separator: ":")
        
        var libPaths = ["/Applications/AirCard.app/Contents/Resources/lib"]
        if let res = Bundle.main.resourceURL {
            libPaths.insert(res.appendingPathComponent("lib").path, at: 0)
        }
        let curDyld = env["DYLD_LIBRARY_PATH"] ?? ""
        env["DYLD_LIBRARY_PATH"] = (libPaths + (curDyld.isEmpty ? [] : [curDyld])).joined(separator: ":")
        return env
    }
    
    nonisolated static func prepareCardImage(srcURL: URL, dstURL: URL) -> Bool {
        guard let image = NSImage(contentsOf: srcURL) else { return false }
        let targetSize = CGSize(width: 1536, height: 969)
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(targetSize.width),
            pixelsHigh: Int(targetSize.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return false }
        
        rep.size = targetSize
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        
        let imgSize = image.size
        let scale = max(targetSize.width / imgSize.width, targetSize.height / imgSize.height)
        let scaledWidth = imgSize.width * scale
        let scaledHeight = imgSize.height * scale
        let x = (targetSize.width - scaledWidth) / 2.0
        let y = (targetSize.height - scaledHeight) / 2.0
        
        image.draw(in: CGRect(x: x, y: y, width: scaledWidth, height: scaledHeight),
                   from: CGRect(origin: .zero, size: imgSize),
                   operation: .copy,
                   fraction: 1.0)
        
        NSGraphicsContext.restoreGraphicsState()
        guard let pngData = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try pngData.write(to: dstURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
    
    // MARK: - Persistence
    
    func loadSavedCards() {
        var loaded: [String] = []
        
        if let saved = UserDefaults.standard.stringArray(forKey: storageKey), !saved.isEmpty {
            loaded.append(contentsOf: saved)
        } else if let saved = UserDefaults.standard.stringArray(forKey: legacyStorageKey1), !saved.isEmpty {
            loaded.append(contentsOf: saved)
        } else if let saved = UserDefaults.standard.stringArray(forKey: legacyStorageKey2), !saved.isEmpty {
            loaded.append(contentsOf: saved)
        }
        
        for p in ["~/.aircard_cards.json", "~/.lumicards_cards.json"] {
            let jsonPath = NSString(string: p).expandingTildeInPath
            if let data = try? Data(contentsOf: URL(fileURLWithPath: jsonPath)),
               let jsonHashes = try? JSONDecoder().decode([String].self, from: data) {
                for h in jsonHashes where !loaded.contains(h) {
                    loaded.append(h)
                }
            }
        }
        
        let dummyHashes = [
            "M6nDwZrkYbFlsodLgCbvyFZQ1cc=",
            "kJL-D0rr-SZhbj2c8nK-OQ9hCMY=",
            "hwAtAmHKYwsQrJbT5cTNDsaxVME="
        ]
        loaded.removeAll { dummyHashes.contains($0) || ($0.contains("-") && $0.count == 36) }
        
        self.cards = loaded.map { CardItem(id: $0, isSelected: true) }
        log("Loaded \(cards.count) real card(s) from storage.")
    }
    
    func saveCards() {
        let hashes = cards.map { $0.id }
        UserDefaults.standard.set(hashes, forKey: storageKey)
        
        let jsonPath = NSString(string: "~/.aircard_cards.json").expandingTildeInPath
        if let data = try? JSONEncoder().encode(hashes) {
            try? data.write(to: URL(fileURLWithPath: jsonPath), options: .atomic)
        }
    }
    
    func addCardHash(_ raw: String) {
        let components = raw.components(separatedBy: CharacterSet(charactersIn: " \n\r\t,;"))
        var addedCount = 0
        for comp in components {
            let clean = comp.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "."))
            if clean.count >= 16 && clean.count <= 64 && !cards.contains(where: { $0.id == clean }) {
                cards.append(CardItem(id: clean, isSelected: true))
                addedCount += 1
                log("Added card: \(clean)")
            }
        }
        if addedCount > 0 {
            saveCards()
        }
    }
    
    func deleteCard(id: String) {
        cards.removeAll { $0.id == id }
        saveCards()
        log("Removed card: \(id)")
    }
    
    func clearAllCards() {
        cards.removeAll()
        saveCards()
        log("Cleared all cards.")
    }
    
    func setCardImage(for cardId: String, url: URL) {
        if let idx = cards.firstIndex(where: { $0.id == cardId }) {
            cards[idx].customImageURL = url
            cards[idx].customImage = NSImage(contentsOf: url)
            cards[idx].isSelected = true
            log("Assigned custom skin to card: \(cardId.prefix(12))...")
        }
    }
    
    func clearCardImage(for cardId: String) {
        if let idx = cards.firstIndex(where: { $0.id == cardId }) {
            cards[idx].customImageURL = nil
            cards[idx].customImage = nil
            log("Cleared custom skin for: \(cardId.prefix(12))...")
        }
    }
    
    // MARK: - Device Connection
    
    func checkDevice() {
        isCheckingDevice = true
        statusText = "Checking connected devices..."
        let scriptDir = self.scriptDir
        
        Task.detached {
            let process = Process()
            process.executableURL = AppViewModel.pythonExecutableURL
            process.environment = AppViewModel.processEnvironment
            process.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
            process.arguments = ["aircard_backend.py", "--device"]
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                
                if let dev = try? JSONDecoder().decode(DeviceInfo.self, from: data) {
                    await MainActor.run {
                        self.device = dev
                        self.isCheckingDevice = false
                        if dev.connected {
                            self.statusText = "Connected to \(dev.name ?? "iPhone")"
                            self.log("Device connected: \(dev.name ?? "iPhone") (\(dev.product ?? ""), iOS \(dev.version ?? ""))")
                        } else {
                            self.statusText = "No iPhone found. Please connect via USB."
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.isCheckingDevice = false
                    self.statusText = "Device detection failed: \(error.localizedDescription)"
                }
            }
        }
    }
    
    // MARK: - Live Card Scanner
    
    func toggleCardScanning() {
        if isScanningCards {
            stopCardScanning()
        } else {
            startCardScanning()
        }
    }
    
    func startCardScanning() {
        guard !isScanningCards else { return }
        isScanningCards = true
        statusText = "Double-click Side button, pass Face ID, then tap your card..."
        log("Started scanning device logs for cards...")
        
        let pipe = Pipe()
        let proc = Process()
        proc.executableURL = AppViewModel.syslogExecutableURL
        proc.environment = AppViewModel.processEnvironment
        proc.arguments = ["-q"]
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        self.scanProcess = proc
        
        let dummyHashes = [
            "M6nDwZrkYbFlsodLgCbvyFZQ1cc=",
            "kJL-D0rr-SZhbj2c8nK-OQ9hCMY=",
            "hwAtAmHKYwsQrJbT5cTNDsaxVME="
        ]
        
        Task.detached {
            do {
                try proc.run()
                let handle = pipe.fileHandleForReading
                var buffer = Data()
                
                while proc.isRunning {
                    let chunk = handle.availableData
                    if chunk.isEmpty {
                        usleep(100000)
                        continue
                    }
                    buffer.append(chunk)
                    
                    while let newlineRange = buffer.range(of: Data([0x0A])) {
                        let lineData = buffer.subdata(in: buffer.startIndex..<newlineRange.lowerBound)
                        buffer.removeSubrange(buffer.startIndex..<newlineRange.upperBound)
                        
                        guard let line = String(data: lineData, encoding: .utf8) else { continue }
                        let lower = line.lowercased()
                        
                        let isWalletSubsystem = lower.contains("passd") ||
                                                lower.contains("passbook") ||
                                                lower.contains("passkit") ||
                                                lower.contains("stockholm") ||
                                                lower.contains("nanopassd") ||
                                                lower.contains("wallet") ||
                                                lower.contains("/cards/")
                        
                        guard isWalletSubsystem else { continue }
                        
                        let isWalletContext = lower.contains("card") ||
                                              lower.contains("pass") ||
                                              lower.contains("payment") ||
                                              lower.contains("pkpass") ||
                                              lower.contains("uniqueid") ||
                                              lower.contains("identifier") ||
                                              lower.contains("face") ||
                                              lower.contains("cache") ||
                                              lower.contains("stockholm") ||
                                              lower.contains("/cards/")
                        
                        guard isWalletContext else { continue }
                        
                        for regex in AppViewModel.cardRegexes {
                            let matches = regex.matches(in: line, range: NSRange(line.startIndex..., in: line))
                            for m in matches {
                                if m.numberOfRanges > 1, let r = Range(m.range(at: 1), in: line) {
                                    let candidate = String(line[r])
                                    if candidate.count == 36 && candidate.contains("-") { continue }
                                    if dummyHashes.contains(candidate) { continue }
                                    
                                    await MainActor.run {
                                        if !self.cards.contains(where: { $0.id == candidate }) {
                                            self.cards.append(CardItem(id: candidate, isSelected: true))
                                            self.saveCards()
                                            self.log("Found card: \(candidate)")
                                            NSSound(named: "Glass")?.play()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } catch {
                await MainActor.run {
                    self.log("Syslog monitor stopped: \(error.localizedDescription)")
                    self.isScanningCards = false
                }
            }
        }
    }
    
    func stopCardScanning() {
        scanProcess?.terminate()
        scanProcess = nil
        isScanningCards = false
        saveCards()
        log("Scanning stopped. Total cards: \(cards.count).")
    }
    
    // MARK: - Skin Application
    
    func applySkin() {
        guard let udid = device?.udid else {
            errorMessage = "No iPhone connected."
            return
        }
        let selectedCardsWithSkin = cards.filter { $0.isSelected && $0.customImageURL != nil }
        guard !selectedCardsWithSkin.isEmpty else {
            errorMessage = "Please assign a skin image to at least one selected card."
            return
        }
        
        isFlashing = true
        showLogs = true
        progress = 0.0
        log("Starting skin application for \(selectedCardsWithSkin.count) card(s)...")
        let scriptDir = self.scriptDir
        
        Task.detached {
            let totalCards = Double(selectedCardsWithSkin.count)
            for (idx, card) in selectedCardsWithSkin.enumerated() {
                guard let imgURL = card.customImageURL else { continue }
                
                let preparedPath = "/tmp/aircard_prep_\(idx).png"
                
                await MainActor.run {
                    self.statusText = "[\(idx + 1)/\(selectedCardsWithSkin.count)] Preparing skin for \(card.id.prefix(10))..."
                    self.progress = (Double(idx) + 0.05) / totalCards
                    self.log("Flashing card [\(idx + 1)/\(selectedCardsWithSkin.count)]: \(card.id)")
                }
                
                // 1. Prepare image natively in Swift (0 external dependencies!)
                let preparedURL = URL(fileURLWithPath: preparedPath)
                let prepped = AppViewModel.prepareCardImage(srcURL: imgURL, dstURL: preparedURL)
                if !prepped {
                    let prepProcess = Process()
                    prepProcess.executableURL = AppViewModel.pythonExecutableURL
                    prepProcess.environment = AppViewModel.processEnvironment
                    prepProcess.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
                    prepProcess.arguments = ["aircard_backend.py", "--prepare-image", imgURL.path, preparedPath]
                    try? prepProcess.run()
                    prepProcess.waitUntilExit()
                }
                
                // 2. Flash card
                let flashProcess = Process()
                flashProcess.executableURL = AppViewModel.pythonExecutableURL
                flashProcess.environment = AppViewModel.processEnvironment
                flashProcess.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
                flashProcess.arguments = ["aircard_backend.py", "--flash", udid, card.id, preparedPath]
                
                let pipe = Pipe()
                flashProcess.standardOutput = pipe
                flashProcess.standardError = Pipe()
                
                try? flashProcess.run()
                
                let handle = pipe.fileHandleForReading
                var lineBuffer = ""
                
                let handleJSONLine: (String) async -> Void = { line in
                    guard !line.isEmpty,
                          let lineData = line.data(using: .utf8),
                          let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                          let msg = json["message"] as? String else { return }
                    
                    let step = (json["step"] as? NSNumber)?.doubleValue
                    let total = (json["total"] as? NSNumber)?.doubleValue
                    
                    await MainActor.run {
                        if let step = step, let total = total, total > 0 {
                            let subProgress = step / total
                            let currentProgress = (Double(idx) + subProgress) / totalCards
                            self.progress = min(currentProgress, 1.0)
                        }
                        self.statusText = "[\(idx + 1)/\(selectedCardsWithSkin.count)] \(msg)"
                        self.log("  \(msg)")
                    }
                }
                
                let processChunk: (Data) async -> Void = { data in
                    guard let text = String(data: data, encoding: .utf8) else { return }
                    lineBuffer.append(text)
                    let parts = lineBuffer.components(separatedBy: .newlines)
                    if parts.count > 1 {
                        for line in parts.dropLast() {
                            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                await handleJSONLine(trimmed)
                            }
                        }
                        lineBuffer = parts.last ?? ""
                    }
                }
                
                while flashProcess.isRunning {
                    let data = handle.availableData
                    if data.isEmpty { usleep(50000); continue }
                    await processChunk(data)
                }
                
                let remainingData = handle.readDataToEndOfFile()
                if !remainingData.isEmpty {
                    await processChunk(remainingData)
                }
                let finalLine = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                if !finalLine.isEmpty {
                    await handleJSONLine(finalLine)
                }
                flashProcess.waitUntilExit()
                
                await MainActor.run {
                    self.progress = Double(idx + 1) / totalCards
                }
            }
            
            await MainActor.run {
                self.isFlashing = false
                self.statusText = "Complete! All cards updated."
                self.showSuccessAlert = true
                self.log("Skins successfully applied to all selected cards!")
            }
        }
    }
    
    // MARK: - Passcode Theme (.passthm) Handlers
    
    func inspectPasscodeTheme(url: URL) {
        isInspectingTheme = true
        let scriptDir = self.scriptDir
        Task.detached {
            let proc = Process()
            proc.executableURL = AppViewModel.pythonExecutableURL
            proc.environment = AppViewModel.processEnvironment
            proc.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
            proc.arguments = ["aircard_backend.py", "--inspect-passthm", url.path]
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            proc.waitUntilExit()
            
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let ok = json["ok"] as? Bool, ok {
                let name = json["name"] as? String ?? url.deletingPathExtension().lastPathComponent
                let detectedVersion = json["detected_version"] as? String ?? "TelephonyUI-10"
                let fileCount = json["file_count"] as? Int ?? 0
                var previews: [String: NSImage] = [:]
                if let keysDict = json["keys_preview"] as? [String: String] {
                    for (digit, dataUri) in keysDict {
                        if let commaIdx = dataUri.firstIndex(of: ",") {
                            let b64 = String(dataUri[dataUri.index(after: commaIdx)...])
                            if let imgData = Data(base64Encoded: b64), let nsImg = NSImage(data: imgData) {
                                previews[digit] = nsImg
                            }
                        }
                    }
                }
                let themeInfo = PasscodeThemeInfo(
                    name: name,
                    filePath: url.path,
                    detectedVersion: detectedVersion,
                    fileCount: fileCount,
                    keysPreview: previews
                )
                await MainActor.run {
                    self.loadedPasscodeTheme = themeInfo
                    self.isInspectingTheme = false
                    self.statusText = "Loaded passcode theme '\(name)' (\(fileCount) assets)"
                    self.log("Loaded .passthm: \(name) [\(detectedVersion)] with \(fileCount) image assets")
                }
            } else {
                await MainActor.run {
                    self.isInspectingTheme = false
                    self.errorMessage = "Failed to inspect .passthm file"
                }
            }
        }
    }
    
    func flashPasscodeTheme() {
        guard let theme = loadedPasscodeTheme else { return }
        guard let dev = device, dev.connected, let udid = dev.udid else {
            errorMessage = "Please connect and trust your iPhone first."
            return
        }
        
        isFlashing = true
        showLogs = true
        progress = 0.0
        statusText = "Starting passcode theme flash..."
        log("Flashing passcode theme '\(theme.name)' to device...")
        let scriptDir = self.scriptDir
        let targetVer = self.targetTelephonyVersion
        
        Task.detached {
            let proc = Process()
            proc.executableURL = AppViewModel.pythonExecutableURL
            proc.environment = AppViewModel.processEnvironment
            proc.currentDirectoryURL = URL(fileURLWithPath: scriptDir)
            proc.arguments = ["aircard_backend.py", "--flash-passthm", udid, theme.filePath, targetVer]
            
            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = Pipe()
            try? proc.run()
            
            let handle = pipe.fileHandleForReading
            var lineBuffer = ""
            
            let handleJSONLine: (String) async -> Void = { line in
                guard !line.isEmpty,
                      let lineData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                      let msg = json["message"] as? String else { return }
                
                let step = (json["step"] as? NSNumber)?.doubleValue
                let total = (json["total"] as? NSNumber)?.doubleValue
                
                await MainActor.run {
                    if let step = step, let total = total, total > 0 {
                        self.progress = min(step / total, 1.0)
                    }
                    self.statusText = msg
                    self.log("  \(msg)")
                }
            }
            
            let processChunk: (Data) async -> Void = { data in
                guard let chunkStr = String(data: data, encoding: .utf8) else { return }
                lineBuffer += chunkStr
                let parts = lineBuffer.components(separatedBy: .newlines)
                if parts.count > 1 {
                    for line in parts.dropLast() {
                        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            await handleJSONLine(trimmed)
                        }
                    }
                    lineBuffer = parts.last ?? ""
                }
            }
            
            while proc.isRunning {
                let data = handle.availableData
                if data.isEmpty { usleep(50000); continue }
                await processChunk(data)
            }
            
            let remaining = handle.readDataToEndOfFile()
            if !remaining.isEmpty {
                await processChunk(remaining)
            }
            let finalLine = lineBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !finalLine.isEmpty {
                await handleJSONLine(finalLine)
            }
            
            proc.waitUntilExit()
            
            await MainActor.run {
                self.isFlashing = false
                self.progress = 1.0
                self.statusText = "Passcode theme applied successfully!"
                self.showSuccessAlert = true
                self.log("Passcode theme '\(theme.name)' successfully flashed!")
            }
        }
    }
    
    // MARK: - Theme Creator Methods
    
    var effectiveCreatorKeys: [String: NSImage] {
        if creatorSubMode == .posterSlice {
            return creatorSlicedKeys
        } else {
            return creatorCustomKeys
        }
    }
    
    func updatePosterSlicing() {
        guard let img = creatorPosterImage else {
            creatorSlicedKeys = [:]
            return
        }
        creatorSlicedKeys = KeypadSlicer.slicePoster(
            image: img,
            zoom: creatorPosterZoom,
            offset: creatorPosterOffset,
            maskToCircles: creatorMaskToCircles
        )
    }
    
    func setPosterImage(_ img: NSImage) {
        creatorPosterImage = img
        creatorPosterZoom = 1.0
        creatorPosterOffset = .zero
        updatePosterSlicing()
        statusText = "Poster image loaded · Ready to frame and slice"
    }
    
    func setIndividualKey(digit: String, image: NSImage) {
        if let cropped = KeypadSlicer.cropToCircle(image: image) {
            creatorCustomKeys[digit] = cropped
            statusText = "Updated key \(digit)"
        }
    }
    
    func clearIndividualKey(digit: String) {
        creatorCustomKeys.removeValue(forKey: digit)
        statusText = "Cleared key \(digit)"
    }
    
    func adoptPosterSlicesToIndividualKeys() {
        if creatorCustomKeys.isEmpty && !creatorSlicedKeys.isEmpty {
            creatorCustomKeys = creatorSlicedKeys
        } else {
            for (k, v) in creatorSlicedKeys {
                if creatorCustomKeys[k] == nil {
                    creatorCustomKeys[k] = v
                }
            }
        }
        statusText = "Adopted poster slices to individual keys"
    }
    
    func clearCreator() {
        creatorPosterImage = nil
        creatorPosterZoom = 1.0
        creatorPosterOffset = .zero
        creatorCustomKeys = [:]
        creatorSlicedKeys = [:]
        statusText = "Theme Creator reset"
    }
    
    func flashCreatedTheme() {
        let keys = effectiveCreatorKeys
        guard !keys.isEmpty else {
            errorMessage = "Please add at least one key icon or import a poster image first."
            return
        }
        guard let dev = device, dev.connected, dev.udid != nil else {
            errorMessage = "Please connect and trust your iPhone first."
            return
        }
        
        guard let stagedURL = PasscodeThemeExporter.stageTemporaryTheme(keys: keys) else {
            errorMessage = "Failed to package theme for flashing."
            return
        }
        
        let themeInfo = PasscodeThemeInfo(
            name: "Created Theme",
            filePath: stagedURL.path,
            detectedVersion: targetTelephonyVersion,
            fileCount: keys.count * 4,
            keysPreview: keys
        )
        self.loadedPasscodeTheme = themeInfo
        self.flashPasscodeTheme()
    }
}

// MARK: - Card View Component (Apple Wallet Style)

struct WalletCardView: View {
    @Binding var card: CardItem
    let cardIndex: Int
    let onPickImage: () -> Void
    let onClearImage: () -> Void
    let onDelete: () -> Void
    
    @State private var isHovered = false
    @State private var isTargeted = false
    @State private var copied = false
    
    var body: some View {
        VStack(spacing: 10) {
            // Card Mockup
            ZStack {
                if let img = card.customImage {
                    // Custom Skin Applied
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 290, height: 182)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Subtle Gloss
                        LinearGradient(
                            colors: [.white.opacity(0.18), .clear, .black.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        
                        // Top Right Clear Button
                        Button(action: onClearImage) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white.opacity(0.9))
                                .background(Circle().fill(Color.black.opacity(0.55)))
                        }
                        .buttonStyle(.plain)
                        .padding(10)
                        .help("Remove skin")
                        
                        // Hover overlay: Change Skin
                        if isHovered {
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Label("Change Skin", systemImage: "photo.badge.arrow.forward")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(.ultraThinMaterial)
                                        .cornerRadius(20)
                                        .shadow(radius: 4)
                                    Spacer()
                                }
                                .padding(.bottom, 12)
                            }
                        }
                    }
                } else {
                    // Empty / Placeholder Card Mockup
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(NSColor.controlBackgroundColor),
                                        Color(NSColor.windowBackgroundColor).opacity(0.8)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isTargeted ? Color.accentColor : (isHovered ? Color.secondary.opacity(0.4) : Color.secondary.opacity(0.2)),
                                style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: card.customImage == nil ? [6, 4] : [])
                            )
                        
                        // Card Chip & Contactless indicator
                        VStack(alignment: .leading) {
                            HStack {
                                Image(systemName: "wave.3.right")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary.opacity(0.5))
                                Spacer()
                                Image(systemName: "creditcard")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary.opacity(0.4))
                            }
                            .padding(14)
                            Spacer()
                        }
                        
                        // Center Action
                        VStack(spacing: 8) {
                            Image(systemName: isHovered || isTargeted ? "photo.badge.plus" : "plus.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(isTargeted ? .accentColor : (isHovered ? .accentColor : .secondary.opacity(0.7)))
                                .scaleEffect(isHovered ? 1.08 : 1.0)
                                .animation(.spring(response: 0.3), value: isHovered)
                            
                            Text(isTargeted ? "Drop image here" : "Assign Card Skin")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text("Click to browse or drag image")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 290, height: 182)
                }
            }
            .frame(width: 290, height: 182)
            .shadow(color: .black.opacity(isHovered ? 0.22 : 0.12), radius: isHovered ? 10 : 5, y: isHovered ? 5 : 2)
            .onHover { h in isHovered = h }
            .onTapGesture { onPickImage() }
            .onDrop(of: [UTType.image], isTargeted: $isTargeted) { providers in
                if let provider = providers.first {
                    provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) { item, _ in
                        if let url = item as? URL {
                            Task { @MainActor in
                                card.customImageURL = url
                                card.customImage = NSImage(contentsOf: url)
                                card.isSelected = true
                            }
                        }
                    }
                    return true
                }
                return false
            }
            
            // Bottom Info & Controls
            HStack(spacing: 8) {
                Toggle("", isOn: $card.isSelected)
                    .labelsHidden()
                    .help("Include in flash")
                
                Text("Card #\(cardIndex + 1)")
                    .font(.system(size: 12, weight: .semibold))
                
                // Monospace Hash Pill with Copy
                HStack(spacing: 4) {
                    Text(card.id.prefix(8) + "…" + card.id.suffix(6))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(card.id, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 9))
                            .foregroundColor(copied ? .green : .secondary)
                    }
                    .buttonStyle(.plain)
                    .help(copied ? "Copied!" : "Copy full hash")
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(6)
                
                Spacer()
                
                // Status badge
                if card.customImage != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 12))
                        .help("Skin assigned and ready")
                }
                
                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Remove from list")
            }
            .padding(.horizontal, 4)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.controlBackgroundColor).opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(card.isSelected ? Color.accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - Main UI View

struct ContentView: View {
    @StateObject private var vm = AppViewModel()
    @State private var showCredits = false
    @State private var dragOffsetStart: CGPoint = .zero
    @State private var isTargetedPoster = false
    
    private var readyToFlashCount: Int {
        vm.cards.filter { $0.isSelected && $0.customImageURL != nil }.count
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 1. Top Header Bar
            headerView
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 2. Control Toolbar (for Wallet Cards)
            if vm.selectedTab == .walletCards {
                toolbarView
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // 3. Live Scanner Notice Banner (if active)
                if vm.isScanningCards {
                    scanningNoticeBanner
                }
            } else {
                passcodeToolbarView
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
            }
            
            // 4. Main Workspace
            if vm.selectedTab == .walletCards {
                ScrollView {
                    if vm.cards.isEmpty {
                        emptyStateView
                            .padding(.top, 40)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 310, maximum: 360), spacing: 20)],
                            spacing: 20
                        ) {
                            ForEach(Array(vm.cards.indices), id: \.self) { idx in
                                WalletCardView(
                                    card: $vm.cards[idx],
                                    cardIndex: idx,
                                    onPickImage: { openCardImagePicker(for: vm.cards[idx].id) },
                                    onClearImage: { vm.clearCardImage(for: vm.cards[idx].id) },
                                    onDelete: { vm.deleteCard(id: vm.cards[idx].id) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                passcodeThemeWorkspaceView
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            
            // 5. Collapsible Activity Console (if open or flashing)
            if vm.showLogs {
                Divider()
                activityLogView
            }
            
            Divider()
            
            // 6. Bottom Action & Status Bar
            bottomBarView
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 780, minHeight: 640)
        .alert("Success!", isPresented: $vm.showSuccessAlert) {
            Button("OK") {}
        } message: {
            if vm.selectedTab == .passcodeThemes {
                Text("Passcode theme successfully applied!\n\nLock your iPhone (and make sure Bold Text is turned OFF in Settings) to see your new passcode keypad.")
            } else {
                Text("Skins successfully applied to all selected cards!\n\nPlease force-close the Wallet app on your iPhone (or reboot) to see your new designs.")
            }
        }
        .sheet(isPresented: $showCredits) {
            creditsSheet
        }
        .sheet(isPresented: $vm.showAddCardSheet) {
            addCardSheet
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 30))
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("AirCard")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("v1.1")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.15))
                        .foregroundColor(.accentColor)
                        .clipShape(Capsule())
                }
                Text("Wallet Cards & Passcode Themes")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Tab Switcher
            Picker("", selection: $vm.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 290)
            
            Spacer()
            
            // Device Status Capsule
            HStack(spacing: 8) {
                Circle()
                    .fill(vm.device?.connected == true ? Color.green : Color.red)
                    .frame(width: 8, height: 8)
                
                if let dev = vm.device, dev.connected {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(dev.name ?? "iPhone")
                            .font(.system(size: 11, weight: .semibold))
                        Text("\(dev.product ?? "") · iOS \(dev.version ?? "")")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("No iPhone (USB)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: { vm.checkDevice() }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .disabled(vm.isCheckingDevice)
                .help("Refresh device connection")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(16)
            
            Button(action: { showCredits = true }) {
                Label("Credits", systemImage: "heart.fill")
                    .foregroundColor(.pink)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    private var toolbarView: some View {
        HStack(spacing: 12) {
            // Live Scanner Toggle
            Button(action: { vm.toggleCardScanning() }) {
                HStack(spacing: 6) {
                    if vm.isScanningCards {
                        ProgressView()
                            .scaleEffect(0.65)
                    } else {
                        Image(systemName: "wave.3.forward.circle.fill")
                    }
                    Text(vm.isScanningCards ? "Stop Scanning" : "Scan Cards")
                        .fontWeight(.semibold)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(vm.isScanningCards ? .red : .blue)
            .controlSize(.regular)
            .disabled(vm.device?.connected != true)
            
            Button(action: { vm.showAddCardSheet = true }) {
                Label("Add Manually", systemImage: "plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            
            if !vm.cards.isEmpty {
                Button(action: openBulkImagePicker) {
                    Label("Set Skin for All...", systemImage: "photo.on.rectangle.angled")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Assign one skin to all selected cards")
            }
            
            Spacer()
            
            if !vm.cards.isEmpty {
                HStack(spacing: 8) {
                    Button("Select All") {
                        for idx in vm.cards.indices { vm.cards[idx].isSelected = true }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    
                    Text("·").foregroundColor(.secondary)
                    
                    Button("Deselect All") {
                        for idx in vm.cards.indices { vm.cards[idx].isSelected = false }
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    
                    Text("·").foregroundColor(.secondary)
                    
                    Button("Clear All") {
                        vm.clearAllCards()
                    }
                    .buttonStyle(.link)
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
    }
    
    private var scanningNoticeBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "iphone.radiowaves.left.and.right")
                .font(.system(size: 20))
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Live Scanner Active")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
                Text("Double-click Side button (Apple Pay), pass Face ID, then tap your card.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Done") {
                vm.stopCardScanning()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 18) {
            Image(systemName: "creditcard.viewfinder")
                .font(.system(size: 54))
                .foregroundColor(.accentColor.opacity(0.8))
            
            Text("No Cards Detected Yet")
                .font(.title3)
                .fontWeight(.bold)
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Text("1.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("Click **Scan Cards** in the toolbar above.")
                }
                HStack(alignment: .top, spacing: 10) {
                    Text("2.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("On your iPhone, **double-click the Side button** (Apple Pay), authenticate with **Face ID**, and **tap your card**.")
                }
                HStack(alignment: .top, spacing: 10) {
                    Text("3.")
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    Text("Your card will be detected immediately!")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
            .frame(maxWidth: 460)
            .padding(20)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            
            HStack(spacing: 12) {
                Button(action: { vm.startCardScanning() }) {
                    Label("Start Scanning", systemImage: "wave.3.forward.circle.fill")
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.device?.connected != true)
                
                Button("Add Hashes Manually") {
                    vm.showAddCardSheet = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(40)
    }
    
    // MARK: - Passcode Views
    
    private var passcodeToolbarView: some View {
        HStack(spacing: 12) {
            // Mode Switcher: [Apply .passthm] | [Theme Creator]
            Picker("", selection: $vm.passcodeTabMode) {
                ForEach(PasscodeTabMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 250)
            
            Divider()
                .frame(height: 18)
            
            if vm.passcodeTabMode == .applyTheme {
                Button(action: { openPasscodeThemePicker() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                        Text("Choose .passthm File")
                            .fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                
                if vm.loadedPasscodeTheme != nil {
                    Button(action: { vm.loadedPasscodeTheme = nil }) {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                            Text("Clear Theme")
                        }
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                // Theme Creator Sub-Mode Picker
                Picker("", selection: $vm.creatorSubMode) {
                    ForEach(CreatorSubMode.allCases) { subMode in
                        Text(subMode.rawValue).tag(subMode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
                
                if vm.creatorSubMode == .posterSlice && vm.creatorPosterImage != nil {
                    Button(action: { openPosterPicker() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "photo")
                            Text("Change Poster...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            Spacer()
            
            // Target Version Picker
            HStack(spacing: 6) {
                Text("Target:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $vm.targetTelephonyVersion) {
                    Text("TelephonyUI-10 (iOS 18+)").tag("TelephonyUI-10")
                    Text("TelephonyUI-9 (iOS 16–17)").tag("TelephonyUI-9")
                }
                .pickerStyle(.menu)
                .frame(width: 200)
            }
        }
    }
    
    private var passcodeThemeWorkspaceView: some View {
        Group {
            if vm.passcodeTabMode == .applyTheme {
                passcodeApplyThemeWorkspaceView
            } else {
                passcodeThemeCreatorWorkspaceView
            }
        }
    }
    
    // MARK: - Apply Theme Mode
    
    private var passcodeApplyThemeWorkspaceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Loaded Theme Banner or Drop Target
                if let theme = vm.loadedPasscodeTheme {
                    HStack(spacing: 16) {
                        Image(systemName: "lock.square.stack.fill")
                            .font(.system(size: 34))
                            .foregroundColor(.purple)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 8) {
                                Text(theme.name)
                                    .font(.headline)
                                    .fontWeight(.bold)
                                
                                Text(theme.detectedVersion)
                                    .font(.system(size: 10, weight: .semibold))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.15))
                                    .foregroundColor(.purple)
                                    .cornerRadius(6)
                            }
                            
                            Text("\(theme.fileCount) artwork assets loaded · Ready to flash to iPhone")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button("Change...") {
                            openPasscodeThemePicker()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(NSColor.controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                } else {
                    // Empty Drop Target
                    VStack(spacing: 12) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor.opacity(0.8))
                        
                        Text("Drag & Drop your .passthm file here")
                            .font(.headline)
                        
                        Text("Supports .passthm, .passtheme, or .zip passcode themes from Cowabunga / TrollTools / Nugget")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("Choose .passthm File...") {
                            openPasscodeThemePicker()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.accentColor.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            .background(Color(NSColor.controlBackgroundColor).opacity(0.3).cornerRadius(16))
                    )
                    .padding(.horizontal, 24)
                }
                
                // Keypad Interactive Preview (3x4 Phone Passcode Style)
                VStack(spacing: 14) {
                    HStack {
                        Text("Lock Screen Keypad Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        Spacer()
                        if vm.loadedPasscodeTheme != nil {
                            Text("Custom Artwork Loaded")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(.horizontal, 10)
                    
                    passcodeKeypadGrid
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                boldTextWarningBox
            }
            .padding(.top, 16)
        }
        .onDrop(of: [UTType.fileURL, UTType.data], isTargeted: nil) { providers in
            if let provider = providers.first {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            vm.inspectPasscodeTheme(url: url)
                        }
                    } else if let url = item as? URL {
                        Task { @MainActor in
                            vm.inspectPasscodeTheme(url: url)
                        }
                    }
                }
                return true
            }
            return false
        }
    }
    
    private var passcodeKeypadGrid: some View {
        let keysLayout: [[(digit: String, letters: String)]] = [
            [("1", ""), ("2", "A B C"), ("3", "D E F")],
            [("4", "G H I"), ("5", "J K L"), ("6", "M N O")],
            [("7", "P Q R S"), ("8", "T U V"), ("9", "W X Y Z")],
            [("", ""), ("0", "+"), ("", "")]
        ]
        
        return VStack(spacing: 12) {
            ForEach(0..<keysLayout.count, id: \.self) { rowIdx in
                HStack(spacing: 22) {
                    ForEach(0..<keysLayout[rowIdx].count, id: \.self) { colIdx in
                        let item = keysLayout[rowIdx][colIdx]
                        if item.digit.isEmpty {
                            Color.clear
                                .frame(width: 68, height: 68)
                        } else {
                            passcodeKeyView(digit: item.digit, letters: item.letters)
                        }
                    }
                }
            }
        }
    }
    
    private func passcodeKeyView(digit: String, letters: String) -> some View {
        let customImage = vm.loadedPasscodeTheme?.keysPreview[digit]
        
        return ZStack {
            if let img = customImage {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 68, height: 68)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: 68, height: 68)
                    .overlay(Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                
                VStack(spacing: 1) {
                    Text(digit)
                        .font(.system(size: 26, weight: .light))
                    if !letters.isEmpty {
                        Text(letters)
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(1)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .frame(width: 68, height: 68)
        .shadow(color: Color.black.opacity(0.08), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Theme Creator Mode
    
    private var passcodeThemeCreatorWorkspaceView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Bar for Creator
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(vm.creatorSubMode == .posterSlice ? "Poster Slice Mode" : "Individual Keys Mode")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(vm.creatorSubMode == .posterSlice
                             ? "Position and slice a wallpaper across the iOS lock screen dialer grid"
                             : "Customize each digit key individually with custom icons or images")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Clear All") {
                        vm.clearCreator()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.effectiveCreatorKeys.isEmpty && vm.creatorPosterImage == nil)
                    
                    Button(action: { openSavePasscodeThemePanel() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export .passthm...")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(vm.effectiveCreatorKeys.isEmpty)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 24)
                
                if vm.creatorSubMode == .posterSlice {
                    posterSliceView
                } else {
                    individualKeysView
                }
                
                boldTextWarningBox
            }
            .padding(.top, 16)
        }
    }
    
    // MARK: - Poster Slice Mode View
    
    private var posterSliceView: some View {
        VStack(spacing: 18) {
            if vm.creatorPosterImage == nil {
                // Drop Target & File Picker for Poster Image
                VStack(spacing: 12) {
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.purple.opacity(0.8))
                    
                    Text("Drag & Drop Poster Image or Wallpaper")
                        .font(.headline)
                    
                    Text("Drop any photo or wallpaper (PNG, JPG, HEIC, WebP) to slice seamlessly across all 10 passcode keys")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                    
                    Button("Choose Poster Image...") {
                        openPosterPicker()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.regular)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 36)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isTargetedPoster ? Color.purple : Color.purple.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [8]))
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.3).cornerRadius(16))
                )
                .padding(.horizontal, 24)
                .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: $isTargetedPoster) { providers in
                    handlePosterDrop(providers: providers)
                }
            } else {
                // Controls Bar when poster is loaded
                HStack(spacing: 14) {
                    Button("Change Poster...") {
                        openPosterPicker()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Button("Reset Position") {
                        withAnimation(.spring()) {
                            vm.creatorPosterZoom = 1.0
                            vm.creatorPosterOffset = .zero
                            dragOffsetStart = .zero
                            vm.updatePosterSlicing()
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    
                    Spacer()
                    
                    // Style Picker: Seamless vs Circle Buttons
                    Picker("Style", selection: $vm.creatorMaskToCircles) {
                        Text("Seamless Poster").tag(false)
                        Text("Circle Buttons").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 210)
                    .onChange(of: vm.creatorMaskToCircles) { _, _ in
                        vm.updatePosterSlicing()
                    }
                    
                    // Zoom slider
                    HStack(spacing: 6) {
                        Image(systemName: "minus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Slider(value: $vm.creatorPosterZoom, in: 0.5...3.0, step: 0.05) {
                            Text("Zoom")
                        }
                        .frame(width: 110)
                        .onChange(of: vm.creatorPosterZoom) { _, _ in
                            vm.updatePosterSlicing()
                        }
                        
                        Image(systemName: "plus.magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text(String(format: "%.1fx", vm.creatorPosterZoom))
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .frame(width: 32, alignment: .trailing)
                    }
                    
                    Button(action: {
                        vm.adoptPosterSlicesToIndividualKeys()
                        vm.creatorSubMode = .individualKeys
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "square.grid.3x3.fill")
                            Text("Edit Individual Keys")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 24)
                
                // Interactive Lock Screen Dialer Preview
                VStack(spacing: 10) {
                    HStack {
                        Text("Live Lock Screen Dialer Preview")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("Drag anywhere on the dialer to reposition the image")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    
                    posterKeypadLivePreview
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
                )
                .padding(.horizontal, 24)
            }
        }
    }
    
    private var posterKeypadLivePreview: some View {
        let keysLayout: [[(digit: String, letters: String)]] = [
            [("1", ""), ("2", "A B C"), ("3", "D E F")],
            [("4", "G H I"), ("5", "J K L"), ("6", "M N O")],
            [("7", "P Q R S"), ("8", "T U V"), ("9", "W X Y Z")],
            [("", ""), ("0", "+"), ("", "")]
        ]
        
        let containerW: CGFloat = KeypadLayout.gridWidth + 36
        let containerH: CGFloat = KeypadLayout.gridHeight + 170
        
        return ZStack {
            // Background Wallpaper / Image (Seamless Character / Poster)
            if let poster = vm.creatorPosterImage {
                GeometryReader { geo in
                    let baseScale = max(geo.size.width / poster.size.width, geo.size.height / poster.size.height)
                    let scale = baseScale * CGFloat(vm.creatorPosterZoom)
                    let scaledW = poster.size.width * scale
                    let scaledH = poster.size.height * scale
                    Image(nsImage: poster)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: scaledW, height: scaledH)
                        .position(
                            x: geo.size.width / 2.0 + vm.creatorPosterOffset.x,
                            y: geo.size.height / 2.0 + vm.creatorPosterOffset.y
                        )
                }
                .clipped()
            } else {
                Color.black.opacity(0.9)
            }
            
            // Subtle frosted overlay to ensure key typography readability
            Color.black.opacity(0.2)
            
            // Lock Screen UI Overlay
            VStack(spacing: 0) {
                // Lock Screen Header
                VStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.95))
                    
                    Text("Enter Passcode")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.white.opacity(0.95))
                    
                    // Passcode 6-Dot Indicator
                    HStack(spacing: 12) {
                        ForEach(0..<6, id: \.self) { _ in
                            Circle()
                                .stroke(Color.white.opacity(0.75), lineWidth: 1.5)
                                .frame(width: 10, height: 10)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding(.top, 18)
                
                Spacer()
                
                // 3x4 Authentic Keypad Grid
                VStack(spacing: KeypadLayout.rowHeight - KeypadLayout.buttonDiameter) {
                    ForEach(0..<keysLayout.count, id: \.self) { rowIdx in
                        HStack(spacing: KeypadLayout.colWidth - KeypadLayout.buttonDiameter) {
                            ForEach(0..<keysLayout[rowIdx].count, id: \.self) { colIdx in
                                let item = keysLayout[rowIdx][colIdx]
                                if item.digit.isEmpty {
                                    Color.clear
                                        .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                                } else {
                                    posterLiveKeyView(digit: item.digit, letters: item.letters)
                                }
                            }
                        }
                    }
                }
                
                Spacer()
                
                // Lock Screen Footer Actions
                HStack {
                    Text("Emergency")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                    Spacer()
                    Text("Cancel")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 16)
            }
        }
        .frame(width: containerW, height: containerH)
        .clipShape(RoundedRectangle(cornerRadius: 36, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.45), radius: 20, x: 0, y: 10)
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    vm.creatorPosterOffset = CGPoint(
                        x: dragOffsetStart.x + value.translation.width,
                        y: dragOffsetStart.y + value.translation.height
                    )
                    vm.updatePosterSlicing()
                }
                .onEnded { _ in
                    dragOffsetStart = vm.creatorPosterOffset
                }
        )
        .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: nil) { providers in
            handlePosterDrop(providers: providers)
        }
    }
    
    private func posterLiveKeyView(digit: String, letters: String) -> some View {
        ZStack {
            // Frosted translucent key circle
            Circle()
                .fill(Color.white.opacity(0.2))
                .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
            
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
            
            // If user explicitly chose Circular Cutouts, show circle-masked preview
            if vm.creatorMaskToCircles, let img = vm.creatorSlicedKeys[digit] {
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                    .clipShape(Circle())
            }
            
            VStack(spacing: 1) {
                Text(digit)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(.white)
                if !letters.isEmpty {
                    Text(letters)
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
    }
    
    // MARK: - Individual Keys Mode View
    
    private var individualKeysView: some View {
        let keysLayout: [[(digit: String, letters: String)]] = [
            [("1", ""), ("2", "A B C"), ("3", "D E F")],
            [("4", "G H I"), ("5", "J K L"), ("6", "M N O")],
            [("7", "P Q R S"), ("8", "T U V"), ("9", "W X Y Z")],
            [("", ""), ("0", "+"), ("", "")]
        ]
        
        return VStack(spacing: 18) {
            // Helper Controls Bar
            HStack(spacing: 14) {
                HStack(spacing: 6) {
                    Image(systemName: "hand.tap.fill")
                        .foregroundColor(.accentColor)
                    Text("\(vm.creatorCustomKeys.count) of 10 keys customized")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                if !vm.creatorSlicedKeys.isEmpty {
                    Button("Fill from Poster Slices") {
                        vm.adoptPosterSlicesToIndividualKeys()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                Button("Clear All Keys") {
                    vm.creatorCustomKeys.removeAll()
                    vm.statusText = "All individual keys cleared"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(vm.creatorCustomKeys.isEmpty)
            }
            .padding(.horizontal, 24)
            
            // 3x4 Grid
            VStack(spacing: 14) {
                HStack {
                    Text("Interactive Keypad (Click or drop images onto any key)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                
                individualKeysGrid(layout: keysLayout)
                .padding(.vertical, 8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(NSColor.separatorColor).opacity(0.5), lineWidth: 1)
            )
            .padding(.horizontal, 24)
        }
    }
    
    private func individualKeysGrid(layout: [[(digit: String, letters: String)]]) -> some View {
        VStack(spacing: KeypadLayout.verticalSpacing) {
            ForEach(0..<layout.count, id: \.self) { rowIdx in
                individualKeyRow(rowItems: layout[rowIdx])
            }
        }
    }
    
    private func individualKeyRow(rowItems: [(digit: String, letters: String)]) -> some View {
        HStack(spacing: KeypadLayout.horizontalSpacing) {
            ForEach(0..<rowItems.count, id: \.self) { colIdx in
                let item = rowItems[colIdx]
                if item.digit.isEmpty {
                    Color.clear
                        .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                } else {
                    individualKeySlot(digit: item.digit, letters: item.letters)
                }
            }
        }
    }
    
    private func individualKeySlot(digit: String, letters: String) -> some View {
        let customImage = vm.creatorCustomKeys[digit]
        
        return ZStack(alignment: .topTrailing) {
            Button(action: { openIndividualKeyPicker(for: digit) }) {
                ZStack {
                    if let img = customImage {
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                            .clipShape(Circle())
                        
                        Circle()
                            .stroke(Color.purple.opacity(0.6), lineWidth: 2)
                            .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                        
                        VStack(spacing: 1) {
                            Text(digit)
                                .font(.system(size: 26, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                            if !letters.isEmpty {
                                Text(letters)
                                    .font(.system(size: 9, weight: .bold))
                                    .tracking(1)
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                            }
                        }
                    } else {
                        Circle()
                            .fill(Color(NSColor.controlBackgroundColor))
                            .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                        
                        Circle()
                            .stroke(Color.secondary.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [4]))
                            .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
                        
                        VStack(spacing: 2) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.accentColor)
                            Text(digit)
                                .font(.system(size: 22, weight: .light))
                            if !letters.isEmpty {
                                Text(letters)
                                    .font(.system(size: 8, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .help("Click or drag an image here to customize key \(digit)")
            .onDrop(of: [UTType.fileURL, UTType.image], isTargeted: nil) { providers in
                handleIndividualKeyDrop(digit: digit, providers: providers)
            }
            
            // Delete button for this key
            if customImage != nil {
                Button(action: { vm.clearIndividualKey(digit: digit) }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.red)
                        .background(Circle().fill(Color.white))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
                .help("Remove custom icon for key \(digit)")
            }
        }
        .frame(width: KeypadLayout.buttonDiameter, height: KeypadLayout.buttonDiameter)
    }
    
    // MARK: - Warning Banner
    
    private var boldTextWarningBox: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.title3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Important Requirement: Turn OFF Bold Text")
                    .font(.caption)
                    .fontWeight(.bold)
                Text("On your iPhone, navigate to **Settings ➔ Display & Brightness** and ensure **Bold Text is turned OFF**. Otherwise, iOS overrides cached keypad graphics with standard vector fonts.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.orange.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.orange.opacity(0.3), lineWidth: 1))
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }
    
    private var activityLogView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Activity Log")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Clear") {
                    vm.logs.removeAll()
                }
                .buttonStyle(.link)
                .font(.caption2)
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(vm.logs.enumerated()), id: \.offset) { idx, log in
                            Text(log)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.secondary)
                                .id(idx)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
                .frame(height: 90)
                .onChange(of: vm.logs.count) { _, _ in
                    if let last = vm.logs.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
        }
        .background(Color(NSColor.textBackgroundColor))
    }
    
    private var bottomBarView: some View {
        VStack(spacing: 8) {
            if vm.isFlashing || vm.progress > 0 {
                ProgressView(value: vm.progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .animation(.easeInOut(duration: 0.2), value: vm.progress)
            }
            
            HStack(spacing: 16) {
                // Left Status Text
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(vm.statusText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if vm.isFlashing || vm.progress > 0 {
                            Text("\(Int(min(max(vm.progress, 0.0), 1.0) * 100))%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .monospacedDigit()
                        }
                    }
                    
                    if vm.selectedTab == .passcodeThemes {
                        if vm.passcodeTabMode == .themeCreator {
                            let count = vm.effectiveCreatorKeys.count
                            if count > 0 {
                                Text("Theme Creator · \(count) of 10 keys configured · Target: \(vm.targetTelephonyVersion)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Theme Creator · Import a poster or drop icons onto keys")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        } else if let theme = vm.loadedPasscodeTheme {
                            Text("\(theme.fileCount) assets ready · Target: \(vm.targetTelephonyVersion)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("No .passthm loaded · Select a theme package to flash")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    } else if !vm.cards.isEmpty {
                        Text("\(vm.cards.filter { $0.isSelected }.count) of \(vm.cards.count) cards selected · \(readyToFlashCount) ready to flash")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // Toggle Log Drawer
                Button(action: { withAnimation { vm.showLogs.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "terminal")
                        Text("Log")
                        Image(systemName: vm.showLogs ? "chevron.down" : "chevron.up")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // Apply / Flash Button
                if vm.selectedTab == .passcodeThemes {
                    if vm.passcodeTabMode == .themeCreator {
                        HStack(spacing: 8) {
                            Button(action: { vm.clearCreator() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash")
                                    Text("Clear All")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(vm.effectiveCreatorKeys.isEmpty && vm.creatorPosterImage == nil)
                            
                            Button(action: { openSavePasscodeThemePanel() }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Export .passthm...")
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(vm.effectiveCreatorKeys.isEmpty)
                            
                            Button(action: { vm.flashCreatedTheme() }) {
                                HStack(spacing: 6) {
                                    if vm.isFlashing {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "lock.shield.fill")
                                    }
                                    Text(vm.isFlashing ? "Flashing Passcode..." : "Flash to iPhone")
                                        .fontWeight(.semibold)
                                }
                                .padding(.horizontal, 8)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.purple)
                            .controlSize(.regular)
                            .disabled(vm.effectiveCreatorKeys.isEmpty || vm.isFlashing || vm.device?.connected != true)
                        }
                    } else {
                        Button(action: { vm.flashPasscodeTheme() }) {
                            HStack(spacing: 6) {
                                if vm.isFlashing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "lock.shield.fill")
                                }
                                Text(vm.isFlashing ? "Flashing Passcode..." : "Flash Passcode Theme")
                                    .fontWeight(.semibold)
                            }
                            .padding(.horizontal, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                        .controlSize(.regular)
                        .disabled(vm.loadedPasscodeTheme == nil || vm.isFlashing || vm.device?.connected != true)
                    }
                } else {
                    Button(action: { vm.applySkin() }) {
                        HStack(spacing: 6) {
                            if vm.isFlashing {
                                ProgressView()
                                    .scaleEffect(0.7)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(vm.isFlashing ? "Flashing Cards..." : (readyToFlashCount > 0 ? "Flash Skins (\(readyToFlashCount) Cards)" : "Flash Skins"))
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.regular)
                    .disabled(readyToFlashCount == 0 || vm.isFlashing || vm.device?.connected != true)
                }
            }
            
            // Subtle Footer Credits
            HStack {
                Spacer()
                HStack(spacing: 4) {
                    Text("By")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Link("@mak5er", destination: URL(string: "https://github.com/mak5er")!)
                        .font(.system(size: 10))
                    Text("&")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Link("@Lumid-Off", destination: URL(string: "https://github.com/Lumid-Off")!)
                        .font(.system(size: 10))
                }
            }
        }
    }
    
    // MARK: - Sheets & Pickers
    
    private var creditsSheet: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard.circle.fill")
                .font(.system(size: 44))
                .foregroundColor(.accentColor)
            
            Text("AirCard")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("Custom Apple Wallet Card Skinner (iOS 18+ via airlift)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.blue)
                    Text("Developer:")
                        .fontWeight(.medium)
                    Link("@mak5er", destination: URL(string: "https://github.com/mak5er")!)
                    Text("·")
                        .foregroundColor(.secondary)
                    Link("Twitter / X", destination: URL(string: "https://x.com/mak5er")!)
                }
                
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundColor(.blue)
                    Text("Developer:")
                        .fontWeight(.medium)
                    Link("@Lumid-Off", destination: URL(string: "https://github.com/Lumid-Off")!)
                    Text("·")
                        .foregroundColor(.secondary)
                    Link("Twitter / X", destination: URL(string: "https://x.com/LumidOff")!)
                }
                
                HStack {
                    Image(systemName: "bolt.shield.fill")
                        .foregroundColor(.orange)
                    Text("Core Exploit:")
                        .fontWeight(.medium)
                    Text("airlift (AirTraffic sync escape)")
                        .foregroundColor(.secondary)
                }
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 8)
            
            Divider()
            
            Button("Close") {
                showCredits = false
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(24)
        .frame(width: 380)
    }
    
    private var addCardSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add Card Hashes Manually")
                .font(.headline)
            Text("Paste one or more card hashes (separated by spaces, commas, or newlines):")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextEditor(text: $vm.manualHashInput)
                .font(.system(.body, design: .monospaced))
                .frame(height: 120)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
            
            HStack {
                Button("Cancel") {
                    vm.showAddCardSheet = false
                    vm.manualHashInput = ""
                }
                Spacer()
                Button("Add to List") {
                    vm.addCardHash(vm.manualHashInput)
                    vm.showAddCardSheet = false
                    vm.manualHashInput = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(vm.manualHashInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 440)
    }
    
    private func openCardImagePicker(for cardId: String) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a custom skin for card \(cardId.prefix(12))..."
        if panel.runModal() == .OK, let url = panel.url {
            vm.setCardImage(for: cardId, url: url)
        }
    }
    
    private func openBulkImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a skin to assign to all selected cards..."
        if panel.runModal() == .OK, let url = panel.url {
            for card in vm.cards where card.isSelected {
                vm.setCardImage(for: card.id, url: url)
            }
        }
    }
    
    private func openPasscodeThemePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "passthm") ?? .data,
            UTType(filenameExtension: "passtheme") ?? .data,
            .zip
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a .passthm passcode theme package..."
        if panel.runModal() == .OK, let url = panel.url {
            vm.inspectPasscodeTheme(url: url)
        }
    }
    
    private func openPosterPicker() {
        let panel = NSOpenPanel()
        panel.title = "Choose Poster Image"
        panel.message = "Select a wallpaper or photo to slice for the passcode keypad..."
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType(filenameExtension: "heic") ?? .image,
            UTType(filenameExtension: "webp") ?? .image,
            .image
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            vm.setPosterImage(img)
        }
    }
    
    private func openIndividualKeyPicker(for digit: String) {
        let panel = NSOpenPanel()
        panel.title = "Choose Icon for Key \(digit)"
        panel.message = "Select an icon or image for key \(digit)..."
        panel.allowedContentTypes = [
            UTType.png,
            UTType.jpeg,
            UTType(filenameExtension: "heic") ?? .image,
            UTType(filenameExtension: "webp") ?? .image,
            .image
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            vm.setIndividualKey(digit: digit, image: img)
        }
    }
    
    private func openSavePasscodeThemePanel() {
        let keys = vm.effectiveCreatorKeys
        guard !keys.isEmpty else {
            vm.errorMessage = "Please configure at least one key before exporting."
            return
        }
        
        let panel = NSSavePanel()
        panel.title = "Save Passcode Theme"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "CustomTheme.passthm"
        panel.allowedContentTypes = [UTType(filenameExtension: "passthm") ?? .data]
        panel.canCreateDirectories = true
        
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try PasscodeThemeExporter.exportTheme(keys: keys, targetURL: url)
                vm.statusText = "Theme exported successfully to \(url.lastPathComponent)"
                vm.log("Exported .passthm to \(url.path)")
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                vm.errorMessage = "Failed to export theme: \(error.localizedDescription)"
            }
        }
    }
    
    private func handlePosterDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        loadImage(from: provider) { img in
            if let img = img {
                vm.setPosterImage(img)
            }
        }
        return true
    }
    
    private func handleIndividualKeyDrop(digit: String, providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        loadImage(from: provider) { img in
            if let img = img {
                vm.setIndividualKey(digit: digit, image: img)
            }
        }
        return true
    }
    
    private func loadImage(from provider: NSItemProvider, completion: @escaping (NSImage?) -> Void) {
        if provider.canLoadObject(ofClass: URL.self) {
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                if let url = url, let img = NSImage(contentsOf: url) {
                    DispatchQueue.main.async { completion(img) }
                    return
                }
                if provider.canLoadObject(ofClass: NSImage.self) {
                    _ = provider.loadObject(ofClass: NSImage.self) { img, _ in
                        DispatchQueue.main.async { completion(img as? NSImage) }
                    }
                } else {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        } else if provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { img, _ in
                DispatchQueue.main.async { completion(img as? NSImage) }
            }
        } else {
            completion(nil)
        }
    }
}

// MARK: - App Entry Point

@main
struct AirCardApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
    }
}
