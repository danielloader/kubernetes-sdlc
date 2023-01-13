#!/bin/bash -eu
 
# Globals

KAFKA_BROKER=${KAFKA_BROKER:-kafka:9092}
KAFKA_TOPIC=${KAFKA_TOPIC:-test}
LINE_COUNT=$(cat testfile.txt | wc -l)
RECORDS_PER_SECOND=${RECORDS_PER_SECOND:-1000}
VERBOSE=${VERBOSE:-false}

echo "STARTING"
echo "Emitting ${RECORDS_PER_SECOND} records/s to ${KAFKA_BROKER}/${KAFKA_TOPIC} using a ${LINE_COUNT} length source file"

function emit_lines() {
  while true
  do
    cat testfile.txt 
  done
}

if [ "${VERBOSE}" == "true" ]; then
  (emit_lines | stdbuf -eL pv --line-mode --rate-limit=${RECORDS_PER_SECOND} --bytes --rate --force --interval=1 --name="${KAFKA_BROKER}/${KAFKA_TOPIC} records" | stdbuf -eL pv --rate --bytes --force --name="Total Data" | kafkacat -P -b "${KAFKA_BROKER}" -t "${KAFKA_TOPIC}" ) 2>&1 | stdbuf -o0 tr '\r' '\n'
else
  emit_lines | pv --line-mode --rate-limit=${RECORDS_PER_SECOND} | kafkacat -P -b "${KAFKA_BROKER}" -t "${KAFKA_TOPIC}"
fi
