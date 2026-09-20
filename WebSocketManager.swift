import SwiftUI
import Foundation

class WebSocketManager: ObservableObject {
    @Published var isConnected = false
    @Published var statusMessage = "Disconnected"
    @Published var deviceID = UUID().uuidString
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var inputDeviceSecret: String?
    private let xiaoBridge = XIAOBridge()
    
    // Configuration - update these for your setup
    private let relayURL = "wss://control.tolasan.com/device"
    private let authToken = "09pa_D8f3x8KmG42a1EgvF-KuA_iLHqg4NGKixxlySg"
    
    func connect() {
        guard webSocketTask == nil else { return }
        
        statusMessage = "Connecting..."
        
        guard let url = URL(string: relayURL) else {
            statusMessage = "Invalid URL"
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.setValue("SecureControl/1.0", forHTTPHeaderField: "User-Agent")
        
        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        
        statusMessage = "WebSocket connecting..."
        listen()
        
        // Send hello after a brief delay to allow connection
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.sendHello()
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        isConnected = false
        statusMessage = "Disconnected"
    }
    
    private func sendHello() {
        let sessionID = UUID().uuidString
        let hello: [String: Any] = [
            "type": "hello",
            "deviceID": deviceID,
            "sessionID": sessionID,
            "name": "iPhone Secure Control",
            "capabilities": ["screen", "input"]
        ]
        
        sendJSON(hello)
        statusMessage = "Hello sent, waiting for ready..."
    }
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue listening
                self.listen()
                
            case .failure(let error):
                DispatchQueue.main.async {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isConnected = false
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else {
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch type {
            case "ready":
                if let secret = json["inputDeviceSecret"] as? String {
                    self.inputDeviceSecret = secret
                    self.xiaoBridge.setSecret(secret)
                }
                self.isConnected = true
                self.statusMessage = "Connected ✓"
                
            case "run":
                if let id = json["id"] as? String,
                   let hex = json["hex"] as? String {
                    self.handleRun(id: id, hex: hex)
                }
                
            case "screen":
                if let id = json["id"] as? String {
                    self.handleScreen(id: id)
                }
                
            case "stop":
                self.statusMessage = "Stop received"
                
            case "end-session":
                self.statusMessage = "Session ended"
                self.disconnect()
                
            default:
                break
            }
        }
    }
    
    private func handleRun(id: String, hex: String) {
        // Acknowledge receipt
        sendJSON(["id": id, "type": "accepted"])
        
        // Forward to XIAO
        xiaoBridge.sendInput(hex: hex) { [weak self] success, error in
            guard let self = self else { return }
            if success {
                self.sendJSON(["id": id, "type": "completed"])
                DispatchQueue.main.async {
                    self.statusMessage = "Input completed ✓"
                }
            } else {
                self.sendJSON(["id": id, "type": "failed", "error": error ?? "XIAO failed"])
                DispatchQueue.main.async {
                    self.statusMessage = "Input failed: \(error ?? "unknown")"
                }
            }
        }
    }
    
    private func handleScreen(id: String) {
        // Capture screenshot
        guard let screenshot = captureScreenshot() else {
            sendJSON(["id": id, "type": "failed", "error": "Screenshot failed"])
            return
        }
        
        let response: [String: Any] = [
            "id": id,
            "type": "screenshot",
            "data": screenshot.base64,
            "mimeType": "image/jpeg",
            "width": screenshot.width,
            "height": screenshot.height,
            "capturedAt": Date().timeIntervalSince1970 * 1000,
            "frameID": UUID().uuidString
        ]
        sendJSON(response)
    }
    
    private func captureScreenshot() -> (base64: String, width: Int, height: Int)? {
        guard let window = UIApplication.shared.windows.first else { return nil }
        
        let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
        let image = renderer.image { ctx in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        
        guard let jpegData = image.jpegData(compressionQuality: 0.7) else { return nil }
        
        return (
            base64: jpegData.base64EncodedString(),
            width: Int(window.bounds.width),
            height: Int(window.bounds.height)
        )
    }
    
    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8) else {
            return
        }
        
        webSocketTask?.send(.string(text)) { error in
            if let error = error {
                print("Send error: \(error)")
            }
        }
    }
}
