#!/bin/bash
#This script deletes all topics in a Confluent Cloud cluster
#Ensure the confluent CLI is installed and referenced in your PATH or set the CONFLUENT_HOME_BIN environment variable to the location of the binary

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --input-file [input-file]"
    echo "    --cluster [ccloud-cluster-id]"
    echo "    --environment [ccloud-environment-id]"
    echo "    --all-topics [use this flag to delete all topics]"
    return 0
}

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

echo "======================================================================"
echo ""
echo "This script accepts a list of topics to delete, or deletes all topics"
echo ""

while [ ! -z "$1" ]
do
    if [[ "$1" == "--help" ]]
    then
        show_usage
        exit 0
    elif [[ "$1" == "--input-file" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        inputFile="$2"
        shift
    elif [[ "$1" == "--cluster" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        clusterId="$2"
        echo "CCloud Kafka Cluster ID: ${clusterId}"
        shift
    elif [[ "$1" == "--environment" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        environmentId="$2"
        echo "CCloud Environment ID: ${environmentId}"
    elif [[ "$1" == "--all-topics" ]]
    then
        ALL_TOPICS_FLAG=true
        echo "Delete all topics: true"
    fi
    shift
done

if [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]] || [[ (! -z "$inputFile" || "$ALL_TOPICS_FLAG" != "true") ]]
then
    echo "--input-file or --all-topics, --cluster, and --environment are required for execution."
    show_usage
    exit 1
fi

TOPICS=(${PWD}/`date +"%d-%m-%y-%T"`_ccloud_deleted_topics.txt)

if [[ -z "$inputFile" ]]
then
    echo "====================================================================="
    echo "=============================== TOPICS =============================="
    echo ""
    echo "Gathering list of topics to delete"
    echo ""

    confluent kafka topic list --cluster ${clusterId} --environment ${environmentId} > ${TOPICS}

else
    echo "====================================================================="
    echo "=============================== TOPICS =============================="
    echo ""
    echo "Displaying list of target topics from the input file"
    echo ""

    cat "$inputFile"
    cat "$inputFile" > ${TOPICS}
fi

cat ${TOPICS} | while read -r topic_name
do
  if [[ -z "${topic_name}" ]]
  then
    :
  else
    # Delete topics
        echo "====================================================================="
        echo "======================== DELETING TOPICS ============================"
    confluent kafka topic delete ${topic_name} --cluster ${clusterId} --environment ${environmentId}
  fi
done
