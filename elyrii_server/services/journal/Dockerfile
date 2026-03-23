FROM oven/bun:1

WORKDIR /app

COPY package.json bun.lock* /app/

RUN bun install

COPY . /app/

EXPOSE 3003

ENTRYPOINT ["sh", "-c", "bun run db:push && bun run start:prod"]