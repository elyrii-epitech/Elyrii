FROM oven/bun:1

WORKDIR /app
COPY package.json /app
RUN bun install
COPY . /app
EXPOSE 3001

ENTRYPOINT ["bun", "run", "dev"]
