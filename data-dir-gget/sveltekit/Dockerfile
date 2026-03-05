# Stage 1: Build the application
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package.json and package-lock.json
COPY package*.json ./

# Install dependencies (including devDependencies needed for build)
RUN npm ci

# Copy source code and config files
COPY ./src ./src
COPY tsconfig.json .

# Compile TypeScript to JavaScript
RUN npm run build

# Remove devDependencies after build
RUN npm prune --production

# Stage 2: Run the application
FROM node:20-alpine

WORKDIR /app

# Create a non-root user for better security
RUN adduser -D -u 1001 nodeuser

# Copy only necessary files from builder stage
COPY --from=builder --chown=nodeuser:nodeuser /app/dist ./dist
COPY --from=builder --chown=nodeuser:nodeuser /app/node_modules ./node_modules
COPY --chown=nodeuser:nodeuser package.json .

# Copy views and public directories
COPY --chown=nodeuser:nodeuser ./views ./views
COPY --chown=nodeuser:nodeuser ./public ./public

# Switch to non-root user
USER nodeuser

# Create log and metrics directories with appropriate permissions
# Temporarily switch back to root to create/chown directories
USER root
RUN mkdir -p /app/log_data/logs && chown -R nodeuser:nodeuser /app/log_data/logs && \
    mkdir -p /app/log_data/metrics && chown -R nodeuser:nodeuser /app/log_data
# Switch back to non-root user
USER nodeuser

# Expose the port the app will run on
ARG PORT
ENV PORT=${PORT:-8080}
EXPOSE ${PORT}

# Set environment variables
ENV NODE_ENV=production
ENV LOG_DIR=/app/log_data/logs
ENV METRICS_DIR=/app/log_data/metrics

# Start the application
CMD ["node", "dist/server.js"]