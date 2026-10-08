# Node 22: @google-cloud/modelarmor 0.8+ requires it.
FROM node:22-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm ci --omit=dev

COPY . .

EXPOSE 8080
CMD [ "npm", "start" ]
