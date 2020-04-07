# docker build -t ebus .
FROM frolvlad/alpine-glibc
WORKDIR /app
COPY ./config.json .
COPY ./ebus-d .
CMD ["./ebus-d"]