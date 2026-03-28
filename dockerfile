# Angular is pre-built on the host before running docker-compose.
# Run: cd front_end && npm run build -- --configuration production
# Then: docker-compose up --build

FROM node:22-alpine
WORKDIR /app

# Install backend dependencies (small, no native issues)
COPY package*.json ./
RUN npm install --omit=dev

# Copy backend source
COPY . .

# Copy pre-built Angular dist from host
COPY ./front_end/dist/front_end/browser/. ./public/front/

ENV PORT=1234
ENV NODE_ENV=production

EXPOSE 1234

CMD ["node", "index.js"]
