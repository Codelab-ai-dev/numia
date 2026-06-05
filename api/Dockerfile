FROM golang:1.25-alpine AS builder
WORKDIR /app
COPY go.mod go.sum ./
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 go build -o /api ./cmd/api

FROM alpine:3.20
RUN apk add --no-cache ca-certificates tzdata
# migrate CLI from the official image (binary lives at /usr/local/bin/migrate)
COPY --from=migrate/migrate:v4.17.0 /usr/local/bin/migrate /usr/local/bin/migrate
COPY --from=builder /api /api
COPY internal/database/migrations /migrations
COPY docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh
EXPOSE 8080
ENTRYPOINT ["/docker-entrypoint.sh"]
