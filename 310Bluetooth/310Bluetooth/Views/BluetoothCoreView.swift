import SwiftUI
import CoreBluetooth

struct BluetoothCoreView: View {
    
    @StateObject private var viewModel = BluetoothCoreModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                VStack {
//                    List {
//                        Text("Test Device 1")
//                        Text("Test Device 2")
//                    }
                    List(viewModel.peripherals, id: \.identifier) { peripheral in
                        NavigationLink {
                            DeviceDetailView(viewModel: viewModel, peripheral: peripheral)
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(peripheral.name ?? "Unknown Device")
                                        .font(.headline)
                                    Text(peripheral.identifier.uuidString.prefix(8))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .navigationTitle("Scanner")
                    
                    if viewModel.isLoading {
                        ProgressView("Connecting...")
                            .padding()
                            .background(RoundedRectangle(cornerRadius: 10).fill(Color(.systemBackground)).shadow(radius: 10))
                    }
                }
            }
        }
    }
    
    struct DeviceDetailView: View {
        @ObservedObject var viewModel: BluetoothCoreModel
        var peripheral: CBPeripheral
        
        var body: some View {
            List {
                Section(header: Text("Device Info")) {
                    Text("Name: \(peripheral.name ?? "Unknown")")
                    Text("ID: \(peripheral.identifier.uuidString)")
                }
                
                Section(header: Text("Data")) {
                    if let level = viewModel.batteryLevel {
                        HStack {
                            Text("Battery Level")
                            Spacer()
                            Text("\(level)%")
                                .bold()
                                .foregroundColor(.green)
                        }
                    } else {
                        Text("Searching for characteristics...")
                            .foregroundColor(.secondary)
                            .italic()
                    }
                }
            }
            .navigationTitle("Device Details")
            .onAppear {
                viewModel.connect(to: peripheral)
            }
        }
    }
}
