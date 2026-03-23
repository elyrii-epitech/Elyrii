FROM oven/bun:1

WORKDIR /app

COPY package*.json .

RUN bun install

COPY . .

EXPOSE 3001

ENTRYPOINT ["bun", "run", "start:prod"]
