# ebus.d

A lightweight, real-time message bus server written in D that enables tag-based publish-subscribe communication over WebSockets and HTTP.

## Overview

**ebus.d** is a flexible event bus / message broker that facilitates real-time communication between clients using a publish-subscribe (pub/sub) pattern. It's designed to be simple, fast, and easy to integrate into web applications and services.

## Key Features

- **Tag-based pub/sub system**: Subscribe to specific tags and receive only relevant messages
- **Group isolation**: Organize messages into separate groups (channels/rooms)
- **WebSocket support**: Real-time bidirectional communication
- **HTTP API**: REST endpoint for pushing messages to subscribers
- **Flexible tag matching**: Partial tag matching for powerful message routing
- **Optional authentication**: Integrate with external authentication services
- **Lightweight**: Minimal dependencies, built on vibe.d framework
- **Cross-platform**: Works on Linux and Windows

## Use Cases

- Real-time chat applications
- Live notifications and updates
- Event-driven microservices communication
- IoT device messaging
- Collaborative applications
- Dashboard real-time data feeds

## Build Instructions

### On 64-bit Linux

```bash
# Install DMD compiler
# Install dependencies: sudo apt-get install libssl-dev

# Copy sample configuration
cp config.json.sample config.json

# Build the project
make
```

### On Windows

```bash
# Install DMD and DUB from https://dlang.org/download.html

# Copy sample configuration
copy config.json.sample config.json

# Build with DUB
dub
```

### Docker

```bash
docker build -t ebus-d .
docker run -p 4445:4445 -v $(pwd)/config.json:/app/config.json ebus-d
```

## Configuration

Edit `config.json` to configure the server:

```json
{
  "bind": "0.0.0.0",          // Bind address
  "port": 4445,               // Server port
  "auth": false,              // Enable/disable authentication
  "authUrl": "http://...",    // Authentication service URL
  "authKey": "12345"          // Authentication key
}
```

## Quick Start

1. Start the server:
   ```bash
   ./ebus-d
   ```

2. Open the example chat in your browser by opening the file directly from disk:
   ```
   file:///path/to/ebus.d/examples/web/index.html
   ```
   Or simply open `examples/web/index.html` in your browser via File → Open.

3. Open multiple browser tabs to test real-time messaging

## Usage

### JavaScript Client

```javascript
// Connect to the server
var connection = EBus.connect("ws://localhost:4445/ws", () => {
  console.log("Connected!");
  
  // Join a group
  var group = connection.joinGroup("myGroup");
  
  // Subscribe to tags
  group.subscribe("message", (event, data) => {
    console.log("Received:", data);
  });
  
  // Invoke/send messages
  group.invoke("message", {text: "Hello, World!", from: "User1"});
});
```

### WebSocket Protocol

Messages follow this JSON format:

```json
{
  "group": "group_name",
  "action": "subscribe|invoke|join|exit",
  "seq": "unique_sequence_id",
  "tags": ["tag1", "tag2"],
  "data": {}
}
```

#### Actions

- **join**: Join a group (for member tracking)
- **subscribe**: Subscribe to specific tags
- **invoke**: Send a message to subscribers matching the tags
- **unsubscribe**: Remove a subscription
- **exit**: Leave a group

#### Subscribe Example
```json
{
  "group": "chat",
  "action": "subscribe",
  "seq": "abc123",
  "tags": ["message"]
}
```

#### Invoke Example
```json
{
  "group": "chat",
  "action": "invoke",
  "seq": "def456",
  "tags": ["message"],
  "data": {
    "text": "Hello!",
    "from": "Alice"
  }
}
```

### HTTP API

Push messages via HTTP POST:

```bash
curl -X POST http://localhost:4445/push/myGroup/invoke \
  -H "Content-Type: application/json" \
  -d '{
    "tags": ["notification"],
    "data": {"message": "Server alert"}
  }'
```

**Response:**
```json
{
  "status": "OK",
  "subscribers": 5
}
```

## Tag Matching

ebus.d uses **partial tag matching**: A subscription's tags must be a **subset** of the invoked tags for the message to be delivered.

**Example:**

- Subscription tags: `["chat", "public"]`
- Invoked with: `["chat", "public", "message"]` → ✅ **Matched**
- Invoked with: `["chat"]` → ❌ **Not matched**
- Invoked with: `["public"]` → ❌ **Not matched**

This allows for flexible message routing and filtering.

## Client Libraries

### JavaScript/Browser
Located in `clients/js/ebus.js`

### Node.js
```javascript
const EBus = require('./clients/js/ebus.js');
const WebSocket = require('ws');
EBus.reWS(WebSocket); // Use Node.js WebSocket implementation

var con = EBus.connect("ws://localhost:4445/ws", () => {
  // Your code here
});
```

## Examples

Check the `/examples` directory for:
- **Web chat**: Real-time chat application (`examples/web/`)
- **Bash scripts**: Command-line message pushing (`examples/bash/`)
- **Node.js**: WebSocket client example (`examples/nodejs/`)

## Architecture

- **Groups (`BGroup`)**: Isolated message spaces
- **Subscriptions (`BSubscription`)**: Tag-based subscriptions within groups
- **Tag serialization**: Efficient tag matching and comparison
- **WebSocket management**: Automatic cleanup of disconnected clients

## Development

Built with:
- **D language** (DMD 2.083+)
- **vibe.d** 0.10.2 - Web framework
- **OpenSSL** - For secure connections

## License

See [LICENSE](LICENSE) file for details.

## Authors

- Lord_Evil
- Vlad Bocharov

Copyright © 2017, Open Minded Webmasters
