FROM node:24-alpine

RUN apk add --no-cache git bash coreutils python3 g++ make && \
    npm install -g @opencode/cli@latest

WORKDIR /workspace

ENTRYPOINT ["opencode"]
