# Built by presentation/deploy.sh from a staging folder, never from the repo
# root, so app/.env and everything else stays out of the image.
FROM node:22-slim
WORKDIR /srv
COPY app/ app/
COPY presentation/ presentation/
ENV NODE_ENV=production
USER node
CMD ["node", "presentation/proxy.js"]
