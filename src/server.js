const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const path = require('path');

const app = express();
const server = http.createServer(app);
const io = new Server(server);

app.use(express.static(path.join(__dirname))); // serve Chat.html, login.html, logo.png, etc.

// Default route → login.html
app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, 'login.html'));
});

// store active users
let activeUsers = new Map();

io.on('connection', (socket) => {
  console.log('🛰️ A user connected');

  // When a new user joins
  socket.on('newUser', (username) => {
    activeUsers.set(socket.id, username);
    io.emit('updateUserList', Array.from(activeUsers.values()));
  });

  // When a chat message is sent
  socket.on('chatMessage', (msg) => {
    const user = activeUsers.get(socket.id);
    socket.broadcast.emit('chatMessage', { user, msg });
  });

  // Typing event (broadcast to others)
  socket.on('typing', (username) => {
    socket.broadcast.emit('typing', username);
  });

  // Stop typing event
  socket.on('stopTyping', (username) => {
    socket.broadcast.emit('stopTyping', username);
  });

  // When a user disconnects
  socket.on('disconnect', () => {
    activeUsers.delete(socket.id);
    io.emit('updateUserList', Array.from(activeUsers.values()));
    console.log('❌ A user disconnected');
  });
});

// Start server
const PORT = 3000;
server.listen(PORT, () => console.log(`🚀 WhereApp running at http://localhost:${PORT}`));
