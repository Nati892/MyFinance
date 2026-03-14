# Stage 1: Build the Angular app
FROM node:22-alpine as angular-build
WORKDIR /app/frontend

# Copy package.json and install dependencies
COPY ./front_end/package*.json ./
RUN npm install

# Copy Angular project files and build
COPY ./front_end/ ./
RUN npm run build -- --configuration production

# Stage 2: Build the Node.js backend
FROM node:22-alpine as node-build
WORKDIR /app

# Copy package.json and install dependencies
COPY package*.json ./
RUN npm install

# Stage 3: Create final image
FROM node:22-alpine
WORKDIR /app

# Copy node modules and backend source
COPY --from=node-build /app/node_modules ./node_modules
COPY . .

# Create dist/spa directory and copy Angular build output
RUN mkdir -p ./public/front

# FIXED: Added --from flag to copy from angular-build stage
COPY --from=angular-build /app/frontend/dist/front_end/browser/. ./public/front/

# Environment variables
ENV PORT=1234
ENV NODE_ENV=production

# Expose port
EXPOSE 1234

# Start the application
CMD ["node", "index.js"]