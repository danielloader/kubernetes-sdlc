#!/bin/bash -eu

# Globals
TEMP_DIRECTORY=$(mktemp --tmpdir=/cache -d -t pcap.XXXXXXX)
MAXIMUM_PACKETS_PER_FILE=1000000

# Sensible defaults
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-"000000000000"}

SQS_QUEUE_NAME=${SQS_QUEUE_NAME:-$(grep -Eo '[^\/]+$' <<< $SQS_QUEUE_URL)}
DESTINATION_S3_BUCKET_NAME=${S3_BUCKET_NAME}
DESTINATION_S3_BUCKET_REGION=${S3_BUCKET_REGION}


# Custom endpoint check
if [ -z ${AWS_ENDPOINT_URL} ]; then
  AWS_ENDPOINT_URL=""
else
  # add flag prefix to string
  AWS_ENDPOINT_URL="--endpoint-url="${AWS_ENDPOINT_URL}
fi


function logger() {
  DATE=`date +'%Y-%m-%d %H:%M:%S'`
  echo "${DATE} ${1} : ${2}"
}

function get_sqs_message() {
  logger "INFO" "Get SQS message."
  aws ${AWS_ENDPOINT_URL} sqs receive-message --queue-url ${SQS_QUEUE_URL} > MESSAGE
}

function delete_sqs_message() {
  logger "INFO" "Delete SQS message."
  aws ${AWS_ENDPOINT_URL} sqs delete-message --queue-url ${SQS_QUEUE_URL} --receipt-handle ${1}
}

function get_object_from_s3() {
  logger "INFO" "execute: aws s3 cp s3://${1}/${2} ${TEMP_DIRECTORY}"
  aws ${AWS_ENDPOINT_URL} s3 cp s3://${1}/${2} ${TEMP_DIRECTORY} --no-progress 
}

function white_space_rename() {
  rename -f 's/\+/\ /g' ${1}
}

function process_pcap() {
    LOCAL_PATH=$(basename ${2})
    logger "INFO" "execute: editcap"
    editcap -c ${MAXIMUM_PACKETS_PER_FILE} "${TEMP_DIRECTORY}/${LOCAL_PATH}" "${TEMP_DIRECTORY}/${LOCAL_PATH%.*.*}_$(date +%s%N).pcap"
    logger "INFO" "execute: tshark"
    find ${TEMP_DIRECTORY}/* -iname '*.pcap' -type f -print0 | sort -z | xargs -0 -t -P`nproc` -I {} sh -c 'tshark -r "{}" -T ek | grep timestamp | gzip -3 > {}.jsonl.gz'
    logger "INFO" "execute: aws s3 mv"
    find ${TEMP_DIRECTORY}/* -iname '*.jsonl.gz' -type f -print0 | sort -z | xargs -0 -t -P1 -I {} aws ${AWS_ENDPOINT_URL} --region=${DESTINATION_S3_BUCKET_REGION} s3 mv "{}" "s3://${DESTINATION_S3_BUCKET_NAME}/json/" --no-progress
    rm -rf ${TEMP_DIRECTORY}/*
}

function teardown() {
  logger "INFO" "Teardown"
  delete_sqs_message ${1}
  rm MESSAGE
}

#
# Main event loop block
#
while :
do
  get_sqs_message
  
  if [ -s MESSAGE ];then
    logger "INFO" "Get Bucket name."
    BUCKET_NAME=`cat MESSAGE | jq -r '.Messages[].Body' | jq -r '.Records[].s3.bucket.name'`
    logger "INFO" "Get Object name."
    OBJECT_KEY_NAME=`cat MESSAGE | jq -r '.Messages[].Body' | jq -r '.Records[].s3.object.key'`
    logger "INFO" "Get Receipt handle."
    SQS_RECEIPT_HANDLE=`cat MESSAGE | jq -r '.Messages[].ReceiptHandle'`
  
    if [[ ! ${OBJECT_KEY_NAME} =~ .*/$ ]];then
      get_object_from_s3 ${BUCKET_NAME} ${OBJECT_KEY_NAME}
      if [ $? = "0" ];then
        process_pcap ${BUCKET_NAME} ${OBJECT_KEY_NAME}
        teardown ${SQS_RECEIPT_HANDLE}
      fi
    else
      teardown ${SQS_RECEIPT_HANDLE}
    fi
  else
    logger "INFO" "Message not received. Sleeping..."
    rm MESSAGE
  fi

  sleep 10
done

## Catch-all clean up of tempdir
rm -rf "${TEMP_DIRECTORY}"