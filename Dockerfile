FROM alpine:latest

RUN apk -U --no-cache upgrade \
    && apk --no-cache add socat

ENTRYPOINT ["socat"]
