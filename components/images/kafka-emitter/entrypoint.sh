#!/bin/bash -eu
 
# Globals

KAFKA_BROKER=${KAFKA_BROKER:-kafka:9092}
KAFKA_TOPIC=${KAFKA_TOPIC:-test}

function send_kafka_messages() {
  kafkacat -P -b "${KAFKA_BROKER}" -t "${KAFKA_TOPIC}" << testfile.txt
}


while :
do
  send_kafka_messages
done
