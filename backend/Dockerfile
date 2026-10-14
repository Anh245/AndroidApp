FROM node:24-alpine
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma
COPY prisma.config.ts ./
RUN DATABASE_URL=postgresql://expense:expense@localhost:5432/expense_db npm ci \
	&& npm prune --omit=dev --ignore-scripts
COPY --chown=node:node src ./src
COPY --chown=node:node scripts ./scripts
COPY --chown=node:node migrations ./migrations
USER node
EXPOSE 3000
CMD ["npm","start"]
