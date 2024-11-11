import SwiftUI

struct CameraDetectionOverlay: View {
    let mouthRect: CGRect?
    let handsFingersPositions: [[CGPoint]]
    
    private func transformPoint(_ point: CGPoint, in geometry: GeometryProxy) -> CGPoint {
        let viewAspectRatio = geometry.size.width / geometry.size.height
        let cameraAspectRatio: CGFloat = 16/9 // Typical camera aspect ratio
        
        var x = point.x
        var y = 1 - point.y // Flip Y coordinate
        
        // Adjust for aspect ratio differences
        if viewAspectRatio > cameraAspectRatio {
            // View is wider than camera
            let scale = viewAspectRatio / cameraAspectRatio
            x = (x - 0.5) * scale + 0.5
        } else {
            // View is taller than camera
            let scale = cameraAspectRatio / viewAspectRatio
            y = (y - 0.5) * scale + 0.5
        }
        
        return CGPoint(
            x: x * geometry.size.width,
            y: y * geometry.size.height
        )
    }

    private func transformRect(_ rect: CGRect, in geometry: GeometryProxy) -> CGRect {
        let viewAspectRatio = geometry.size.width / geometry.size.height
        let cameraAspectRatio: CGFloat = 16/9
        
        var x = rect.minX
        var y = 1 - rect.maxY
        var width = rect.width
        var height = rect.height
        
        // Adjust for aspect ratio differences
        if viewAspectRatio > cameraAspectRatio {
            // View is wider than camera
            let scale = viewAspectRatio / cameraAspectRatio
            x = (x - 0.5) * scale + 0.5
            width *= scale
        } else {
            // View is taller than camera
            let scale = cameraAspectRatio / viewAspectRatio
            y = (y - 0.5) * scale + 0.5
            height *= scale
        }
        
        return CGRect(
            x: x * geometry.size.width,
            y: y * geometry.size.height,
            width: width * geometry.size.width,
            height: height * geometry.size.height
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let mouthRect = mouthRect {
                    let viewRect = transformRect(mouthRect, in: geometry)
                    Rectangle()
                        .stroke(Color.pink, lineWidth: 2)
                        .frame(width: viewRect.width, height: viewRect.height)
                        .cornerRadius(4)
                        .position(x: viewRect.minX + viewRect.width/2,
                                y: viewRect.minY + viewRect.height/2)
                        .overlay(
                            Text("Mouth")
                                .foregroundColor(.pink)
                                .font(.caption)
                                .padding(2)
                                .background(Color.white.opacity(0.7))
                                .cornerRadius(4)
                                .position(x: viewRect.minX + viewRect.width/2,
                                          y: viewRect.minY + viewRect.height/2 - 20)
                            
                        )
                }
                
                ForEach(Array(handsFingersPositions.enumerated()), id: \.offset) { _, hand in
                    ForEach(Array(hand.enumerated()), id: \.offset) { _, handPoint in
                        let viewPoint = transformPoint(handPoint, in: geometry)
                        Circle()
                            .fill(Color.black)
                            .frame(width: 8, height: 8)
                            .position(viewPoint)
                    }
                }
            }
        }
    }
}
