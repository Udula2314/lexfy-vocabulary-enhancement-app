import express from 'express';
import cors from 'cors';
import { router as topicRoutes } from './src/routes/topicRoutes.js';
import { initializeWebSocketServer } from './src/config/websocket.js';

import { router as learningRoutes } from './src/routes/learning.routes.js';
import { router as wordRoutes } from './src/routes/word.routes.js';
import dotenv from 'dotenv';

dotenv.config();

const app = express();
const PORT = process.env.PORT || 5001;

// Middleware
app.use(cors());
app.use(express.json());

// Routes for Test & Lexfy Databases


// Route for Learning Module (YouTube Videos)
app.use('/api/learning', learningRoutes);

// Add the new word routes
app.use('/api/words', wordRoutes);

// Routes for Topics
app.use('/api/topics', topicRoutes);

const server = app.listen(PORT, () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  initializeWebSocketServer(server); // Initialize WebSocket server with HTTP server instance
});

console.log("🟢 WebSocket Server Started...");

//Testing CI/CD pipeline