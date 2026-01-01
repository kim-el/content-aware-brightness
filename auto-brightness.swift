import Cocoa
import CoreGraphics
import Foundation
import ScreenCaptureKit
import IOKit
import IOKit.hid

// Force unbuffered output
setvbuf(stdout, nil, _IONBF, 0)

// ----------------------------------------------------------------------------
//  HID BRIGHTNESS KEY LISTENER
// ----------------------------------------------------------------------------

class BrightnessKeyListener {
    static let shared = BrightnessKeyListener()
    
    private var manager: IOHIDManager?
    private var cmdPressed: Bool = false  // Track Cmd key state
    var onBrightnessKeyPressed: (() -> Void)?
    var onTabChanged: (() -> Void)?  // New callback for Cmd+T/W
    
    func start() {
        manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        guard let manager = manager else { return }
        
        // Match all HID devices that can send consumer control events
        let matching: [[String: Any]] = [
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_GenericDesktop,
                kIOHIDDeviceUsageKey as String: kHIDUsage_GD_Keyboard
            ],
            [
                kIOHIDDeviceUsagePageKey as String: kHIDPage_Consumer,
                kIOHIDDeviceUsageKey as String: kHIDUsage_Csmr_ConsumerControl
            ]
        ]
        
        IOHIDManagerSetDeviceMatchingMultiple(manager, matching as CFArray)
        
        // Register callback for input values
        let callback: IOHIDValueCallback = { context, result, sender, value in
            let element = IOHIDValueGetElement(value)
            let usagePage = IOHIDElementGetUsagePage(element)
            let usage = IOHIDElementGetUsage(element)
            let intValue = IOHIDValueGetIntegerValue(value)
            let listener = Unmanaged<BrightnessKeyListener>.fromOpaque(context!).takeUnretainedValue()
            
            // Track Cmd key state (Left Cmd = 0xE3, Right Cmd = 0xE7)
            if usagePage == 0x07 && (usage == 0xE3 || usage == 0xE7) {
                listener.cmdPressed = (intValue == 1)
            }
            
            // Keyboard page (0x07) with F1 (0x3A = brightness down) or F2 (0x3B = brightness up)
            if usagePage == 0x07 && (usage == 0x3A || usage == 0x3B) && intValue == 1 {
                DispatchQueue.main.async {
                    print("🎹 Brightness key pressed! (F\(usage == 0x3A ? "1" : "2"))")
                    listener.onBrightnessKeyPressed?()
                }
            }
            
            // Cmd+T (T = 0x17) or Cmd+W (W = 0x1A) - tab open/close
            if usagePage == 0x07 && listener.cmdPressed && intValue == 1 {
                if usage == 0x17 {  // T key
                    DispatchQueue.main.async {
                        print("🔖 Cmd+T detected (new tab)")
                        listener.onTabChanged?()
                    }
                } else if usage == 0x1A {  // W key
                    DispatchQueue.main.async {
                        print("🔖 Cmd+W detected (close tab)")
                        listener.onTabChanged?()
                    }
                }
            }
        }
        
        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterInputValueCallback(manager, callback, context)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            print("🎹 HID listener started (brightness keys + Cmd+T/W)")
        } else {
            print("⚠️ HID manager open failed: \(openResult) - may need Accessibility permission")
        }
    }
}

// ----------------------------------------------------------------------------
//  WINDOW TITLE CHANGE OBSERVER
// ----------------------------------------------------------------------------

class WindowTitleObserver {
    static let shared = WindowTitleObserver()
    
    private var observer: AXObserver?
    private var currentApp: NSRunningApplication?
    private var debounceTimer: Timer?
    private var lastTitleChangeTime: Date = .distantPast
    var onTitleChanged: (() -> Void)?
    
    func start() {
        // Watch for app activations to set up observer on the new app
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                self?.observeApp(app)
            }
        }
        
        // Start observing the current frontmost app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            observeApp(frontApp)
        }
    }
    
    private func handleTitleChange() {
        // Debounce: only fire if 0.5 seconds have passed since last fire
        let now = Date()
        if now.timeIntervalSince(lastTitleChangeTime) < 0.5 { return }
        lastTitleChangeTime = now
        
        print("📄 Window title changed")
        onTitleChanged?()
    }
    
    private func observeApp(_ app: NSRunningApplication) {
        // Clean up previous observer
        if let observer = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        
        currentApp = app
        let pid = app.processIdentifier
        
        // Create observer
        var newObserver: AXObserver?
        let callback: AXObserverCallback = { observer, element, notification, refcon in
            let titleObserver = Unmanaged<WindowTitleObserver>.fromOpaque(refcon!).takeUnretainedValue()
            DispatchQueue.main.async {
                titleObserver.handleTitleChange()
            }
        }
        
        guard AXObserverCreate(pid, callback, &newObserver) == .success,
              let newObserver = newObserver else {
            return
        }
        
        observer = newObserver
        
        // Get the app's AXUIElement and add title change notification
        let appElement = AXUIElementCreateApplication(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        
        AXObserverAddNotification(newObserver, appElement, kAXTitleChangedNotification as CFString, refcon)
        AXObserverAddNotification(newObserver, appElement, kAXFocusedWindowChangedNotification as CFString, refcon)
        
        // Add to run loop
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(newObserver), .defaultMode)
    }
}

