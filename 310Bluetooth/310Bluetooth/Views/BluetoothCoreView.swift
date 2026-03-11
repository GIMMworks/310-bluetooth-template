import SwiftUI
import CoreBluetooth

struct BluetoothCoreView: View {
    // This connects to the model shared by the MainTabView
    @ObservedObject var viewModel: BluetoothCoreModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "cpu")
                        .font(.largeTitle)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        Text("Live Device Data")
                            .font(.title2)
                            .bold()
                        Text(viewModel.connectedPeripheral?.name ?? "Unknown Device")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.bottom)

                Divider()

                // Data Display Section
                VStack(alignment: .leading, spacing: 15) {
                    Text("Incoming GATT Values")
                        .font(.headline)
                        .foregroundColor(.blue)

                  
                    Text(viewModel.discoveredData)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                }

                Spacer()
                
                HStack {
                    Circle()
                        .fill(viewModel.connectedPeripheral != nil ? Color.green : Color.red)
                        .frame(width: 10, height: 10)
                    Text(viewModel.connectedPeripheral != nil ? "Connected" : "Disconnected")
                        .font(.caption)
                        .textCase(.uppercase)
                }
            }
            .padding()
        }
        .navigationTitle("Data Stream")
    }
}
