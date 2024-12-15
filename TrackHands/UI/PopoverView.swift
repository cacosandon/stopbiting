import SwiftUI
import AVFoundation

struct PopoverView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    @State private var showingTooltip = false
    @FocusState private var isFocused: Bool
    
    let quitApp: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                HStack() {
                    Text("Check every")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .rounded))

                    TextField("", value: $cameraManager.checkInterval, format: .number.precision(.fractionLength(1)))
                        .frame(width: 24)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .padding(6)
                        .background(Color(.windowBackgroundColor).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    
                    Text("sec")
                        .foregroundColor(.secondary)
                        .font(.system(.body, design: .rounded))
                }
                
                Spacer()
                
                Button {
                    showingTooltip.toggle()
                } label: {
                    Image(systemName: "questionmark.circle")
                        .foregroundColor(.primary)
                        .font(.system(size: 16))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(PlainButtonStyle())
                .popover(isPresented: $showingTooltip, arrowEdge: .bottom) {
                    Text("If your fingers are not being recognized, close the app and open it again. If that doesn't work, contact us at help@trackhands.com")
                        .font(.system(.caption, design: .rounded))
                        .padding(12)
                        .frame(width: 250)
                        .fixedSize(horizontal: false, vertical: true)
                }

                
                Button(action: quitApp) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 16))
                        .fontWeight(.medium)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
                .help("Quit Application")
            }
            .padding(12)
            .background(
                Color(.windowBackgroundColor)
                    .opacity(0.8)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            )
            
            GeometryReader { geometry in
                ZStack {
                    if let previewLayer = cameraManager.previewLayer {
                        CameraPreview(previewLayer: previewLayer)
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(width: min(geometry.size.width, geometry.size.height * 16/9))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                CameraDetectionOverlay(
                                    mouthRect: cameraManager.mouthRect,
                                    handsFingersPositions: cameraManager.handsFingersPositions
                                )
                            )
                            .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 2)
                    } else {
                        // Show a placeholder or loading indicator until previewLayer is available
                        ProgressView("Loading camera...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .padding(16)
    }
}
