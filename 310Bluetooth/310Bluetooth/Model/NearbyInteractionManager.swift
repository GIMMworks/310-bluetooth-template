import Foundation
import NearbyInteraction // The framework for Ultra-Wideband (U1/U2 chip)
import ARKit             // Used for "Camera Assistance" to improve accuracy
import Combine           // Allows the UI to listen for distance/direction changes

/// This class manages the spatial relationship between two devices.
class NearbyInteractionManager: NSObject, ObservableObject, NISessionDelegate, ARSessionDelegate {
    
    // --- Data for the UI ---
    @Published var distance: Float? = nil        // Distance in meters (accurate to 10cm)
    @Published var direction: simd_float3? = nil // X, Y, Z vector pointing to the peer
    @Published var sessionStatus: String = "Initializing..."
    
    // --- The Engines ---
    var niSession: NISession?   // The "Radar" session
    var arSession: ARSession?   // The "Camera" session for spatial orientation
    
    /// The phone's unique "Spatial Address."
    /// Sends to the other phone over Bluetooth so they can find you.
    var localDiscoveryToken: NIDiscoveryToken? {
        return niSession?.discoveryToken
    }
    
    override init() {
        super.init()
        setupSession()
    }
    
    /// Initializes the hardware and checks if the device supports UWB.
    func setupSession() {
        // Check if this device has a U1 or U2 chip
        if NISession.deviceCapabilities.supportsPreciseDistanceMeasurement {
            niSession = NISession()
            niSession?.delegate = self
            
            // Start ARKit. This allows the phone to know its own orientation
            arSession = ARSession()
            arSession?.delegate = self
            let config = ARWorldTrackingConfiguration()
            arSession?.run(config)
            
            DispatchQueue.main.async { self.sessionStatus = "Hardware Ready" }
        } else {
            DispatchQueue.main.async { self.sessionStatus = "UWB Not Supported" }
        }
    }
    
    /// Starts the spatial tracking once we receive the other phone's token.
    /// - Parameter peerTokenData: The raw Bluetooth data received from the other device.
    func startSession(with peerTokenData: Data) {
        do {
            // Convert the raw Bluetooth bytes back into a "Spatial Token"
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: peerTokenData) else { return }
            
            // Configure the session to track this specific peer
            let config = NINearbyPeerConfiguration(peerToken: token)
            
            // This is the "Magic" setting: it uses ARKit + UWB together
            // to make the directional arrow much more precise.
            config.isCameraAssistanceEnabled = true
            
            // Run the radar!
            niSession?.run(config)
            
            DispatchQueue.main.async { self.sessionStatus = "Session Running" }
        } catch {
            print("Token decoding failed: \(error)")
        }
    }
    
    // MARK: - NISessionDelegate
    
    /// This triggers every time the phones move (roughly 10-30 times per second).
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        // Update the @Published variables so the UI updates instantly
        DispatchQueue.main.async {
            self.distance = object.distance   // How far away?
            self.direction = object.direction // Which way?
            self.sessionStatus = "Tracking..."
        }
    }
}
