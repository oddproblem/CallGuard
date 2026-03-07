const express = require("express");
const http = require("http");
const { Server } = require("socket.io");

const app = express();
const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*" },
});

// Map CallGuard IDs → socket IDs
const users = {};

// Health check endpoint (Render needs this)
app.get("/", (req, res) => {
  res.json({ status: "ok", users: Object.keys(users).length });
});

io.on("connection", (socket) => {
  console.log(`[+] Socket connected: ${socket.id}`);

  // Register a user with their CallGuard ID
  socket.on("register", (id) => {
    users[id] = socket.id;
    console.log(`[REGISTER] ${id} → ${socket.id}`);
  });

  // Caller sends an offer to a target user
  socket.on("call-user", (data) => {
    const target = users[data.target];
    if (target) {
      console.log(`[CALL] ${data.from} → ${data.target}`);
      io.to(target).emit("incoming-call", data);
    } else {
      console.log(`[CALL] Target ${data.target} not found`);
      socket.emit("call-rejected", { from: data.target, reason: "User offline" });
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
        console.log(`[-] ${id} disconnected`);
        break;
      }
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, "0.0.0.0", () => {
  console.log(`CallGuard signaling server running on port ${PORT}`);
});
