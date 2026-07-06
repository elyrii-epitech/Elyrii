FROM oven/bun:1
WORKDIR /app
COPY package.json /app
RUN bun i
COPY . /app/
RUN bun run build
CMD [ "bun", "run", "prod" ]