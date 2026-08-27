# CallGuard Backend Architecture (Detailed Analysis)

This document provides a highly detailed, line-by-line architectural breakdown of the CallGuard backend, explaining the exact data flow, execution paths, dependencies, and security implications of the codebase.

## 1. Project Overview & Folder Structure
The backend is located in `d:\VoIP calls\callguard-server` and functions as a **Signaling Server** for WebRTC and a **Bridge** for Firebase Cloud Messaging (FCM). 

### Dependencies (`package.json`)
- `express (^5.2.1)`: Provides the HTTP routing framework for health checks and TURN server credentials.
- `socket.io (^4.8.3)`: Enables real-time, bidirectional websocket communication for WebRTC signaling (SDP offers/answers, ICE candidates).
- `firebase-admin (^13.7.0)`: Used to trigger server-to-device push notifications, waking up offline mobile apps.
- `cors (^2.8.6)`: Allows cross-origin requests.

---

## 2. Entry Point & Initialization Flow
**File Path:** `d:\VoIP calls\callguard-server\server.js`

### A. Environment and Firebase Setup
**Purpose:** Initialize the Express server, the HTTP server, the Socket.IO instance, and the Firebase Admin SDK.

**Code Snippet:**
```javascript
const express = require("express");
const http = require("http");
const fs = require("fs");
const { Server } = require("socket.io");
const admin = require("firebase-admin");

// Load service account: prefer local file (dev), fall back to env var (production)
let serviceAccount;
if (fs.existsSync("./serviceAccountKey.json")) {
  serviceAccount = require("./serviceAccountKey.json");
} else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
  serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
} else {
  console.error("ERROR: No Firebase service account found. Set FIREBASE_SERVICE_ACCOUNT env var.");
  process.exit(1);
}

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*" },
  pingTimeout: 30000,
  pingInterval: 10000,
});
```
**Why it was written this way:** 
The Firebase initialization includes a fallback mechanism. During local development, it reads `serviceAccountKey.json` directly from the filesystem. In production (e.g., Docker, Heroku), it expects a JSON-stringified environment variable. If neither exists, it explicitly terminates the process `process.exit(1)` to prevent the server from running in a broken state. `pingTimeout` and `pingInterval` in Socket.IO are configured to maintain connections reliably across unreliable mobile networks.

---

## 3. Database Models (In-Memory State)
**Purpose:** Manage state for active WebRTC connections and push notifications without requiring a heavy persistent database like Redis or PostgreSQL.

**Code Snippet:**
```javascript
// Map CallGuard IDs → socket IDs
const users = {};

// Map CallGuard IDs → FCM Tokens
const fcmTokens = {};

// Pending call offers: callerId → { target, from, offer, timestamp }
const pendingCalls = {};

// Queue for ICE candidates sent to offline users
const pendingIceCandidates = {};

// Map socket IDs back to CallGuard IDs
const socketToUser = {};
```
**Data Flow / Execution:**
- **`users`**: Populated when an active client emits the `register` event. Used to route `incoming-call` events instantly.
- **`fcmTokens`**: Populated via `register-fcm-token`. Used when `users[target]` is undefined, indicating the callee's app is terminated or backgrounded.
- **`pendingCalls` / `pendingIceCandidates`**: When sending a push notification, the SDP offer and any early ICE candidates are cached here. Once the callee wakes up, they fetch these to establish the peer connection.

**Security Implications:** Storing this in-memory means that if the Node.js server restarts, all pending calls and current routing tables are lost. This is an acceptable trade-off for a lightweight, stateless-like signaling server, but horizontal scaling would require migrating these objects to Redis.

---

## 4. REST APIs (HTTP Routes)

### A. Health Check
**Code Snippet:**
```javascript
app.get("/", (req, res) => {
  res.json({ status: "ok", users: Object.keys(users).length });
});
```
**Purpose:** Allows load balancers or uptime monitoring to verify the server is alive and report active concurrency.

### B. TURN/STUN Credentials (`/turn-credentials`)
**Purpose:** Provides clients with the necessary ICE servers to bypass NATs and Firewalls during WebRTC.
**Code Snippet:**
```javascript
app.get("/turn-credentials", (req, res) => {
  res.json({
    iceServers: [
      { urls: "stun:stun.l.google.com:19302" },
      { urls: "stun:stun1.l.google.com:19302" },
      {
        urls: "turn:a.relay.metered.ca:80",
        username: "e8dd65b92aad5bee9bb2b50d",
        credential: "3ZJhNOpbZLPiuRgp",
      },
      // ... (other metered.ca TCP/UDP configurations)
    ],
  });
});
```
**Why it was written this way:** Hardcoding these in the backend rather than the frontend allows the developer to rotate TURN credentials (e.g., if metered.ca rate limits them) without requiring a mobile app update.

