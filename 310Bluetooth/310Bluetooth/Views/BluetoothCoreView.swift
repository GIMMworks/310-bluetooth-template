import SwiftUI
import CoreBluetooth


struct BluetoothCoreView: View {
    
    @StateObject private var viewModel = BluetoothCoreModel()
    
    var body: some View {
        NavigationStack {
            VStack {
                List {
                    Text("Test Device 1")
                    Text("Test Device 2")
                }
                List(viewModel.peripherals, id: \.identifier) { peripheral in
                    Button {
                        viewModel.connect(to: peripheral)
                    } label: {
                        Text(peripheral.name ?? "Unknown Device")
                    }
                }
                
                if viewModel.isLoading {
                    ProgressView("Connecting...")
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)
                }
            }
        }
    }
}
