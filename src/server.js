const express = require('express');
const http = require('http');
const socket = require('socket.io');
const crypto = require('crypto');
const { execSync } = require('child_process');
const fs = require('fs');

const app = express();
const server = http.createServer(app);
const io = socket(server);

// Serve static files
app.use(express.static(__dirname));

// Default route → login page
app.get("/", (req, res) => {
    res.sendFile(__dirname + "/login.html");
});

// AES-256 KEY + IV
const KEY = crypto.randomBytes(32);
const IV = crypto.randomBytes(16);

function encrypt(text) {
    const cipher = crypto.createCipheriv("aes-256-cbc", KEY, IV);
    return cipher.update(text, "utf8", "hex") + cipher.final("hex");
}

function getMac() {
    try {
        const out = execSync("ip link | awk '/ether/ {print $2; exit}'")
            .toString().trim();
        return out || "unknown";
    } catch {
        return "unknown";
    }
}

// ACTIVE USER LIST
let activeUsers = [];

io.on("connection", (socket) => {
    console.log("User connected.");

    // --- USER JOINS ---
    socket.on("newUser", (username) => {
        socket.username = username;

        if (!activeUsers.includes(username)) {
            activeUsers.push(username);
        }

        // Send updated list to all clients
        io.emit("activeUsers", activeUsers);
    });

    // --- MESSAGE RECEIVED ---
    // Chat messages
socket.on("chatMessage", (msgData) => {
    const { user, message } = msgData;

    const mac = getMac();                   // Existing MAC lookup
    const ip = socket.handshake.address;    // NEW: capture client IP

    const ciphertext = encrypt(message);

    // Emit unencrypted message to clients
    io.emit("chatMessage", { user, msg: message });

    // Create structured forensic log
    const file = `./queue/inbox/msg_${Date.now()}.txt`;
    const payload =
        `USER=${user}\n` +
        `MAC=${mac}\n` +
        `IP=${ip}\n` +                      // NEW FIELD
        `CIPHERTEXT=${ciphertext}\n` +
        `IV=${IV.toString("hex")}\n`;

    fs.writeFileSync(file, payload);

    console.log("Encrypted message: message encrypted");
});



    // --- USER DISCONNECTS ---
    socket.on("disconnect", () => {
        if (socket.username) {
            activeUsers = activeUsers.filter(u => u !== socket.username);
            io.emit("activeUsers", activeUsers);
        }
    });
});

// START SERVER
const PORT = process.env.PORT || 3000;
server.listen(PORT, () =>
    console.log(`Server running on ${PORT}`)
);
