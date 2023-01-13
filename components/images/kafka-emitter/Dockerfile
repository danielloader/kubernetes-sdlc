FROM debian:11
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update -y && apt-get install kafkacat -y

ARG UID=1000
ARG GID=1000

RUN groupadd -g "${GID}" user \
  && useradd --create-home --no-log-init -u "${UID}" -g "${GID}" user

USER user
WORKDIR /home/user/

COPY entrypoint.sh entrypoint.sh
COPY testfile.txt testfile.txt

ENTRYPOINT [ "./entrypoint.sh" ]