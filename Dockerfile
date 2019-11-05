FROM alpine:edge

ARG VERSION=1.7.3.3-r1

RUN apk --no-cache add socat=${VERSION}

ENTRYPOINT ["socat"]
