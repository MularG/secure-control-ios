# Secure Control - iOS App

Custom iPhone app for secure WebSocket control via the Mac relay.

## Security
- Token sent in `Authorization: Bearer` header (not URL query string)
- Not logged, not stripped by iOS
- Custom User-Agent: `SecureControl/1.0`

## Setup in Xcode

1. Open Xcode on your Mac
2. File > New > Project > iOS > App
   - Product Name: `SecureControl`
   - Interface: SwiftUI
   - Language: Swift
3. Delete the default files, copy in:
   - `ControlApp.swift`
   - `ContentView.swift`
   - `WebSocketManager.swift`
   - `XIAOBridge.swift`
4. Signing & Capabilities:
   - Select your Apple Developer Team
   - Bundle Identifier: `com.yourname.securecontrol` (must be unique)
5. Connect iPhone via USB, select it as run destination, hit Run

## Configuration

In `WebSocketManager.swift`, update:
- `relayURL`: Your relay WebSocket URL (default: `wss://control.tolasan.com/device`)
- `authToken`: Must match the relay's expected token

In `XIAOBridge.swift`:
- `xiaoURL`: XIAO NCM address (default: `http://172.31.254.1/input`)

## Relay Changes Required

The Mac relay (`server.js`) must verify the `Authorization` header:

```javascript
// In the upgrade handler, before accepting:
const auth = request.headers['authorization'];
if (auth !== `Bearer ${DEVICE_TOKEN}`) {
  socket.end('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
  return;
}
```

This replaces the open relay — only clients with the correct Bearer token can connect.

## Protocol

1. App connects WS with `Authorization: Bearer <token>` header
2. App sends `{"type":"hello","deviceID":"...","sessionID":"...","name":"...","capabilities":["screen","input"]}`
3. Relay replies `{"type":"ready","inputDeviceSecret":"..."}`
4. Relay sends `{"type":"run","id":"...","hex":"..."}` → App POSTs hex to XIAO → replies `accepted` then `completed`
5. Relay sends `{"type":"screen","id":"..."}` → App captures screenshot → replies with base64 JPEG
