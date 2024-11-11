import SwiftUI
import AVFoundation

struct PopoverView: View {
    @EnvironmentObject private var cameraManager: CameraManager
    let quitApp: () -> Void

    var body: some View {
        VStack {
            HStack(spacing: 8) {
                Text("Check every")
                    .foregroundColor(.secondary)
                
                TextField("Seconds", value: $cameraManager.checkInterval, format: .number.precision(.fractionLength(1)))
                    .frame(width: 60)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .multilineTextAlignment(.center)
                
                Text("seconds")
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Close") {
                    quitApp()
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .controlSize(.regular)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.windowBackgroundColor))
                    .shadow(radius: 2)
            )
            
            GeometryReader { geometry in
                CameraPreview(session: cameraManager.session)
                    .aspectRatio(16/9, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        CameraDetectionOverlay(
                            mouthRect: cameraManager.mouthRect,
                            handsFingersPositions: cameraManager.handsFingersPositions
                        )
                    )
            }
        }
        .padding()
    }
}
