import SwiftUI
import Foundation
import CoreBluetooth
import Combine

class BluetoothCoreModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var peripherals: [CBPeripheral] = []
    @Published var isLoading: Bool = false
    @Published var discoveredData: String = "No data yet"
    
    // MARK: - Bluetooth Properties
    private var centralManager: CBCentralManager!
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func connect(to peripheral: CBPeripheral) {
        isLoading = true
        centralManager.stopScan()
        centralManager.connect(peripheral, options: nil)
    }
}

// MARK: - Central Manager Delegate
extension BluetoothCoreModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi: NSNumber) {
        if !peripherals.contains(peripheral) {
            DispatchQueue.main.async {
                self.peripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.discoveredData = "Connected! Discovering services..."
        }
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

// MARK: - Peripheral Delegate
extension BluetoothCoreModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        for characteristic in characteristics {
            if characteristic.properties.contains(.read) {
                peripheral.readValue(for: characteristic)
            }
        
            if characteristic.properties.contains(.notify) {
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let data = characteristic.value {
            let hexString = data.map { String(format: "%02hhX", $0) }.joined(separator: " ")
            
          
            let readableString = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .controlCharacters) ?? "Binary Data"
            
            DispatchQueue.main.async {
                self.discoveredData = """
                UUID: \(characteristic.uuid.uuidString)
                
                TEXT: \(readableString)
                
                HEX: \(hexString)
                """
            }
        }
    }
}
