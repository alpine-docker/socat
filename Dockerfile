FROM alpine

RUN apk --no-cache add socat libcap \
 && setcap 'cap_net_bind_service=+ep' /usr/bin/socat \
 && apk del libcap

ENTRYPOINT ["socat"]
