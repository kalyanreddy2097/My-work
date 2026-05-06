# Service B Dockerfile
FROM node:18-alpine

WORKDIR /app

# Copy package.json first for better layer caching
COPY package.json .
RUN npm install --production

# Copy rest of the code
COPY . .

# Run as non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
USER appuser

CMD ["node", "worker.js"]
