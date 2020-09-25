# docker build -t ebus .
FROM frolvlad/alpine-glibc
WORKDIR /app
COPY ./config.json.sample ./config.json
COPY ./ebus-d .
CMD ["./ebus-d"]