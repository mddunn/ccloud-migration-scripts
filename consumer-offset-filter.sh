#!/bin/bash
#Ensure the confluent CLI is installed and referenced in your PATH or set the CONFLUENT_HOME_BIN environment variable to the location of the binary
#Cluster link must be running

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --input-file [input-file]"
    echo "    --link-id [link-name]"
    echo "    --cluster [ccloud-cluster-id]"
    echo "    --environment [ccloud-environment-id]"

    return 0
}

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

echo "============================================================================"
echo ""
echo "This script accepts a list of consumer groups to exclude from the offset sync functionality of the cluster link"

command="consumer.offset.group.filters={\"groupFilters\":[ {\"name\": \"*\", \"patternType\": \"LITERAL\", \"filterType\": \"INCLUDE\"},"

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
    elif [[ "$1" == "--link-id" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        linkId="$2"
        echo "Cluster Link Name: ${linkId}"
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
    fi
    shift
done


if [[ -z "$inputFile"  ]] || [[ -z "$linkId"  ]] || [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]]
then
    echo "--input-file, --link-id, --cluster, and --environment are required for execution."
    show_usage
    exit 1
fi

while IFS= read -r line || [[ "$line" ]];
do 
   command="${command}{\"name\": \"$line\", \"patternType\": \"LITERAL\", \"filterType\": \"EXCLUDE\"},"
done < ${inputFile}

echo ""
echo "============================================================================"
echo "=============== Create New Configuration File for Link Update =============="
echo ""
command="${command%?}]}"
echo "${command}" > cluster-link-update-offset-sync.config

cat cluster-link-update-offset-sync.config

echo ""
echo "============================================================================"
echo "========== Update the Cluster Link Consumer Group Offset Syncing ==========="
echo ""

confluent kafka link update ${linkId} --config-file cluster-link-update-offset-sync.config --cluster ${clusterId} --environment ${environmentId}

echo ""
echo "============================================================================"
echo "================= Validate the Updated Link Configuration =================="
echo ""

confluent kafka link describe ${linkId} --cluster ${clusterId} --environment ${environmentId}

echo ""