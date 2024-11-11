import SwiftUI

@main
struct StopBitingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    var body: some Scene {
        Settings { }
    }
}