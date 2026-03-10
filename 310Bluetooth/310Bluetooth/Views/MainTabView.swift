import SwiftUI
import CoreBluetooth

struct MainTabView: View {
    @StateObject var bluetoothModel = BluetoothCoreModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            
            // TAB 1: SCANNER
            NavigationStack {
                VStack(spacing: 0) {
                    // Status Bar: Shows if this phone is broadcasting its own signal
                    HStack {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .foregroundColor(.blue)
                        Text("Broadcasting as: \(UIDevice.current.name)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.05))
                    
                    List(bluetoothModel.peripherals, id: \.identifier) { p in
                        HStack {
                            // Click the device name to connect
                            Button {
                                bluetoothModel.connect(to: p)
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(p.name ?? "Unknown Device")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(bluetoothModel.connectedPeripheral == p ? "Connected" : "Tap to Connect")
                                        .font(.caption)
                                        .foregroundColor(bluetoothModel.connectedPeripheral == p ? .green : .gray)
                                }
                            }
                            
                            Spacer()
                            
                            // Precision Button (Appears once connected)
                            if bluetoothModel.connectedPeripheral == p {
                                Button {
                                    bluetoothModel.sendHandshake()
                                    selectedTab = 1 // Switch to the Arrow Tab
                                } label: {
                                    Label("Find", systemImage: "location.north.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.green)
                                .transition(.scale)
                                
                                // Link to see the raw Bluetooth data (Hex/Text)
                                NavigationLink(destination: BluetoothCoreView(viewModel: bluetoothModel)) {
                                    EmptyView()
                                }
                                .frame(width: 10)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .navigationTitle("Nearby Devices")
                .toolbar {
                    // REFRESH BUTTON
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            // Clear and Rescan
                            bluetoothModel.peripherals.removeAll()
                            bluetoothModel.startAdvertising() // Refresh the beacon signal too
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .tabItem {
                Label("Scanner", systemImage: "antenna.radiowaves.left.and.right")
            }
            .tag(0)
            
            // TAB 2: PRECISION (THE ARROW)
            SpatialDistanceView(niManager: bluetoothModel.niManager)
                .tabItem {
                    Label("Precision", systemImage: "location.north.line")
                }
                .tag(1)
        }
        .animation(.default, value: bluetoothModel.connectedPeripheral)
    }
}
