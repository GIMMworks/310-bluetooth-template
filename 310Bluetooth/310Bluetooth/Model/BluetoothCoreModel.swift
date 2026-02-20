import SwiftUI
import Foundation
import CoreBluetooth
import Combine

class BluetoothCoreModel: NSObject, ObservableObject {
    
    // MARK: - Published Properties (updates UI automatically)
    @Published var peripherals: [CBPeripheral] = []
    @Published var isLoading: Bool = false
    
    // MARK: - Bluetooth
    private var centralManager: CBCentralManager!
    private let batteryLevelCharacteristicUUID = CBUUID(string: "AE41")
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func connect(to peripheral: CBPeripheral) {
        isLoading = true
        centralManager.stopScan()
        centralManager.connect(peripheral)
    }
}

extension BluetoothCoreModel: CBCentralManagerDelegate {
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            centralManager.scanForPeripherals(withServices: nil, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String : Any],
                        rssi: NSNumber) {
        
        if !peripherals.contains(peripheral) {
            DispatchQueue.main.async {
                self.peripherals.append(peripheral)
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager,
                        didConnect peripheral: CBPeripheral) {
        
        DispatchQueue.main.async {
            self.isLoading = false
        }
        
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension BluetoothCoreModel: CBPeripheralDelegate {
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverServices error: Error?) {
        
        peripheral.services?.forEach {
            peripheral.discoverCharacteristics(nil, for: $0)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        
        service.characteristics?.forEach { characteristic in
            if characteristic.uuid == batteryLevelCharacteristicUUID {
                peripheral.setNotifyValue(true, for: characteristic)
                peripheral.readValue(for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        
        if characteristic.uuid == batteryLevelCharacteristicUUID,
           let data = characteristic.value {
            
            let batteryLevel = data[0]
            print("Battery Level: \(batteryLevel)%")
        }
    }
}
