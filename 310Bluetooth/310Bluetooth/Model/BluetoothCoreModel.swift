import SwiftUI
import CoreBluetooth
import NearbyInteraction
import Combine

class BluetoothCoreModel: NSObject, ObservableObject {
    @Published var peripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var discoveredData: String = ""
    
    var niManager = NearbyInteractionManager()
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    
    // OUR CUSTOM UUIDs
    let serviceUUID = CBUUID(string: "E20A")
    let charUUID = CBUUID(string: "E20B")
    
    // STANDARD BLUETOOTH UUIDs (To read info from random devices)
    let deviceInfoServiceUUID = CBUUID(string: "180A")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    func resetAndRestart() {
        DispatchQueue.main.async {
            self.peripherals.removeAll()
            self.connectedPeripheral = nil
            self.discoveredData = ""
            self.centralManager.stopScan()
            // Scan for everything (nil) to ensure maximum visibility
            self.centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            self.peripheralManager.stopAdvertising()
            self.startAdvertising()
        }
    }

    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        self.connectedPeripheral = peripheral
        self.discoveredData = "Connecting..."
        centralManager.connect(peripheral, options: nil)
    }

    func startAdvertising() {
        guard peripheralManager.state == .poweredOn else { return }
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataLocalNameKey: "Spatial-Peer-\(UIDevice.current.name)"
        ]
        peripheralManager.startAdvertising(advertisementData)
    }

    func sendHandshake() {
        guard let peripheral = connectedPeripheral,
              let token = niManager.localDiscoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            return
        }
        
        if let service = peripheral.services?.first(where: { $0.uuid == serviceUUID }),
           let char = service.characteristics?.first(where: { $0.uuid == charUUID }) {
            peripheral.writeValue(data, for: char, type: .withResponse)
        }
    }
}

// MARK: - Central Manager
extension BluetoothCoreModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        }
    }

    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        if !peripherals.contains(peripheral) {
            DispatchQueue.main.async { self.peripherals.append(peripheral) }
        }
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async { self.discoveredData = "Connected. Searching for data..." }
        peripheral.delegate = self
        // Tell the phone to look for OUR service AND standard Info services
        peripheral.discoverServices([serviceUUID, deviceInfoServiceUUID])
    }
}

// MARK: - Peripheral Manager
extension BluetoothCoreModel: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            let char = CBMutableCharacteristic(type: charUUID, properties: [.write, .read, .notify], value: nil, permissions: [.writeable, .readable])
            let service = CBMutableService(type: serviceUUID, primary: true)
            service.characteristics = [char]
            peripheralManager.add(service)
            startAdvertising()
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        // Automatically search for characteristics in every service found
        peripheral.services?.forEach { service in
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let chars = service.characteristics else { return }
        for char in chars {
            // If it supports 'notify', turn it on
            if char.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: char)
            }
            // Always try to read it once
            if char.properties.contains(.read) {
                peripheral.readValue(for: char)
            }
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        
        // 1. Try decoding as UWB Token
        if let _ = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NIDiscoveryToken.self, from: data) {
            niManager.startSession(with: data)
            DispatchQueue.main.async { self.discoveredData = "UWB Token Received" }
            return
        }
        
        // 2. Try decoding as a simple String
        if let message = String(data: data, encoding: .utf8) {
            // Clean up the string (remove weird characters)
            let cleanMsg = message.trimmingCharacters(in: .controlCharacters)
            if !cleanMsg.isEmpty {
                DispatchQueue.main.async { self.discoveredData = cleanMsg }
            }
        }
    }
}