### C. Pending Call Offer Fetcher (`/pending-call/:userId`)
**Purpose:** An HTTP endpoint specifically designed for devices waking up from an FCM push notification.
**Code Snippet:**
```javascript
app.get("/pending-call/:userId", (req, res) => {
  const userId = req.params.userId;
  const pending = pendingCalls[userId];
  if (pending) {
    // Check if the pending call is still fresh (< 60 seconds old)
    if (Date.now() - pending.timestamp < 60000) {
      res.json({ success: true, call: { from: pending.from, offer: pending.offer } });
    } else {
      delete pendingCalls[userId];
      res.json({ success: false, reason: "expired" });
    }
  } else {
    res.json({ success: false, reason: "not_found" });
  }
});
```
**Error Handling / Validation:** It strictly checks `Date.now() - pending.timestamp < 60000`. If the call is older than 60 seconds, it is considered abandoned by the caller, deleted, and returns `"expired"`. This prevents "ghost rings" where a user opens the app hours later and it suddenly rings.

---

## 5. Socket.IO Signaling Flow

### A. Connection and Authentication
**Code Snippet:**
```javascript
io.on("connection", (socket) => {
  console.log(`[+] Socket connected: ${socket.id}`);

  // Register a user with their CallGuard ID
  socket.on("register", (id) => {
    users[id] = socket.id;
    socketToUser[socket.id] = id;
    console.log(`[REGISTER] ${id} → ${socket.id} (${Object.keys(users).length} online)`);
  });

  // Register push token
  socket.on("register-fcm-token", (data) => {
    fcmTokens[data.userId] = data.token;
  });
```
**Data flow:** Mobile clients first connect, then emit `register` with their 6-digit CallGuard ID. The bi-directional `users` and `socketToUser` dictionaries are populated. 

### B. Outgoing Calls & Background Wakeup (`call-user`)
**Purpose:** Route the WebRTC SDP Offer. Trigger a background wake if the target is disconnected.
**Code Snippet:**
```javascript
  socket.on("call-user", (data) => {
    const target = users[data.target];
    if (target) {
      // 1. User is online and socket is active
      io.to(target).emit("incoming-call", data);
    } else {
      // 2. User is offline
      const fcmToken = fcmTokens[data.target];
      if (fcmToken) {
        pendingCalls[data.target] = {
          from: data.from,
          offer: data.offer,
          timestamp: Date.now(),
        };

        const message = {
          token: fcmToken,
          data: {
            type: "incoming_call",
            from: data.from,
            offer: JSON.stringify(data.offer),
          },
          android: { priority: "high", ttl: 60000 },
        };
        admin.messaging().send(message)
          .then((response) => console.log(`[FCM] Successfully sent data message`))
          .catch((error) => console.log(`[FCM] Error sending message:`, error));
      } else {
        socket.emit("user-offline", { target: data.target });
      }
    }
  });
```
**Why it was written this way (CRITICAL):**
Notice the FCM payload only contains a `data` block, lacking a `notification` block. This is a **Data-Only Message**. If a `notification` block were present, Android would display a standard system tray notification. By making it data-only, it directly triggers the Flutter app's background isolate, allowing the app to invoke the native iOS/Android `CallKit` full-screen incoming call UI. The SDP offer is stringified and passed directly into the push notification payload so the callee has it immediately upon waking.

### C. Answering Calls & ICE Candidate Queueing (`answer-call` & `ice-candidate`)
**Code Snippet:**
```javascript
  socket.on("answer-call", (data) => {
    const caller = users[data.to];
    const calleeId = socketToUser[socket.id];
    
    if (calleeId) {
      delete pendingCalls[calleeId]; // Clean up
      
      // Flush queued ICE candidates back to the callee
      if (pendingIceCandidates[calleeId]) {
        pendingIceCandidates[calleeId].forEach(candidate => {
          socket.emit("ice-candidate", { candidate: candidate });
        });
        delete pendingIceCandidates[calleeId];
      }
    }
    
    if (caller) {
      io.to(caller).emit("call-answered", data);
    }
  });

  socket.on("ice-candidate", (data) => {
    const target = users[data.to];
    if (target) {
      io.to(target).emit("ice-candidate", { candidate: data.candidate });
    } else {
      if (!pendingIceCandidates[data.to]) pendingIceCandidates[data.to] = [];
      pendingIceCandidates[data.to].push(data.candidate);
    }
  });
```
**Execution flow:** Because WebRTC generation of ICE candidates happens asynchronously, the caller might generate ICE candidates *before* the callee's device wakes up from the push notification. If `target` is undefined, the server pushes candidates to the `pendingIceCandidates` array. When the callee finally connects and emits `answer-call`, the server loops through this array and blasts the cached ICE candidates to the callee, preventing connection deadlocks.

### D. Rejection, Ending, and Disconnection
**Code Snippet:**
```javascript
  socket.on("reject-call", (data) => { /* Emits call-rejected, deletes pending */ });
  socket.on("end-call", (data) => { /* Emits call-ended */ });

  socket.on("disconnect", () => {
    const id = socketToUser[socket.id];
    if (id) {
      delete users[id];
      delete socketToUser[socket.id];
      console.log(`[-] ${id} disconnected (${Object.keys(users).length} online)`);
    }
  });
```
**Error Handling:** The `disconnect` event guarantees that `users` and `socketToUser` are cleaned up when a client loses internet or closes the app, preventing zombie sockets from swallowing signaling events.
