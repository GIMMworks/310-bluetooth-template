import SwiftUI
import CoreBluetooth
import NearbyInteraction
import Combine

class BluetoothCoreModel: NSObject, ObservableObject {
    @Published var peripherals: [CBPeripheral] = []
    @Published var connectedPeripheral: CBPeripheral?
    @Published var discoveredData: String = "No data yet"
    
    private var centralManager: CBCentralManager!
    private var peripheralManager: CBPeripheralManager!
    var niManager = NearbyInteractionManager()
    
    // Unique ID for our UWB Data Transfer
    let charUUID = CBUUID(string: "E20B")

    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }

    // MARK: - Actions
    func connect(to peripheral: CBPeripheral) {
        centralManager.stopScan()
        self.connectedPeripheral = peripheral
        centralManager.connect(peripheral, options: nil)
    }

    func startAdvertising() {
        if peripheralManager.state == .poweredOn {
            let advertisementData: [String: Any] = [
                CBAdvertisementDataServiceUUIDsKey: [CBUUID(string: "E20A")],
                CBAdvertisementDataLocalNameKey: "Spatial-Peer-\(UIDevice.current.name)"
            ]
            peripheralManager.startAdvertising(advertisementData)
        }
    }

    // THIS IS THE KEY: Sending our Token to the other phone
    func sendHandshake() {
        guard let peripheral = connectedPeripheral,
              let token = niManager.localDiscoveryToken,
              let data = try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true) else {
            return
        }
        
        // This physically writes the data to the other phone's Bluetooth antenna
        // We find the characteristic we defined and send our UWB token through it
        if let service = peripheral.services?.first,
           let char = service.characteristics?.first(where: { $0.uuid == charUUID }) {
            peripheral.writeValue(data, for: char, type: .withResponse)
            print("Token sent to peer!")
        }
        
        // Also start our own session locally
        niManager.startSession(with: data)
    }
}

// MARK: - Delegate Extensions
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
        DispatchQueue.main.async { self.connectedPeripheral = peripheral }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension BluetoothCoreModel: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        if peripheral.state == .poweredOn {
            // Create a "Mailbox" (Service) so the other phone can drop off its token
            let char = CBMutableCharacteristic(type: charUUID, properties: [.write, .read], value: nil, permissions: [.writeable, .readable])
            let service = CBMutableService(type: CBUUID(string: "E20A"), primary: true)
            service.characteristics = [char]
            peripheralManager.add(service)
            startAdvertising()
        }
    }

    // This triggers when the OTHER phone sends us THEIR token
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        for request in requests {
            if let data = request.value {
                // Give the received token to the NI Manager to start the arrow!
                niManager.startSession(with: data)
                peripheralManager.respond(to: request, withResult: .success)
            }
        }
    }
}

extension BluetoothCoreModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        peripheral.services?.forEach { peripheral.discoverCharacteristics(nil, for: $0) }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            // If the data we received is a UWB Token, start the session
            niManager.startSession(with: data)
            
            let readableString = String(data: data, encoding: .utf8) ?? "UWB Token Received"
            DispatchQueue.main.async { self.discoveredData = readableString }
        }
    }
}
