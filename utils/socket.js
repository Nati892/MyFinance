let io = null;

function init(httpServer) {
  const { Server } = require('socket.io');
  const config = global.cfg;

  io = new Server(httpServer, {
    cors: {
      origin: config.cors?.origin || '*',
      methods: ['GET', 'POST']
    }
  });

  io.on('connection', (socket) => {
    socket.on('join-household', (householdId) => {
      socket.join(`household:${householdId}`);
    });

    socket.on('leave-household', (householdId) => {
      socket.leave(`household:${householdId}`);
    });
  });

  return io;
}

function getIO() {
  return io;
}

module.exports = { init, getIO };