// ----------------------------------------------------------------------------
//  PRIVATE BINDINGS (DisplayServices for brightness control)
// ----------------------------------------------------------------------------

@_silgen_name("DisplayServicesGetBrightness")
func DisplayServicesGetBrightness(_ displayID: CGDirectDisplayID, _ brightness: UnsafeMutablePointer<Float>) -> Int32

@_silgen_name("DisplayServicesSetBrightness")
func DisplayServicesSetBrightness(_ displayID: CGDirectDisplayID, _ brightness: Float) -> Int32

// ----------------------------------------------------------------------------
//  GLOBAL STATE & CONFIG
// ----------------------------------------------------------------------------

enum Config {
    static let captureSize = 50
    static let tickInterval: TimeInterval = 0.02
    static let animationDuration: TimeInterval = 0.5
    static let debounceInterval: TimeInterval = 0.5
    static let targetTolerance: Float = 0.03
    static let animationThreshold: Float = 0.003
    static let trainingDelay: TimeInterval = 5.0
}

var lightTarget: Float = 0.45
var darkTarget: Float = 1.0

// ----------------------------------------------------------------------------
//  SCREENCAPTUREKIT HELPER
// ----------------------------------------------------------------------------

actor ScreenCaptureHelper {
    static let shared = ScreenCaptureHelper()
    
    private var content: SCShareableContent?
    private var display: SCDisplay?
    
    func initialize() async throws {
        content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        display = content?.displays.first
    }
    
    func captureScreenCenter() async throws -> Float? {
        guard let display = display else {
            try await initialize()
            guard let display = self.display else { return nil }
            return try await captureWithDisplay(display)
        }
        return try await captureWithDisplay(display)
    }
    
    private func captureWithDisplay(_ display: SCDisplay) async throws -> Float? {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        let config = SCStreamConfiguration()
        config.width = Config.captureSize
        config.height = Config.captureSize
        config.showsCursor = false
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        // Use NV12 pixel format (Y+UV bi-planar) to get Luma (Y) directly
        config.pixelFormat = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        
        // Capture a sample buffer directly (no CGImage conversion needed)
        let sampleBuffer = try await SCScreenshotManager.captureSampleBuffer(
            contentFilter: filter,
            configuration: config
        )
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return nil }
        
        // Lock the buffer to read bytes
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }
        
        // Plane 0 is Y (Luma), Plane 1 is UV (Chroma)
        let yPlaneIndex = 0
        guard let baseAddress = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, yPlaneIndex) else { return nil }
        
        // Read Luma bytes and calculate average
        // Since we are 50x50, stride might be larger than width, so we read row by row
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, yPlaneIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, yPlaneIndex)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, yPlaneIndex)
        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        
        var totalLuma: UInt64 = 0
        
        for y in 0..<height {
            let rowStart = y * bytesPerRow
            for x in 0..<width {
                // Luma is just the byte value (0-255)
                totalLuma += UInt64(buffer[rowStart + x])
            }
        }
        
        let pixelCount = Float(width * height)
        if pixelCount == 0 { return 0 }
        
        return (Float(totalLuma) / pixelCount) / 255.0
    }
    
    func checkPermission() async -> Bool {
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            return true
        } catch {
            return false
        }
    }
}

// ----------------------------------------------------------------------------
//  PERMISSION CHECK
// ----------------------------------------------------------------------------

func printPermissionError() {
    print("")
    print("❌ Screen Recording permission required!")
    print("")
    print("   This app needs to see your screen content to adjust brightness.")
    print("")
    print("   To grant permission:")
    print("   1. Open System Settings → Privacy & Security → Screen Recording")
    print("   2. Add 'auto-brightness' to the list")
    print("   3. Restart this app")
    print("")
    print("   Or run this command to open settings directly:")
    print("   open \"x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture\"")
    print("")
}

// ----------------------------------------------------------------------------
//  PREMIUM ENGINE
// ----------------------------------------------------------------------------

class PremiumEngine {
    static let shared = PremiumEngine()
    
    private var currentTarget: Float = 0.5
    private var lastSettledHW: Float = -1.0
    private var animationTimer: Timer?
    private var trainingTimer: Timer?
    private var currentLuma: Float = 0.5
    private var isAnimating: Bool = false  // Added to prevent jitter
    
    init() { 
        currentTarget = getHWBrightness() 
        lastSettledHW = currentTarget
    }
    
    func getHWBrightness() -> Float {
        var b: Float = 0.5
        _ = DisplayServicesGetBrightness(CGMainDisplayID(), &b)
        return b
    }
    
