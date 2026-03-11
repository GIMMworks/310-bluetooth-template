import SwiftUI
import CoreBluetooth

struct MainTabView: View {
    @StateObject private var bluetoothModel = BluetoothCoreModel()
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                VStack(spacing: 0) {
                    BroadcastingHeaderView(model: bluetoothModel)
                    
                    List(bluetoothModel.peripherals, id: \.identifier) { peripheral in
                        DeviceRowView(
                            peripheral: peripheral,
                            model: bluetoothModel,
                            selectedTab: $selectedTab
                        )
                    }
                }
                .navigationTitle("Nearby Devices")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button {
                            bluetoothModel.resetAndRestart()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                }
            }
            .tabItem { Label("Scanner", systemImage: "list.bullet.indent") }
            .tag(0)
            
            SpatialDistanceView(niManager: bluetoothModel.niManager)
                .tabItem { Label("Precision", systemImage: "scope") }
                .tag(1)
        }
    }
}

// MARK: - Sub-Views

struct BroadcastingHeaderView: View {
    @ObservedObject var model: BluetoothCoreModel
    var body: some View {
        HStack {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundColor(.blue)
            Text("Visible as: \(UIDevice.current.name)")
                .font(.caption).bold()
            Spacer()
            Text(model.niManager.sessionStatus)
                .font(.caption2).padding(4)
                .background(Color.secondary.opacity(0.2)).cornerRadius(4)
        }
        .padding().background(Color(uiColor: .secondarySystemBackground))
    }
}

struct DeviceRowView: View {
    let peripheral: CBPeripheral
    @ObservedObject var model: BluetoothCoreModel
    @Binding var selectedTab: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(peripheral.name ?? "Unknown Device")
                    .font(.headline)
                
                if model.connectedPeripheral == peripheral {
                    // This shows "Connected", "Connecting...", or the data values
                    Text(model.discoveredData.isEmpty ? "Connected" : model.discoveredData)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .bold()
                } else {
                    Text("Available")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if model.connectedPeripheral == peripheral {
                Button(action: {
                    model.sendHandshake()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        selectedTab = 1
                    }
                }) {
                    Label("Find", systemImage: "location.magnifyingglass")
                        .fontWeight(.bold)
                        .foregroundColor(Color(.white))
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button("Connect") {
                    model.connect(to: peripheral)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}
