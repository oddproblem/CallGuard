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

// Map CallGuard IDs → socket IDs
const users = {};

// Map CallGuard IDs → FCM Tokens
const fcmTokens = {};

// Pending call offers: callerId → { target, from, offer, timestamp }
// Stored so the callee can retrieve the offer after waking up from push
const pendingCalls = {};

// Health check endpoint
app.get("/", (req, res) => {
  res.json({ status: "ok", users: Object.keys(users).length });
});

// TURN credentials endpoint — returns free Metered Open Relay servers
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
      {
        urls: "turn:a.relay.metered.ca:80?transport=tcp",
        username: "e8dd65b92aad5bee9bb2b50d",
        credential: "3ZJhNOpbZLPiuRgp",
      },
      {
        urls: "turn:a.relay.metered.ca:443",
        username: "e8dd65b92aad5bee9bb2b50d",
        credential: "3ZJhNOpbZLPiuRgp",
      },
      {
        urls: "turns:a.relay.metered.ca:443?transport=tcp",
        username: "e8dd65b92aad5bee9bb2b50d",
        credential: "3ZJhNOpbZLPiuRgp",
      },
    ],
  });
});

// Endpoint for callee to retrieve a pending call offer after waking from push
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

io.on("connection", (socket) => {
  console.log(`[+] Socket connected: ${socket.id}`);

  // Register a user with their CallGuard ID
  socket.on("register", (id) => {
    users[id] = socket.id;
    console.log(`[REGISTER] ${id} → ${socket.id} (${Object.keys(users).length} online)`);
  });

  // Register push token
  socket.on("register-fcm-token", (data) => {
    fcmTokens[data.userId] = data.token;
    console.log(`[FCM REGISTER] ${data.userId} → token received`);
  });

  // Caller sends an offer to a target user
  socket.on("call-user", (data) => {
    const target = users[data.target];
    if (target) {
      console.log(`[CALL] ${data.from} → ${data.target}`);
      io.to(target).emit("incoming-call", data);
    } else {
      console.log(`[CALL] Target ${data.target} not found via socket.`);
      const fcmToken = fcmTokens[data.target];
      if (fcmToken) {
        console.log(`[CALL] Target ${data.target} is offline but has FCM token. Sending push notification...`);

        // Store the pending call so callee can fetch the full offer later
        pendingCalls[data.target] = {
          from: data.from,
          offer: data.offer,
          timestamp: Date.now(),
        };

        // Send DATA-ONLY message (no 'notification' key) so that the
        // background handler is invoked and we can show callkit incoming.
        // Including the offer in the data payload so the callee has it.
        const message = {
          token: fcmToken,
          data: {
            type: "incoming_call",
            from: data.from,
            offer: JSON.stringify(data.offer),
          },
          android: {
            priority: "high",
            ttl: 60000,
          },
        };
        admin.messaging().send(message)
          .then((response) => {
            console.log(`[FCM] Successfully sent data message:`, response);
          })
          .catch((error) => {
            console.log(`[FCM] Error sending message:`, error);
          });
      } else {
        console.log(`[CALL] Target ${data.target} is offline without an FCM token`);
        socket.emit("user-offline", { target: data.target });
      }
    }
  });

  // Callee answers the call
  socket.on("answer-call", (data) => {
    const caller = users[data.to];
    // Clean up pending call
    delete pendingCalls[data.to];
    if (caller) {
      console.log(`[ANSWER] → ${data.to}`);
      io.to(caller).emit("call-answered", data);
    }
  });

  // ICE candidate exchange
  socket.on("ice-candidate", (data) => {
    const target = users[data.to];
    if (target) {
      io.to(target).emit("ice-candidate", {
        candidate: data.candidate,
      });
    }
  });

  // Call rejected
  socket.on("reject-call", (data) => {
    const target = users[data.to];
    // Clean up pending call
    delete pendingCalls[data.to];
    if (target) {
      console.log(`[REJECT] → ${data.to}`);
      io.to(target).emit("call-rejected", { from: data.to });
    }
  });

  // Call ended
  socket.on("end-call", (data) => {
    const target = users[data.to];
    if (target) {
      console.log(`[END] → ${data.to}`);
      io.to(target).emit("call-ended", { from: data.to });
    }
  });

  // Cleanup on disconnect
  socket.on("disconnect", () => {
    for (const [id, sid] of Object.entries(users)) {
      if (sid === socket.id) {
        delete users[id];
        console.log(`[-] ${id} disconnected (${Object.keys(users).length} online)`);
        break;
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`CallGuard signaling server running on port ${PORT}`);
});
