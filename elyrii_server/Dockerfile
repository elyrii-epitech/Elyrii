FROM oven/bun:1
WORKDIR /app
COPY package.json /app
RUN bun i
COPY . /app/
CMD [ "bun", "run", "prod" ]