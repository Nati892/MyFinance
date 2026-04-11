# The Angular frontend is built automatically inside Docker during the image build.
# No manual pre-build needed — just run: docker-compose up --build

# Stage 1: Build Angular frontend
FROM node:22-alpine AS frontend-builder
WORKDIR /app/front_end
COPY front_end/package*.json ./
RUN npm install
COPY front_end/ ./
RUN npm run build -- --configuration production

# Stage 2: Backend
FROM node:22-alpine
WORKDIR /app

# Install backend dependencies (small, no native issues)
COPY package*.json ./
RUN npm install --omit=dev

# Copy backend source
COPY . .

# Copy built Angular dist from Stage 1
COPY --from=frontend-builder /app/front_end/dist/front_end/browser/. ./public/front/

ENV PORT=1234
ENV NODE_ENV=production

EXPOSE 1234

CMD ["node", "index.js"]
