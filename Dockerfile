FROM alpine

RUN apk --update add socat && \
    rm -rf /var/cache/apk/* && \
    rm -rf /root/.cache

ENTRYPOINT ["socat"]
