import Foundation
import CoreLocation
import CoreBluetooth
import Combine

enum IBeaconRole {
    case beacon
    case scanner
}

/// Manages all CoreLocation iBeacon logic for both advertising (beacon) and ranging (scanner) roles.
/// Conforms to ObservableObject so SwiftUI views reactively update on state changes.
class IBeaconModel: NSObject, ObservableObject {

    @Published var role: IBeaconRole = .scanner
    @Published var isActive: Bool = false
    @Published var statusMessage: String = "Select a role to begin."
    @Published var proximity: CLProximity = .unknown
    @Published var accuracy: CLLocationAccuracy = -1
    @Published var rssi: Int = 0
    @Published var permissionDenied: Bool = false

    /// Shared UUID that both phones must use — in production, generate your own with `uuidgen`
    static let beaconUUID = UUID(uuidString: "E2C56DB5-DFFB-48D2-B060-D0F5A71096E0")!
    static let beaconMajor: CLBeaconMajorValue = 1
    static let beaconMinor: CLBeaconMinorValue = 1
    static let beaconIdentifier = "com.GIMMWorks.-10Bluetooth"

    // Private CoreLocation + CoreBluetooth
    private let locationManager = CLLocationManager()
    private var peripheralManager: CBPeripheralManager?
    private var beaconRegion: CLBeaconRegion {
        CLBeaconRegion(
            uuid: IBeaconModel.beaconUUID,
            major: IBeaconModel.beaconMajor,
            minor: IBeaconModel.beaconMinor,
            identifier: IBeaconModel.beaconIdentifier
        )
    }
    private var beaconConstraint: CLBeaconIdentityConstraint {
        CLBeaconIdentityConstraint(uuid: IBeaconModel.beaconUUID)
    }

    override init() {
        super.init()
        locationManager.delegate = self
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Switch role and reset state
    func setRole(_ newRole: IBeaconRole) {
        stop()
        role = newRole
        statusMessage = newRole == .beacon
            ? "Ready to broadcast as iBeacon."
            : "Ready to scan for iBeacon."
    }

    /// Start broadcasting or ranging based on current role
    func start() {
        guard !isActive else { return }
        let status = locationManager.authorizationStatus
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }
        if status == .denied || status == .restricted {
            permissionDenied = true
            statusMessage = "Location permission required for iBeacon."
            return
        }
        performStart()
    }

    /// Stop all activity
    func stop() {
        isActive = false
        proximity = .unknown
        accuracy = -1
        rssi = 0

        if role == .beacon {
            peripheralManager?.stopAdvertising()
            statusMessage = "Beacon stopped."
        } else {
            locationManager.stopRangingBeacons(satisfying: beaconConstraint)
            locationManager.stopMonitoring(for: beaconRegion)
            statusMessage = "Scanner stopped."
        }
    }

    private func performStart() {
        isActive = true
        if role == .beacon {
            startBeacon()
        } else {
            startScanner()
        }
    }

    private func startBeacon() {
        guard let peripheralManager, peripheralManager.state == .poweredOn else {
            statusMessage = "Bluetooth not ready. Ensure Bluetooth is enabled."
            isActive = false
            return
        }
        let region = beaconRegion
        let advertisingData = region.peripheralData(withMeasuredPower: nil) as? [String: Any]
        peripheralManager.startAdvertising(advertisingData)
        statusMessage = "Broadcasting as iBeacon…"
    }

    private func startScanner() {
        locationManager.startMonitoring(for: beaconRegion)
        locationManager.startRangingBeacons(satisfying: beaconConstraint)
        statusMessage = "Ranging for iBeacon…"
    }

    /// Human-readable proximity label
    var proximityLabel: String {
        switch proximity {
        case .immediate: return "Immediate (~< 0.5m)"
        case .near:      return "Near (~1–3m)"
        case .far:       return "Far (> 3m)"
        default:         return "Unknown"
        }
    }

    /// 0.0–1.0 scale for visual indicator (1 = closest)
    var proximityScale: Double {
        switch proximity {
        case .immediate: return 1.0
        case .near:      return 0.65
        case .far:       return 0.3
        default:         return 0.0
        }
    }

    /// Color mapped to proximity
    var proximityColor: String {
        switch proximity {
        case .immediate: return "green"
        case .near:      return "yellow"
        case .far:       return "orange"
        default:         return "gray"
        }
    }
}

extension IBeaconModel: CBPeripheralManagerDelegate {

    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        // If the beacon role was requested before BT was ready, retry now
        if peripheral.state == .poweredOn && isActive && role == .beacon {
            startBeacon()
        }
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        DispatchQueue.main.async {
            if let error {
                self.statusMessage = "Advertising error: \(error.localizedDescription)"
                self.isActive = false
            } else {
                self.statusMessage = "iBeacon is live and broadcasting!"
            }
        }
    }
}
extension IBeaconModel: CLLocationManagerDelegate {

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.permissionDenied = false
                if self.isActive { self.performStart() }
            case .denied, .restricted:
                self.permissionDenied = true
                self.isActive = false
                self.statusMessage = "Location permission denied. Please enable in Settings."
            default:
                break
            }
        }
    }

    // Called when ranging returns beacon data
    func locationManager(_ manager: CLLocationManager,
                         didRange beacons: [CLBeacon],
                         satisfying constraint: CLBeaconIdentityConstraint) {
        DispatchQueue.main.async {
            if let closest = beacons.sorted(by: { $0.accuracy < $1.accuracy }).first {
                self.proximity = closest.proximity
                self.accuracy  = closest.accuracy
                self.rssi      = closest.rssi
                self.statusMessage = "Beacon detected!"
            } else {
                self.proximity = .unknown
                self.accuracy  = -1
                self.rssi      = 0
                self.statusMessage = "Ranging… no beacon detected yet."
            }
        }
    }

    // Beacon region monitoring callbacks
    func locationManager(_ manager: CLLocationManager,
                         didEnterRegion region: CLRegion) {
        DispatchQueue.main.async {
            self.statusMessage = "Entered beacon region."
            manager.startRangingBeacons(satisfying: self.beaconConstraint)
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didExitRegion region: CLRegion) {
        DispatchQueue.main.async {
            self.proximity = .unknown
            self.statusMessage = "Left beacon region."
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.statusMessage = "Error: \(error.localizedDescription)"
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didStartMonitoringFor region: CLRegion) {
        locationManager.requestState(for: region)
    }

    func locationManager(_ manager: CLLocationManager,
                         didDetermineState state: CLRegionState,
                         for region: CLRegion) {
        if state == .inside {
            locationManager.startRangingBeacons(satisfying: beaconConstraint)
        }
    }
}
