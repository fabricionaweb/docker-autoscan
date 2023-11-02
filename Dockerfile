# syntax=docker/dockerfile:1-labs
FROM public.ecr.aws/docker/library/alpine:3.18 AS base
ENV TZ=UTC
WORKDIR /src

# source stage =================================================================
FROM base AS source

# get and extract source from git
ARG VERSION
ADD https://github.com/Cloudbox/autoscan.git#v$VERSION ./

# build stage ==================================================================
FROM base AS build-app
ENV CGO_ENABLED=0

# dependencies
RUN apk add --no-cache go git

# build dependencies
COPY --from=source /src/go.mod /src/go.sum ./
RUN go mod download

# build app
COPY --from=source /src ./
ARG VERSION
ARG COMMIT=$VERSION
RUN mkdir /build && \
    go build \
        -ldflags "-s -w -X main.Version=$VERSION -X main.GitCommit=$COMMIT -X main.Timestamp=$(date -u '+%S')" \
        -o /build/ ./cmd/...

# runtime stage ================================================================
FROM base

ENV S6_VERBOSITY=0 S6_BEHAVIOUR_IF_STAGE2_FAILS=2 PUID=65534 PGID=65534
WORKDIR /config
VOLUME /config
EXPOSE 3030

# runtime dependencies
RUN apk add --no-cache tzdata s6-overlay logrotate curl

# copy files
COPY --from=build-app /build /app
COPY ./rootfs/. /

# run using s6-overlay
ENTRYPOINT ["/init"]
