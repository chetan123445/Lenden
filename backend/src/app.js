require('dotenv').config();
const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');

const apiRoutes = require('./routes/api');
const Admin = require('./models/admin');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api', apiRoutes);

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

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
