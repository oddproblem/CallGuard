const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*" },
  pingTimeout: 30000,
  pingInterval: 10000,
});

// Map CallGuard IDs → socket IDs
const users = {};

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

io.on("connection", (socket) => {
  console.log(`[+] Socket connected: ${socket.id}`);

  // Register a user with their CallGuard ID
  socket.on("register", (id) => {
    users[id] = socket.id;
    console.log(`[REGISTER] ${id} → ${socket.id} (${Object.keys(users).length} online)`);
  });

  // Caller sends an offer to a target user
  socket.on("call-user", (data) => {
    const target = users[data.target];
    if (target) {
      console.log(`[CALL] ${data.from} → ${data.target}`);
      io.to(target).emit("incoming-call", data);
    } else {
      console.log(`[CALL] Target ${data.target} not found — offline`);
      socket.emit("user-offline", { target: data.target });
    }
  });

  // Callee answers the call
  socket.on("answer-call", (data) => {
    const caller = users[data.to];
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
