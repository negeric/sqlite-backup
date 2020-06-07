FROM alpine:latest
RUN apk update \
    && apk add sqlite \
    && apk add socat \
    && apk add gzip \
    && apk add bash \
    && apk add gnupg \
    && apk add --update coreutils
RUN apk add --no-cache py-pip ca-certificates && pip install s3cmd
COPY entrypoint.sh /
RUN chmod +x entrypoint.sh
ENTRYPOINT ["./entrypoint.sh"]
