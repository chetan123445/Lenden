# Lenden Backend

This is the backend for the Lenden app, built with Node.js, Express, and MongoDB.

## Setup

1. Install dependencies:
   ```
npm install
   ```
2. Create a `.env` file in the root of `backend/` with your MongoDB URI:
   ```
MONGODB_URI=your_mongodb_connection_string
   ```
3. Start the server:
   ```
npm run dev
   ```

## Folder Structure
- `src/app.js`: Main entry point
- `src/routes/`: API routes
- `src/controllers/`: Route logic
- `src/models/`: Mongoose models
