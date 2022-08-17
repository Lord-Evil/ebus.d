# docker build -t ebus .
FROM ubuntu
WORKDIR /app
COPY ./config.json.sample ./config.json
COPY ./ebus-d .
CMD ["./ebus-d"]