#!/bin/bash
#This script can be used to validate that all topic partitions are being mirrored over the cluster link
#The Confluent CLI commands must be installed in a location set in your PATH to run confluent kafka mirror describe

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --input-file [input-file]"
    echo "    --link-id [link-name]"
    echo "    --cluster [ccloud-cluster-id]"
    echo "    --environment [ccloud-environment-id]"
    echo "    --all-active-mirror-topics [use this flag to describe all mirror topics]"

    return 0
}

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

echo "============================================================================"
echo ""
echo "This script accepts a list of mirror topics to promote and help validate successful promotion"
echo ""

MIRROR_TOPIC_STATUS_FILE=(${PWD}/`date +"%d-%m-%y-%T"`_mirror_topic_describe.txt)
mirrorTopics=()

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
    elif [[ "$1" == "--all-active-mirror-topics" ]]
    then
        activeMirrorTopicsFlag=true
        echo "Promoting all active mirror topics: true"
    fi
    shift
done

if [[ -z "$linkId"  ]] || [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]] || [[ (-z "$inputFile" && "$activeMirrorTopicsFlag" != "true") ]]
then
    echo "--input-file or --all-active-mirror-topics, --link-id, --cluster, and --environment are required for execution."
    show_usage
    exit 1
fi

describe_mirror_topic () {

    for index in "${!mirrorTopics[@]}";
	  do
        confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId} | tee --append ${MIRROR_TOPIC_STATUS_FILE}
	  done
	  return 0
}

if [[ ! -z "$inputFile"  ]]
then
    if [[ ! -s ${inputFile} ]]
    then
        echo "No topics to promote!"
        exit 1
    fi
    while IFS= read -r line || [[ "$line" ]];
    do
        mirrorTopics+=("$line")
    done < ${inputFile}

elif [[ "$activeMirrorTopicsFlag" = true ]]
then
    #retrieve mirror topic list
    echo "================================================================"
    echo ""
    echo "Retrieving list of mirror topics that are not in a Stopped state"

    confluent kafka mirror list --link ${linkId} --cluster ${clusterId}  --environment ${environmentId} > tmp-list-mirror.txt

    #query all the active mirrors
    awk -v topic=3 -v status=11  '{if ($status != "STOPPED" && $topic != "|" && $topic != "") {print $topic}}' tmp-list-mirror.txt > tmp-input.txt

    if [[ ! -s tmp-input.txt ]]
    then
        echo ""
        echo "No active mirror topics!"
        echo ""
        #clean up the temp files
        rm tmp-input.txt
        rm tmp-list-mirror.txt
        exit 1
    fi

    while IFS= read -r line || [[ "$line" ]];
    do
        mirrorTopics+=("$line")
    done < tmp-input.txt

    #clean up the temp files
    rm tmp-input.txt
    rm tmp-list-mirror.txt
else
    echo ""
    echo "No input file or all active mirror topics flags found"
    echo ""
    show_usage
    exit 1
fi

echo ""
echo "============================================================================"
echo "============== Describing mirror topics to validate mirroring =============="
echo ""

describe_mirror_topic

echo ""
echo "============================================================================"
echo "======== Parsing output file to validate all partitions are active ========="
echo ""

awk -F '|' -v topic=2 -v partition=3 -v mirror_lag=4 -v status=6 -v last_fetch_offset=8 'NR==1 {print "TOPIC","PARTITION","MIRROR_LAG","STATUS","LAST_FETCH_OFFSET"} {if ($status != "STOPPED" && $mirror_lag==$last_fetch_offset)  {print $topic, $partition, $mirror_lag, $status, $last_fetch_offset}}' ${MIRROR_TOPIC_STATUS_FILE} | column -t > `date +"%d-%m-%y-%T"`-input-mirror-state.txt
#cat tmp-input-mirror-state.txt
#rm tmp-input-mirror-state.txt

echo ""