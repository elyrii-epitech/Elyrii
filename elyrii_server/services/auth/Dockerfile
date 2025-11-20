FROM oven/bun:1

WORKDIR /app

COPY package*.json .

RUN bun install

COPY . .

EXPOSE 3001

RUN bun run db:generate

CMD ["sh", "-c", "bun run db:migrate && bun run start"]
