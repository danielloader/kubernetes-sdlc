FROM debian:11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install tshark jq curl unzip -y
RUN if [ $(dpkg --print-architecture) = "amd64" ]; then \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip"; \
  else \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "/tmp/awscliv2.zip"; \
  fi

RUN unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf "/tmp/aws*"

ARG UID=1000
ARG GID=1000

RUN groupadd -g "${GID}" user \
  && useradd --create-home --no-log-init -u "${UID}" -g "${GID}" user
RUN mkdir /cache && chown -R ${UID}:${GID} /cache

USER user
WORKDIR /home/user/

COPY entrypoint.sh entrypoint.sh

CMD [ "./entrypoint.sh" ]