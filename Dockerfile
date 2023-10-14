FROM golang:1.20-buster

RUN apt-get update && apt-get install -y jq git && rm -rf /var/lib/apt/lists/*

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

WORKDIR /app

COPY . .

RUN chmod +x ./set_up.sh

CMD ["/bin/bash", "-c", "./set_up.sh"]
