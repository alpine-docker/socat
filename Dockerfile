FROM alpine

ARG VERSION=1.7.4.3-r0

RUN apk --no-cache add socat=${VERSION}

ENTRYPOINT ["socat"]
