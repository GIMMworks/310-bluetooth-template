import SwiftUI

struct SpatialDistanceView: View {
    @ObservedObject var niManager: NearbyInteractionManager
    
    var body: some View {
        VStack(spacing: 50) {
            VStack {
                Text(niManager.distance != nil ? String(format: "%.2f", niManager.distance!) : "--")
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                Text("METERS AWAY").font(.caption).tracking(3)
            }
            
            ZStack {
                Circle().stroke(Color.gray.opacity(0.1), lineWidth: 15).frame(width: 250)
                
                if let direction = niManager.direction {
                    Image(systemName: "arrow.up.circle.fill")
                        .resizable()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.green)
                        // Converts X and Z vectors to a rotation angle
                        .rotationEffect(Angle(radians: Double(atan2(direction.x, direction.z))))
                } else {
                    Image(systemName: "dot.radiowaves.left.and.right").font(.largeTitle).foregroundColor(.gray)
                }
            }
            Text(niManager.direction != nil ? "Target Acquired" : "Searching...").font(.subheadline)
        }
    }
}
