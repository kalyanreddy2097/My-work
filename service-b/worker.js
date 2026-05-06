const axios = require('axios');

const SERVICE_A_URL = process.env.SERVICE_A_URL || 'http://localhost:5000';
const INTERVAL_MS = 10000;
const STARTUP_DELAY_MS = 5000;

async function pollServiceA() {
  try {
    const response = await axios.get(`${SERVICE_A_URL}/data`, { timeout: 5000 });
    console.log(`[${new Date().toISOString()}] Got data from Service A:`, response.data);
  } catch (err) {
    console.error(`[${new Date().toISOString()}] Failed to reach Service A:`, err.message);
  }
}

// Graceful shutdown handler
process.on('SIGTERM', () => {
  console.log(`[${new Date().toISOString()}] Service B shutting down gracefully...`);
  process.exit(0);
});

process.on('SIGINT', () => {
  console.log(`[${new Date().toISOString()}] Service B interrupted, shutting down...`);
  process.exit(0);
});

console.log(`Service B starting. Polling Service A at ${SERVICE_A_URL} every ${INTERVAL_MS / 1000}s`);
console.log(`Waiting ${STARTUP_DELAY_MS / 1000}s before first poll...`);

// Wait before first poll to give service-a time to be ready
setTimeout(() => {
  pollServiceA();
  setInterval(pollServiceA, INTERVAL_MS);
}, STARTUP_DELAY_MS);
