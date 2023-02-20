FROM alpine:edge

ARG VERSION=1.7.4.3-r0

RUN apk -U --no-cache upgrade \
    && apk --no-cache add socat=${VERSION}

ENTRYPOINT ["socat"]
