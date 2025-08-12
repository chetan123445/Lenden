require('dotenv').config();
const express = require('express');
const app = express();
const mongoose = require('mongoose');
const cors = require('cors');
const cron = require('node-cron');
const { sendReminderEmail } = require('./utils/lendingborrowingotp');
const Transaction = require('./models/transaction');
const User = require('./models/user');
const http = require('http');
const socketio = require('socket.io');
const server = http.createServer(app);
const io = socketio(server, { cors: { origin: '*' } });
const ChatThread = require('./models/chatThread');
const GroupChatThread = require('./models/groupChatThread');
const leoProfanity = require('leo-profanity');

const apiRoutes = require('./routes/api');
const Admin = require('./models/admin');

const PORT = process.env.PORT || 5000;

// CORS Configuration
const corsOptions = {
  origin: [
    'https://lenden-backend-kf3c.onrender.com',
    'http://localhost:3000',
    'http://localhost:8080',
    'http://127.0.0.1:3000',
    'http://127.0.0.1:8080',
    // Add your Flutter app's domain if it has one
    // For mobile apps, you might want to allow all origins
    '*'
  ],
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
  allowedHeaders: [
    'Content-Type', 
    'Authorization', 
    'X-Requested-With',
    'Accept',
    'Origin'
  ],
  credentials: true,
  optionsSuccessStatus: 200 // Some legacy browsers (IE11, various SmartTVs) choke on 204
};

// Middleware
app.use(cors(corsOptions));
app.use(express.json());

// Add preflight handling for complex requests
app.options('*', cors(corsOptions));

// Debug middleware to log all requests
app.use((req, res, next) => {
  console.log(`🌐 ${req.method} ${req.path} - Origin: ${req.headers.origin || 'No origin'} - User-Agent: ${req.headers['user-agent']?.substring(0, 50) || 'No user-agent'}`);
  next();
});

// Routes
app.use('/api', apiRoutes(io));

// Root route handler
app.get('/', (req, res) => {
  res.json({
    message: 'Lenden Backend API is running!',
    version: '1.0.0',
    endpoints: {
      base: '/api',
      documentation: 'API endpoints are available under /api prefix'
    },
    cors: {
      enabled: true,
      origins: corsOptions.origin,
      methods: corsOptions.methods
    }
  });
});

// CORS test endpoint
app.get('/cors-test', (req, res) => {
  res.json({
    message: 'CORS is working!',
    timestamp: new Date().toISOString(),
    headers: req.headers,
    origin: req.headers.origin || 'No origin header'
  });
});

// Catch-all route for undefined paths
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Route not found',
    message: 'The requested endpoint does not exist',
    availableEndpoints: '/api',
    suggestion: 'Try accessing /api endpoints for available routes'
  });
});

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI, {
  useNewUrlParser: true,
  useUnifiedTopology: true,
})
.then(async () => {
  console.log('Database Established');
  await Admin.createDefaultAdmin();
  console.log('Default admin ensured');
})
.catch((err) => console.error('Batabase connection error:', err));

cron.schedule('0 8 * * *', async () => {
  try {
    const today = new Date();
    today.setHours(0,0,0,0);
    const tomorrow = new Date(today);
    tomorrow.setDate(today.getDate() + 1);
    // Find transactions due today or overdue and not cleared
    const dueTxns = await Transaction.find({
      expectedReturnDate: { $lte: tomorrow },
      cleared: false
    }).lean();
    for (const txn of dueTxns) {
      // Send to both lender and borrower
      const lender = await User.findById(txn.lender).lean();
      const borrower = await User.findById(txn.borrower).lean();
      const daysLeft = Math.ceil((new Date(txn.expectedReturnDate) - today) / (1000*60*60*24));
      if (lender && lender.email) {
        await sendReminderEmail(lender.email, {
          ...txn,
          counterpartyName: borrower?.name || borrower?.username || borrower?.email,
          counterpartyEmail: borrower?.email
        }, daysLeft);
      }
      if (borrower && borrower.email) {
        await sendReminderEmail(borrower.email, {
          ...txn,
          counterpartyName: lender?.name || lender?.username || lender?.email,
          counterpartyEmail: lender?.email
        }, daysLeft);
      }
    }
    console.log(`[CRON] Reminder emails sent for ${dueTxns.length} transactions.`);
  } catch (err) {
    console.error('[CRON] Error sending reminder emails:', err);
  }
});

io.on('connection', (socket) => {
  // Transaction chat
  socket.on('join', ({ transactionId }) => {
    socket.join(transactionId);
  });
  socket.on('chatMessage', async ({ transactionId, senderId, content, parentId, image, imageType, imageName }) => {
    if ((!content || leoProfanity.check(content)) && !image) return;
    let thread = await ChatThread.findOne({ transactionId });
    if (!thread) {
      thread = await ChatThread.create({ transactionId, messages: [] });
    }
    const message = {
      sender: senderId,
      content: content || '',
      parentId: parentId || null,
      image: image ? { data: image, type: imageType, name: imageName } : undefined
    };
    thread.messages.push(message);
    await thread.save();
    const populatedMsg = await ChatThread.populate(thread.messages[thread.messages.length - 1], { path: 'sender', select: 'name email' });
    io.to(transactionId).emit('chatMessage', populatedMsg);
  });

  // Group chat
  socket.on('joinGroup', ({ groupTransactionId }) => {
    socket.join(`group_${groupTransactionId}`);
  });
  socket.on('groupChatMessage', async ({ groupTransactionId, senderId, content, parentId }) => {
    if (!content || leoProfanity.check(content)) return;
    let thread = await GroupChatThread.findOne({ groupTransactionId });
    if (!thread) {
      thread = await GroupChatThread.create({ groupTransactionId, messages: [] });
    }
    const message = {
      sender: senderId,
      content: content || '',
      parentId: parentId || null,
    };
    thread.messages.push(message);
    await thread.save();
    const populatedMsg = await GroupChatThread.populate(thread.messages[thread.messages.length - 1], { path: 'sender', select: 'name email' });
    io.to(`group_${groupTransactionId}`).emit('groupChatMessage', populatedMsg);
  });
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
