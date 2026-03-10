import Foundation
import NearbyInteraction
import ARKit
import Combine

class NearbyInteractionManager: NSObject, ObservableObject, NISessionDelegate, ARSessionDelegate {
    // UI Properties
    @Published var distance: Float? = nil
    @Published var direction: simd_float3? = nil
    @Published var sessionStatus: String = "Initializing..."
    
    // The Engine
    var niSession: NISession?
    var arSession: ARSession? // Added ARKit support to stabilize the UWB chip
    var localDiscoveryToken: NIDiscoveryToken? {
        return niSession?.discoveryToken
    }
    override init() {
        super.init()
        setupSession()
    }
    
    func setupSession() {
        if NISession.deviceCapabilities.supportsPreciseDistanceMeasurement {
            niSession = NISession()
            niSession?.delegate = self
            
            // Start ARKit in the background to help the UWB hardware
            arSession = ARSession()
            arSession?.delegate = self
            let config = ARWorldTrackingConfiguration()
            arSession?.run(config)
            
            DispatchQueue.main.async {
                self.sessionStatus = "Hardware Ready"
            }
        } else {
            DispatchQueue.main.async {
                self.sessionStatus = "UWB Not Supported"
            }
        }
    }
    
    func startSession(with peerTokenData: Data) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: peerTokenData) else {
                return
            }
            
            // Create configuration using the token we received via Bluetooth
            let config = NINearbyPeerConfiguration(peerToken: token)
            
            // This is the "Magic Link" that uses ARKit to make the UWB arrow more accurate
            config.isCameraAssistanceEnabled = true
            
            niSession?.run(config)
            
            DispatchQueue.main.async {
                self.sessionStatus = "Session Running"
            }
        } catch {
            print("Token decoding failed: \(error)")
        }
    }
    
    // MARK: - NISessionDelegate (The heartbeat)
    
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        
        DispatchQueue.main.async {
            self.distance = object.distance
            self.direction = object.direction
            self.sessionStatus = "Tracking..."
        }
    }
    
    func session(_ session: NISession, didInvalidateWith error: Error) {
        DispatchQueue.main.async {
            self.sessionStatus = "Error: \(error.localizedDescription)"
        }
        setupSession() // Attempt restart
    }
    
    // Handle phone being put in pocket or app minimized
    func sessionWasSuspended(_ session: NISession) {
        DispatchQueue.main.async { self.sessionStatus = "Paused" }
    }
}
