import SwiftUI
import CoreLocation

// MARK: - IBeaconView
/// Top-level view for the iBeacon demo tab.
/// Purely reactive — all logic lives in IBeaconModel.
struct IBeaconView: View {
    @StateObject private var viewModel = IBeaconModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    RoleSelectorView(viewModel: viewModel)
                    StatusCardView(viewModel: viewModel)

                    if viewModel.role == .scanner {
                        ProximityIndicatorView(viewModel: viewModel)
                        BeaconMetricsView(viewModel: viewModel)
                    } else {
                        BeaconBroadcastView(viewModel: viewModel)
                    }

                    ControlButtonView(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle("iBeacon Demo")
            .alert("Permission Required", isPresented: $viewModel.permissionDenied) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Location access is required for iBeacon functionality. Please enable it in Settings.")
            }
        }
    }
}

// MARK: - Role Selector
/// Segmented control to pick Beacon (transmit) or Scanner (receive) role.
struct RoleSelectorView: View {
    @ObservedObject var viewModel: IBeaconModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Select Role")
                .font(.headline)

            Picker("Role", selection: Binding(
                get: { viewModel.role },
                set: { viewModel.setRole($0) }
            )) {
                Text("📡  Beacon").tag(IBeaconRole.beacon)
                Text("🔍  Scanner").tag(IBeaconRole.scanner)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isActive)

            Text(viewModel.role == .beacon
                 ? "This phone will broadcast as an iBeacon."
                 : "This phone will detect and range nearby iBeacons.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Status Card
/// Displays the current status string from the ViewModel.
struct StatusCardView: View {
    @ObservedObject var viewModel: IBeaconModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.isActive ? "antenna.radiowaves.left.and.right" : "antenna.radiowaves.left.and.right.slash")
                .font(.title2)
                .foregroundColor(viewModel.isActive ? .blue : .secondary)
                .symbolEffect(.pulse, isActive: viewModel.isActive)

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.isActive ? "Active" : "Inactive")
                    .font(.caption).bold()
                    .foregroundColor(viewModel.isActive ? .blue : .secondary)
                Text(viewModel.statusMessage)
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Proximity Indicator (Scanner only)
/// Animated concentric rings that grow/shrink based on detected proximity.
struct ProximityIndicatorView: View {
    @ObservedObject var viewModel: IBeaconModel

    private var ringColor: Color {
        switch viewModel.proximity {
        case .immediate: return .green
        case .near:      return .yellow
        case .far:       return .orange
        default:         return .gray.opacity(0.4)
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Proximity")
                .font(.headline)

            ZStack {
                // Outer ring (far)
                Circle()
                    .stroke(ringColor.opacity(0.2), lineWidth: 2)
                    .frame(width: 200, height: 200)

                // Middle ring (near)
                Circle()
                    .stroke(ringColor.opacity(viewModel.proximityScale >= 0.65 ? 0.5 : 0.15), lineWidth: 2)
                    .frame(width: 140, height: 140)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.proximity)

                // Inner ring (immediate)
                Circle()
                    .fill(ringColor.opacity(viewModel.proximityScale >= 1.0 ? 0.25 : 0.08))
                    .frame(width: 80, height: 80)
                    .animation(.easeInOut(duration: 0.5), value: viewModel.proximity)

                // Center beacon icon
                VStack(spacing: 4) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.title)
                        .foregroundColor(ringColor)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.proximity)

                    Text(viewModel.proximity == .unknown ? "—" : viewModel.proximityLabel.components(separatedBy: "(").first ?? "")
                        .font(.caption2).bold()
                        .foregroundColor(ringColor)
                }
            }

            Text(viewModel.proximityLabel)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(ringColor)
                .animation(.easeInOut, value: viewModel.proximity)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Beacon Metrics (Scanner only)
/// Shows numeric accuracy and RSSI values from ranged beacon.
struct BeaconMetricsView: View {
    @ObservedObject var viewModel: IBeaconModel

    private var accuracyText: String {
        viewModel.accuracy < 0 ? "—" : String(format: "%.2f m", viewModel.accuracy)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Beacon Metrics")
                .font(.headline)

            HStack {
                MetricTileView(
                    icon: "ruler",
                    label: "Est. Distance",
                    value: accuracyText,
                    color: .blue
                )
                MetricTileView(
                    icon: "waveform.path",
                    label: "RSSI",
                    value: viewModel.rssi == 0 ? "—" : "\(viewModel.rssi) dBm",
                    color: .purple
                )
            }

            Text("UUID: \(IBeaconModel.beaconUUID.uuidString)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Metric Tile
struct MetricTileView: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.title3).bold()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(10)
    }
}

// MARK: - Beacon Broadcast Info (Beacon only)
/// Shown when this device is acting as the beacon — displays what it's broadcasting.
struct BeaconBroadcastView: View {
    @ObservedObject var viewModel: IBeaconModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Broadcasting Identity")
                .font(.headline)

            VStack(spacing: 10) {
                BeaconInfoRowView(label: "UUID", value: IBeaconModel.beaconUUID.uuidString)
                BeaconInfoRowView(label: "Major", value: "\(IBeaconModel.beaconMajor)")
                BeaconInfoRowView(label: "Minor", value: "\(IBeaconModel.beaconMinor)")
                BeaconInfoRowView(label: "Identifier", value: IBeaconModel.beaconIdentifier)
            }

            Text("The Scanner phone must range for the same UUID to detect this beacon.")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        }
        .padding()
        .background(Color(uiColor: .secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct BeaconInfoRowView: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.caption).bold()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Control Button
/// Start / Stop button that adapts label and color to current state.
struct ControlButtonView: View {
    @ObservedObject var viewModel: IBeaconModel

    var body: some View {
        Button {
            viewModel.isActive ? viewModel.stop() : viewModel.start()
        } label: {
            Label(
                viewModel.isActive ? "Stop" : (viewModel.role == .beacon ? "Start Broadcasting" : "Start Scanning"),
                systemImage: viewModel.isActive ? "stop.circle.fill" : "play.circle.fill"
            )
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding()
            .background(viewModel.isActive ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(12)
        }
    }
}

// MARK: - Preview
#Preview {
    IBeaconView()
}
