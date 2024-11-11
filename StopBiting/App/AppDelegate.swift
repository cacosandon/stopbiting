import Cocoa
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    private var warningWindow: WarningOverlay?
    private var cancellable: AnyCancellable?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusBarItem()
        setupWarningOverlay()
    }
    
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "🖐️"
        
        let popover = NSPopover()
        popover.contentSize = NSSize(width: 480, height: 320)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView(quitApp: quitApp)
                .environmentObject(CameraManager.shared)
        )

        self.popover = popover
        
        statusItem?.button?.action = #selector(togglePopover)
        statusItem?.button?.target = self
    }
    
    @objc private func togglePopover() {
        guard let statusBarButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusBarButton.bounds, of: statusBarButton, preferredEdge: .minY)
            }
        }
    }
    
    private func setupWarningOverlay() {
        warningWindow = WarningOverlay()
        cancellable = CameraManager.shared.$handInMouth
            .receive(on: DispatchQueue.main)
            .sink { [weak self] handInMouth in
                if handInMouth {
                    self?.showWarningOverlay()
                } else {
                    self?.hideWarningOverlay()
                }
            }
    }
    
    private func showWarningOverlay() {
        guard let screen = NSScreen.main else { return }
        warningWindow?.setFrame(screen.frame, display: true)
        warningWindow?.orderFront(nil)
    }
    
    private func hideWarningOverlay() {
        warningWindow?.orderOut(nil)
    }

    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        CameraManager.shared.cleanup()
        cancellable?.cancel()
    }
} 