    func setHWBrightness(_ val: Float) {
        _ = DisplayServicesSetBrightness(CGMainDisplayID(), val)
    }

    private func commitTraining() {
        guard trainingTimer != nil else { return }
        trainingTimer?.invalidate()
        trainingTimer = nil
        
        let finalHW = getHWBrightness()
        if currentLuma > 0.5 {
            lightTarget = finalHW
        } else {
            darkTarget = finalHW
        }
        
        print("🧠 LEARNED (Commit): New target for \(currentLuma > 0.5 ? "Light" : "Dark") is \(String(format: "%.2f", finalHW))")
        lastSettledHW = finalHW
        currentTarget = finalHW
    }

    private var lastCaptureTime: Date = .distantPast

    func triggerCapture(reason: String) {
        // Global Throttle: Prevent rapid-fire captures (max 2 per second)
        // This prevents CPU spikes when multiple events fire simultaneously
        // Global Throttle
        let now = Date()
        if now.timeIntervalSince(lastCaptureTime) < Config.debounceInterval {
            return
        }
        lastCaptureTime = now

        // Rule: If an event happens while training, commit the current training immediately.
        if trainingTimer != nil {
            commitTraining()
        }

        // Always capture screen content on triggers
        Task {
            guard let luma = try? await ScreenCaptureHelper.shared.captureScreenCenter() else { return }
            
            await MainActor.run {
                self.currentLuma = luma
                
                // Determine target based on content
                let nextGoal = luma > 0.5 ? lightTarget : darkTarget
                
                // Skip if already at target (with larger tolerance)
                if abs(nextGoal - self.currentTarget) < Config.targetTolerance { return }
                
                print("⚡ [\(reason)] Luma: \(String(format: "%.2f", luma)) → Target: \(String(format: "%.2f", nextGoal))")
                self.currentTarget = nextGoal
                self.startMotion()
            }
        }
    }

    private func startTraining() {
        animationTimer?.invalidate()
        animationTimer = nil
        
        trainingTimer?.invalidate()
        print("🛠 TRAINING: Capturing adjustments...")
        
        trainingTimer = Timer.scheduledTimer(withTimeInterval: Config.trainingDelay, repeats: false) { [weak self] _ in
            self?.commitTraining()
        }
    }

    private func startMotion() {
        if animationTimer != nil { return }
        isAnimating = true
        var ref = getHWBrightness()
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: Config.tickInterval, repeats: true) { [weak self] t in
            guard let self = self else { return }
            let diff = self.currentTarget - ref
            
            // Check if done
            if abs(diff) < Config.animationThreshold {
                self.setHWBrightness(self.currentTarget)
                self.lastSettledHW = self.currentTarget
                self.isAnimating = false
                t.invalidate()
                self.animationTimer = nil
                return
            }
            
            // Move toward target
            ref += (diff * 0.1)
            self.setHWBrightness(ref)
        }
    }
    
    func handleBrightnessKeyPressed() {
        // User pressed brightness key - stop animation and learn
        if isAnimating {
            print("🎹 Brightness key detected - stopping animation")
            animationTimer?.invalidate()
            animationTimer = nil
            isAnimating = false
        }
        lastSettledHW = getHWBrightness()
        startTraining()
    }
    
    // Cleanup for timers (Fix Memory Leak suggestion)
    deinit {
        animationTimer?.invalidate()
        trainingTimer?.invalidate()
    }

    func start() {
        let ws = NSWorkspace.shared
        let nc = ws.notificationCenter

        nc.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { _ in 
            self.triggerCapture(reason: "APP SWITCH") 
        }
        nc.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.triggerCapture(reason: "SPACE SWITCH") }
        }

        // Removed defunct accessibility observer

        // Start HID listener for brightness keys + Cmd+T/W
        BrightnessKeyListener.shared.onBrightnessKeyPressed = { [weak self] in
            self?.handleBrightnessKeyPressed()
        }
        BrightnessKeyListener.shared.onTabChanged = { [weak self] in
            // Delay to let the new tab content load
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.triggerCapture(reason: "TAB CHANGE")
            }
        }
        BrightnessKeyListener.shared.start()

        // Start window title observer for page navigation
        WindowTitleObserver.shared.onTitleChanged = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.triggerCapture(reason: "TITLE CHANGE")
            }
        }
        WindowTitleObserver.shared.start()

        self.triggerCapture(reason: "BOOTUP")
    }
}

// ----------------------------------------------------------------------------
//  STARTUP
// ----------------------------------------------------------------------------

Task {
    let hasPermission = await ScreenCaptureHelper.shared.checkPermission()
    
    await MainActor.run {
        if !hasPermission {
            printPermissionError()
            exit(1)
        }
        
        print("🔥 App started (Interactive Training Mode).")
        PremiumEngine.shared.start()
    }
}

RunLoop.main.run()
