FROM golang:1.22-bookworm AS build

ARG HTTP_PROXY="http://192.168.50.1:23456"
ARG HTTPS_PROXY="http://192.168.50.1:23456"
ARG NO_PROXY="localhost,127.0.0.1,::1"
ENV HTTP_PROXY=${HTTP_PROXY} \
    HTTPS_PROXY=${HTTPS_PROXY} \
    http_proxy=${HTTP_PROXY} \
    https_proxy=${HTTPS_PROXY} \
    NO_PROXY=${NO_PROXY} \
    no_proxy=${NO_PROXY} \
    GOPROXY=https://proxy.golang.org,direct

WORKDIR /src
COPY . .
RUN go mod tidy
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /out/ankiconnect-relay ./cmd/server

FROM debian:bookworm-slim
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=build /out/ankiconnect-relay /usr/local/bin/ankiconnect-relay
ENV LISTEN_ADDR=:8080 \
    ANKICONNECT_URL=http://127.0.0.1:8765 \
    ANKI_BASE=/anki-data \
    ANKI_PROGRAM_FILES_DIR=/home/anki/.local/share/AnkiProgramFiles
EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ankiconnect-relay"]
