#!/bin/bash
#This script validates that consumer offsets are successfully synced over the cluster link from source to destination
#The Kafka CLI commands must be installed in a location set in your PATH to run kafka-consumer-groups

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --osk-bootstrap-server [osk-bootstrap-server-list]"
    echo "    --ccloud-bootstrap-server [ccloud-bootstrap-server-list]"
    echo "    --command-config [command-config-file]"

    return 0
}

if [[ $# -eq 0 ]];then
   echo "No input arguments provided."
   show_usage
   exit 1
fi

echo "============================================================================"
echo ""
echo "This script validates that consumer offsets are successfully synced over the cluster link from the source to destination"
echo ""

echo "============================================================================"
echo "=============================== PARAMETERS ================================="
echo ""

while [ ! -z "$1" ]
do
    if [[ "$1" == "--help" ]]
    then
        show_usage
        exit 0
    elif [[ "$1" == "--osk-bootstrap-server" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        OSK_BOOTSTRAP_SERVERS="$2"
        echo "OSK Bootstrap Servers are: ${OSK_BOOTSTRAP_SERVERS}"
        shift
    elif [[ "$1" == "--ccloud-bootstrap-server" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        CCLOUD_BOOTSTRAP_SERVERS="$2"
        echo "CCloud Bootstrap Servers are: ${CCLOUD_BOOTSTRAP_SERVERS}"
        shift
    elif [[ "$1" == "--command-config" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        CCLOUD_COMMAND_CONFIG="$2"
        echo "CCloud Command Config File path is: ${CCLOUD_COMMAND_CONFIG}"
    fi
    shift
done

CONSUMER_GROUPS=(${PWD}/`date +"%d-%m-%y-%T"`osk_consumer_groups.txt)
DIFF=(${PWD}/`date +"%d-%m-%y-%T"`_diff.txt)
OSK_GROUP_DATA=(${PWD}/osk_group_data.txt)
CCLOUD_GROUP_DATA=(${PWD}/ccloud_group_data.txt)
FORMATTED_OSK_GROUP_DATA=(${PWD}/frmt_osk_group_data.txt)
FORMATTED_CCLOUD_GROUP_DATA=(${PWD}/frmt_ccloud_group_data.txt)
SORTED_OSK_GROUP_DATA=(${PWD}/sort_osk_group_data.txt)
SORTED_CCLOUD_GROUP_DATA=(${PWD}/sort_ccloud_group_data.txt)

if [[ -z "$OSK_BOOTSTRAP_SERVERS"  ]] || [[ -z "$CCLOUD_BOOTSTRAP_SERVERS"  ]] || [[ -z "$CCLOUD_COMMAND_CONFIG"  ]]
then
    echo "--osk-bootstrap-server, --ccloud-bootstrap-server, and --command-config are required for execution."
    show_usage
    exit 1
fi

echo "============================================================================"
echo "=============================== OSK CONSUMERS =============================="
echo ""
echo "Gathering list of consumer groups from OSK cluster"
echo "Output written to" `date +"%d-%m-%y-%T"`"osk_consumer_groups.txt"
echo ""

kafka-consumer-groups --bootstrap-server ${OSK_BOOTSTRAP_SERVERS} --list > ${CONSUMER_GROUPS}

echo "============================================================================"
echo "=================================== DIFF ==================================="
echo ""
echo "Comparing consumer group data between the OSK and CCloud clusters to validate the syncing"
echo "Output written to" `date +"%d-%m-%y-%T"`"_diff.txt"
echo ""

cat ${CONSUMER_GROUPS} | while read -r group_name
do
    if [[ -z "${group_name}" ]]
    then
        :
    else
        # Describe the Consumer Groups in SRC and DEST
        kafka-consumer-groups --bootstrap-server ${OSK_BOOTSTRAP_SERVERS} --group ${group_name} --describe > ${OSK_GROUP_DATA}
        kafka-consumer-groups --bootstrap-server ${CCLOUD_BOOTSTRAP_SERVERS} --command-config ${CCLOUD_COMMAND_CONFIG} --group ${group_name} --describe > ${CCLOUD_GROUP_DATA}

        # Format the Consumer Group data to only include columns expected to match and remove unneeded consumer group data
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${OSK_GROUP_DATA} > ${FORMATTED_OSK_GROUP_DATA}
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${CCLOUD_GROUP_DATA} > ${FORMATTED_CCLOUD_GROUP_DATA}

        # If removing from the ${FORMATTED_CCLOUD_GROUP_DATA}, $5 if removing from the DIFF
        #awk '$4 == "-" { next } { print }' "<txt file>"

        # Sort the Consumer Group data by partition number for the diff command
        printf "=================== OSK ===================" > ${SORTED_OSK_GROUP_DATA}
        sort -t, -nk3 ${FORMATTED_OSK_GROUP_DATA} >> ${SORTED_OSK_GROUP_DATA}
        printf "=================== CCLOUD ===================" > ${SORTED_CCLOUD_GROUP_DATA}
        sort -t, -nk3 ${FORMATTED_CCLOUD_GROUP_DATA} >> ${SORTED_CCLOUD_GROUP_DATA}

        # Diff the two sorted files
        printf "=========================== Group Name: %s ============================\n" "${group_name}" >> ${DIFF}
        diff ${SORTED_OSK_GROUP_DATA} ${SORTED_CCLOUD_GROUP_DATA} >> ${DIFF}
        printf "\n" >> ${DIFF}
    fi
done

# Cleanup temp files
rm ${OSK_GROUP_DATA}
rm ${CCLOUD_GROUP_DATA}
rm ${FORMATTED_OSK_GROUP_DATA}
rm ${FORMATTED_CCLOUD_GROUP_DATA}
rm ${SORTED_OSK_GROUP_DATA}
rm ${SORTED_CCLOUD_GROUP_DATA}

echo ""