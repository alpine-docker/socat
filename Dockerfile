#FROM alpine:3.13.2
FROM alpine:3.13.0

ARG SOCAT_VERSION=1.7.4.2

RUN apk --no-cache add socat=${SOCAT_VERSION}

COPY artefacts/ /

ENTRYPOINT ["socat"]
