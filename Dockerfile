FROM alpine

RUN apk --no-cache add socat

ENTRYPOINT ["socat"]
