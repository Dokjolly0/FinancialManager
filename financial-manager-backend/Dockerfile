# syntax=docker/dockerfile:1

FROM golang:1.25-alpine AS build
WORKDIR /src

RUN apk add --no-cache git

COPY go.mod go.sum ./
RUN go mod download

COPY . .

ARG TARGET=api
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/app ./cmd/${TARGET}

FROM alpine:3.20 AS runtime
# tzdata is required for time.LoadLocation to resolve IANA zone names like
# "Europe/Rome" (plan.md section 18.1/18.7 reports, 4.5 user timezones) —
# Alpine doesn't ship it by default.
RUN apk add --no-cache ca-certificates wget tzdata \
    && addgroup -S app && adduser -S app -G app
WORKDIR /app

COPY --from=build /out/app /app/app
COPY --from=build /src/migrations /app/migrations

USER app:app

ENTRYPOINT ["/app/app"]
