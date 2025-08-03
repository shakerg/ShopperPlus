FROM node:lts

# Set working directory
WORKDIR /app

# Copy package files
COPY --chown=1000:1000 package*.json ./

# Install dependencies
RUN npm ci --only=production && npm cache clean --force

# Copy application code
COPY --chown=1000:1000 src/ ./src/

# Create directories for logs and temp files
RUN mkdir -p /app/logs /app/temp

# Expose application port
EXPOSE 3000

USER 1000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 CMD curl -f -k http://localhost:3000/health || exit 1

# Start application
CMD ["npm", "start"]
