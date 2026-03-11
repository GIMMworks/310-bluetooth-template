import Foundation
import NearbyInteraction
import ARKit
import Combine

class NearbyInteractionManager: NSObject, ObservableObject, NISessionDelegate, ARSessionDelegate {
    @Published var distance: Float? = nil
    @Published var direction: simd_float3? = nil
    @Published var sessionStatus: String = "Initializing..."
    
    var niSession: NISession?
    var arSession: ARSession?
    
    // The phone ID
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
            
            arSession = ARSession()
            arSession?.delegate = self
            let config = ARWorldTrackingConfiguration()
            arSession?.run(config)
            
            DispatchQueue.main.async { self.sessionStatus = "Hardware Ready" }
        }
    }
    
    func startSession(with peerTokenData: Data) {
        do {
            guard let token = try NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: peerTokenData) else { return }
            
            let config = NINearbyPeerConfiguration(peerToken: token)
            config.isCameraAssistanceEnabled = true
            
            niSession?.run(config)
            DispatchQueue.main.async { self.sessionStatus = "Session Running" }
        } catch {
            print("Token decoding failed: \(error)")
        }
    }
    
    // MARK: - NISessionDelegate
    func session(_ session: NISession, didUpdate nearbyObjects: [NINearbyObject]) {
        guard let object = nearbyObjects.first else { return }
        DispatchQueue.main.async {
            self.distance = object.distance
            self.direction = object.direction
            self.sessionStatus = "Tracking..."
        }
    }
}
