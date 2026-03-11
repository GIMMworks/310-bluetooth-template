import SwiftUI
import NearbyInteraction

struct SpatialDistanceView: View {
    // This connects to the hardware manager we just finished
    @ObservedObject var niManager: NearbyInteractionManager
    
    var body: some View {
        VStack(spacing: 40) {
            // 1. Connection Status Header
            VStack(spacing: 8) {
                Text("PRECISION FINDING")
                    .font(.caption)
                    .tracking(2)
                    .foregroundColor(.secondary)
                
                HStack {
                    Circle()
                        .fill(niManager.sessionStatus == "Tracking..." ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(niManager.sessionStatus)
                        .font(.footnote)
                        .bold()
                }
            }
            .padding(.top)

            Spacer()

            // 2. The Directional Arrow
            // We use the 'x' component of the direction vector to determine left/right
            if let direction = niManager.direction {
                Image(systemName: "arrow.up")
                    .font(.system(size: 120, weight: .black))
                    .foregroundColor(.blue)
                    .rotationEffect(.radians(Double(direction.x))) // Rotates based on peer location
                    .shadow(color: .blue.opacity(0.3), radius: 10)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Pulse effect while searching
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 80))
                    .foregroundColor(.gray.opacity(0.5))
            }

            // 3. The Distance Display
            VStack(spacing: 5) {
                if let dist = niManager.distance {
                    // Convert meters to feet if you prefer, or keep as meters
                    Text(String(format: "%.1f", dist))
                        .font(.system(size: 90, weight: .bold, design: .rounded))
                        .foregroundColor(dist < 1.0 ? .green : .primary)
                    
                    Text("METERS")
                        .font(.headline)
                        .foregroundColor(.secondary)
                } else {
                    Text("--")
                        .font(.system(size: 90, weight: .bold, design: .rounded))
                        .foregroundColor(.gray)
                    Text("SEARCHING...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
            
            // 4. Instructional Footer
            Text("Point your phone toward the other device\nand move slightly to calibrate.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.bottom)
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}
