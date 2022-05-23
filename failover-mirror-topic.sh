#!/bin/bash
#Ensure the confluent CLI is installed and referenced in your PATH or set the CONFLUENT_HOME_BIN environment variable to the location of the binary
#Cluster link must be running and mirror topics must exist on the destination cluster

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --input-file [input-file]"
    echo "    --link-id [link-name]"
    echo "    --cluster [ccloud-cluster-id]"
    echo "    --environment [ccloud-environment-id]"
    echo "    --all-active-mirror-topics [use this flag to failover all remaining active mirror topics]"
    return 0
}

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

echo "============================================================================"
echo ""
echo "This script accepts a list of mirror topics to fail over or fails over all mirror topics, and helps validate successful fail over"
echo ""

MIRROR_TOPIC_STATUS_FILE=(${PWD}/`date +"%d-%m-%y-%T"`_mirror_topic_status.txt)
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
        shift
    elif [[ "$1" == "--all-active-mirror-topics" ]]
    then
        ACTIVE_MIRROR_TOPICS_FLAG=true
        echo "Failing over all active mirror topics: true"
    fi
    shift
done

if [[ -z "$linkId"  ]] || [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]] || [[ (! -z "$inputFile" || "$ACTIVE_MIRROR_TOPICS_FLAG" != "true") ]]
then
    echo ""
    echo "Invalid usage:"
    echo "--input-file or --all-active-mirror-topics, --link-id, --cluster, and --environment are required for execution."
    echo ""
    show_usage
    exit 1
fi

describe_mirror_topic () {

    for index in "${!mirrorTopics[@]}";
    do
        echo "Mirror Topic: ${mirrorTopics[$index]}"
		    echo "Command: confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}"
		    echo ""
		    confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}
		    echo ""
	  done
	  return 0
}

describe_mirror_topic_write () {

    for index in "${!mirrorTopics[@]}";
	  do
        confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId} >> ${MIRROR_TOPIC_STATUS_FILE}
	  done
	  return 0
}

#describe_mirror_topic_write_test () {
#	  #TEST BLOCK
#	  confluent kafka mirror describe test6 --link ${linkId} --cluster ${clusterId}  --environment ${environmentId} >> ${MIRROR_TOPIC_STATUS_FILE}
#	  #TEST BLOCK
#}

if [[ ! -z "$inputFile"  ]]
then
    if [[ ! -s ${inputFile} ]]
    then
        echo "No topics to failover!"
        exit 1
    fi
    while IFS= read -r line || [[ "$line" ]];
    do
        mirrorTopics+=("$line")
    done < ${inputFile}

##TEST BLOCK
#    confluent kafka mirror list > tmp-list-mirror.txt
#
#    #query all the active mirrors
#    awk -v topic=3 -v status=11  '{if ($status != "STOPPED" && $topic != "|" && $topic != "") {print $topic}}' tmp-list-mirror.txt > tmp-input.txt
##TEST BLOCK

elif [[ "$ACTIVE_MIRROR_TOPICS_FLAG" = true ]]
then
    #retrieve mirror topic list
    echo "================================================================"
    echo ""
    echo "Retrieving list of mirror topics that are not in a Stopped state"

    confluent kafka mirror list > tmp-list-mirror.txt

    #query all the active mirrors
    awk -v topic=3 -v status=11  '{if ($status != "STOPPED" && $topic != "|" && $topic != "") {print $topic}}' tmp-list-mirror.txt > tmp-input.txt

    if [[ ! -s tmp-input.txt ]]
    then
        echo ""
        echo "No topics to failover!"
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
    echo "No input file or active mirror topics flags found"
    echo ""
    show_usage
    exit 1
fi

#Describe takes in one topic at a time
echo ""
echo "============================================================================"
echo "=========== Displaying mirror topic current status pre-failover ==========="
echo ""

describe_mirror_topic

#Promoting mirror topics
echo ""
echo "============================================================================"
echo "========================= Failing over mirror topics =========================="
echo ""
echo "Command: confluent kafka mirror promote ${mirrorTopics[*]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}"
echo ""

confluent kafka mirror failover ${mirrorTopics[*]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}

#Describe topics again after they've been promoted
echo ""
sleep 15
echo "Wait while the topics are promoted"
echo ""
echo "=========== Displaying mirror topic current status post-failover =========="
echo ""

describe_mirror_topic
describe_mirror_topic_write
#describe_mirror_topic_write_test

echo "=========== Displaying target mirror topics still pending failover =========="
echo ""
awk -v topic=3 -v partition=5 -v status=11 'NR==1 {print "TOPIC","PARTITION","STATUS"} {if ($status != "STOPPED" && $topic != "|" && $topic != "")  {gsub(/"/,""); print $topic, $partition, $status}}' ${MIRROR_TOPIC_STATUS_FILE} | column -t > tmp-input-mirror-state.txt
cat tmp-input-mirror-state.txt
rm tmp-input-mirror-state.txt

echo ""
