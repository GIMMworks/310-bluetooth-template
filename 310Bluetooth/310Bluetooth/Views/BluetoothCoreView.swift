import SwiftUI
import CoreBluetooth

struct BluetoothCoreView: View {
    @StateObject private var viewModel = BluetoothCoreModel()
    
    var body: some View {
        NavigationStack {
            List(viewModel.peripherals, id: \.identifier) { peripheral in
                NavigationLink(destination: DeviceDetailView(viewModel: viewModel, peripheral: peripheral)) {
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "Unknown Device")
                            .font(.headline)
                        Text(peripheral.identifier.uuidString.prefix(12))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Devices")
        }
    }
}

struct DeviceDetailView: View {
    @ObservedObject var viewModel: BluetoothCoreModel
    var peripheral: CBPeripheral
    
    var body: some View {
        Form {
            Section("Device Info") {
                LabeledContent("Name", value: peripheral.name ?? "Unknown")
                LabeledContent("Status", value: statusString)
            }
            
            Section("Live Data Feed") {
                Text("\(viewModel.discoveredData)")
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.blue)
            }
        }
        .navigationTitle("Details")
        .onAppear {
            viewModel.connect(to: peripheral)
        }
    }
    
    var statusString: String {
        switch peripheral.state {
        case .connected: return "Connected"
        case .connecting: return "Connecting..."
        default: return "Disconnected"
        }
    }
}
