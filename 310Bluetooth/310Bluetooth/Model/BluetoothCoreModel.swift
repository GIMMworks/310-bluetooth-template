import SwiftUI
import CoreBluetooth       // The framework for Bluetooth Low Energy (BLE)
import NearbyInteraction  // Used here to handle the UWB "Discovery Tokens"
import Combine             // Helps the UI stay in sync with Bluetooth changes

/// This class acts as both a "Central" (Scanner) and a "Peripheral" (Broadcaster).
class BluetoothCoreModel: NSObject, ObservableObject {
    // --- Data for the UI ---
    @Published var peripherals: [CBPeripheral] = []    // List of found devices
    @Published var connectedPeripheral: CBPeripheral? // The device we are currently talking to
    @Published var discoveredData: String = ""         // Text/Status to show in the List
    
    // --- Internal Logic ---
    var niManager = NearbyInteractionManager()         // Connects Bluetooth to the UWB Radar
    private var centralManager: CBCentralManager!      // The "Eye" (Scans for devices)
    private var peripheralManager: CBPeripheralManager! // The "Voice" (Advertises this phone)
    
    // --- Unique Mailbox IDs (UUIDs) ---
    // These IDs ensure our app only talks to other phones running the SAME app.
    let serviceUUID = CBUUID(string: "E20A") // The "Service" (The building)
    let charUUID = CBUUID(string: "E20B")    // The "Characteristic" (The mailbox inside)
    
    // Standard ID for universal device info (Name, Model, etc.)
    let deviceInfoServiceUUID = CBUUID(string: "180A")

    override init() {
        super.init()
        // Initialize the managers and set this class as the "Boss" (Delegate)
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    /// Wipes the slate clean and restarts both scanning and broadcasting.
    func resetAndRestart() {
        DispatchQueue.main.async {
            self.peripherals.removeAll()
            self.connectedPeripheral = nil
            self.discoveredData = ""
            self.centralManager.stopScan()
            // Scan for services = nil to see every device nearby
            self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            self.peripheralManager.stopAdvertising()
            self.startAdvertising()
        }
    }

    /// Attempts to form a Bluetooth bond with a selected device.
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        self.connectedPeripheral = peripheral
        self.discoveredData = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }

    /// Starts "shouting" this phone's presence so other phones can see it.
    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Spatial-Peer-\(UIDevice.current.name)"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    /// The Handshake: Sends our phone's UWB "Address" (Token) to the other phone.
    func sendHandshake() {
        guard let peripheral = connectedPeripheral,
              let token = niManager.localDiscoveryToken,
              // Convert the complex token into a simple "Data" package for Bluetooth
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            return
        }
        
        // Find the "Mailbox" on the other phone and drop the token in.
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }),
           let char = service.characteristics?.first(where: { $0.uuid == charUUID }) {
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }
}

// MARK: - Central Manager (The "Eye")
extension BluetoothCoreModel: CBCentralManagerDelegate {
    /// Triggers when you turn Bluetooth on/off in iOS Settings.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    /// Triggers every time the phone spots a new Bluetooth device nearby.
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        if !peripherals.contains(peripheral) {
            DispatchQueue.main.async { self.peripherals.append(peripheral) }
        }
    }

    /// Triggers once a connection is successful.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.discoveredData = "Connected. Searching for data..." }
        peripheral.delegate = self
        // Ask the device: "What services/mailboxes do you have?"
        peripheral.discoverServices([serviceUUID, deviceInfoServiceUUID])
    }
}

// MARK: - Peripheral Manager (The "Voice")
extension BluetoothCoreModel: CBPeripheralManagerDelegate {
    /// Sets up our phone's "Mailbox" so other phones can write their tokens to us.
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let char = CBMutableCharacteristic(type: charUUID, properties: [.write, .read, .notify], value: nil, permissions: [.writeable, .readable])
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [char]
            peripheralManager.add(service)
            startAdvertising()
        }
    }

    /// Triggers when the OTHER phone writes its token into OUR mailbox.
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                // If it's a UWB Token, start the radar and send our token back
                if let _ = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
                    niManager.startSession(with: data)
                    sendHandshake()
                } else if let message = String(data: data, encoding: .utf8) {
                    DispatchQueue.main.async { self.discoveredData = message }
                }
                peripheralManager.respond(to: request, withResult: .success)
            }
        }
    }
}

// MARK: - Peripheral Delegate (The Intelligent Reader)
extension BluetoothCoreModel: CBPeripheralDelegate {
    /// Step 1: Find the service
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    /// Step 2: Find the characteristic
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
            if char.properties.contains(.read) {
                peripheral.readValue(for: char)
            }
        }
    }

    /// Handle the Data
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        if let _ = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            niManager.startSession(with: data)
            DispatchQueue.main.async { self.discoveredData = "UWB Token Received" }
            return
        }
        
        if let message = String(data: data, encoding: .utf8) {
            let cleanMsg = message.trimmingCharacters(in: .controlCharacters)
            if !cleanMsg.isEmpty {
                DispatchQueue.main.async { self.discoveredData = cleanMsg }
            }
        }
    }
}
