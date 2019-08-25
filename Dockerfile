FROM alpine:edge

ARG VERSION=1.7.3.2

RUN apk --no-cache add socat=${VERSION}

ENTRYPOINT ["socat"]
