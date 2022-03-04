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
    fi
    shift
done

if [[ -z "$inputFile"  ]] || [[ -z "$linkId"  ]] || [[ -z "$clusterId"  ]] || [[ -z "$environmentId"  ]]
then
    echo "--input-file, --link-id, --cluster, and --environment are required for execution."
    show_usage
    exit 1
fi

describe_mirror_topic () {

	for index in "${!mirrorTopics[@]}";
	do
    echo "Mirror Topic: ${mirrorTopics[$index]}"
		echo "confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}"
		echo ""
		confluent kafka mirror describe ${mirrorTopics[$index]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}
		echo ""
	done
	return 0
}


while IFS= read -r line || [[ "$line" ]];
do
  mirrorTopics+=("$line")
done < ${inputFile}

#Describe takes in one topic at a time
echo ""
echo "============================================================================"
echo "=========== Displaying mirror topic current status pre-promotion ==========="
echo ""

describe_mirror_topic

#Promoting mirror topics
echo ""
echo "============================================================================"
echo "========================= Promoting mirror topics =========================="
echo ""
echo "confluent kafka mirror promote ${mirrorTopics[*]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}"
echo ""

confluent kafka mirror promote ${mirrorTopics[*]} --link ${linkId} --cluster ${clusterId}  --environment ${environmentId}

#Describe topics again after they've been promoted
echo ""
sleep 5
echo "Wait while the topics are promoted"
echo ""
echo "=========== Displaying mirror topic current status post-promotion =========="
echo ""

describe_mirror_topic
echo ""