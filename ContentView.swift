import SwiftUI

struct ContentView: View {
    @EnvironmentObject var wsManager: WebSocketManager
    @State private var xiaoConnected = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Status
                VStack(spacing: 8) {
                    Image(systemName: wsManager.isConnected ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(wsManager.isConnected ? .green : .red)
                    
                    Text(wsManager.statusMessage)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                // Device ID
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device ID")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(wsManager.deviceID)
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .padding(.horizontal)
                
                // XIAO Status
                HStack {
                    Image(systemName: xiaoConnected ? "checkmark.circle" : "xmark.circle")
                        .foregroundColor(xiaoConnected ? .green : .gray)
                    Text("XIAO: \(xiaoConnected ? "Connected" : "Not detected")")
                        .font(.subheadline)
                    Spacer()
                    Button("Check") {
                        checkXIAO()
                    }
                    .font(.subheadline)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Connect/Disconnect Button
                Button(action: {
                    if wsManager.isConnected {
                        wsManager.disconnect()
                    } else {
                        wsManager.connect()
                    }
                }) {
                    Text(wsManager.isConnected ? "Disconnect" : "Connect")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(wsManager.isConnected ? Color.red : Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .navigationTitle("Secure Control")
            .onAppear {
                checkXIAO()
            }
        }
    }
    
    private func checkXIAO() {
        let bridge = XIAOBridge()
        bridge.checkStatus { connected in
            DispatchQueue.main.async {
                xiaoConnected = connected
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(WebSocketManager())
    }
}
