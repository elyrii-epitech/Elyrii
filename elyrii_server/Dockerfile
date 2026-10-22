FROM oven/bun:1 AS dependencies
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile

FROM dependencies AS db-migrations
COPY drizzle.config.ts ./
COPY config/db ./config/db
COPY migrations ./migrations
COPY scripts/db-baseline.ts ./scripts/db-baseline.ts
COPY scripts/db-migrate.ts ./scripts/db-migrate.ts
CMD ["bun", "run", "db:migrate"]

FROM dependencies AS server
COPY . ./
RUN bun run build
CMD ["bun", "run", "start"]