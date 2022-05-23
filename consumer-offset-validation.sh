#!/bin/bash
#This script validates that consumer offsets are successfully synced over the cluster link from source to destination
#The Kafka CLI commands must be installed in a location set in your PATH to run kafka-consumer-groups

show_usage () {
    echo "Usage: $0 [options [parameters]]"
    echo ""
    echo "Options:"
    echo "    --help -- Prints this page"
    echo "    --ccloud-bootstrap-server [ccloud-bootstrap-server-list]"
    echo "    --src-bootstrap-server [src-bootstrap-server-list]"
    echo "    --command-config-ccloud [ccloud-command-config-file]"
    echo "    --command-config-src [src-command-config-file]"
    echo "    --remove-unused-consumers [use this flag if there are a number of unused consumers on the source cluster]"
    echo "    --input-file [file containing a list of target consumer groups]"

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
    elif [[ "$1" == "--src-bootstrap-server" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        SRC_BOOTSTRAP_SERVERS="$2"
        echo "Source Cluster Bootstrap Servers are: ${SRC_BOOTSTRAP_SERVERS}"
        shift
    elif [[ "$1" == "--command-config-ccloud" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        COMMAND_CONFIG_CCLOUD="$2"
        echo "Destination Command Config File path is: ${COMMAND_CONFIG_CCLOUD}"
        shift
    elif [[ "$1" == "--command-config-src" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        COMMAND_CONFIG_SRC="$2"
        echo "Source Command Config File path is: ${COMMAND_CONFIG_SRC}"
        shift
    elif [[ "$1" == "--input-file" ]]
    then
        if [[ "$2" == --* ]] || [[ -z "$2" ]]
        then
            echo "No Value provided for "$1". Please ensure proper values are provided"
            show_usage
            exit 1
        fi
        INPUT_FILE="$2"
        echo "File with the list of target consumer groups: ${INPUT_FILE}"
    elif [[ "$1" == "--remove-unused-consumers" ]]
    then
        REMOVE_UNUSED_CONSUMERS=true
        echo "Filtering unused source consumer group data: true"
    fi
    shift
done

echo ""

if [[ -z "$CCLOUD_BOOTSTRAP_SERVERS"  ]] || [[ -z "$SRC_BOOTSTRAP_SERVERS"  ]] || [[ -z "$COMMAND_CONFIG_CCLOUD"  ]] || [[ -z "$COMMAND_CONFIG_SRC"  ]]
then
    echo "--ccloud-bootstrap-server, --src-bootstrap-server, --command-config-ccloud, and --command-config-src are required for execution."
    show_usage
    exit 1
fi

if [[ -n "$INPUT_FILE" ]]
then
    CONSUMER_GROUPS=(${PWD}/`date +"%d-%m-%y-%T"`_target_consumer_groups.txt)
    DIFF=(${PWD}/`date +"%d-%m-%y-%T"`_diff.txt)
    SRC_GROUP_DATA=(${PWD}/src_group_data.txt)
    CCLOUD_GROUP_DATA=(${PWD}/ccloud_group_data.txt)
    PARSED_SRC_GROUP_DATA=(${PWD}/parsed_src_group_data.txt)
    PARSED_CCLOUD_GROUP_DATA=(${PWD}/parsed_ccloud_group_data.txt)

    echo "============================================================================"
    echo "=============================== SRC CONSUMERS =============================="
    echo ""
    echo "Displaying list of target consumer groups from the input file:"
    echo ""
    cat "$INPUT_FILE"
    cat "$INPUT_FILE" > ${CONSUMER_GROUPS}

    echo ""
    echo "============================================================================"
    echo "=================================== DIFF ==================================="
    echo ""
    echo "Comparing consumer group data between the Source and CCloud clusters to validate the syncing"
    echo "Output written to" `date +"%d-%m-%y-%T"`"_diff.txt"
    echo ""

    if [[ "$REMOVE_UNUSED_CONSUMERS" = true ]]
    then
        echo "================================================"
        echo "||Removing inactive consumer group information||"
        echo "================================================"
        cat ${CONSUMER_GROUPS} | while read -r group_name
        do
            if [[ -z "${group_name}" ]]
            then
                :
            else
                # Describe the Consumer Groups in SRC and DEST
                kafka-consumer-groups --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_SRC} --group ${group_name} --describe > ${SRC_GROUP_DATA}
                kafka-consumer-groups --bootstrap-server ${CCLOUD_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_CCLOUD} --group ${group_name} --describe > ${CCLOUD_GROUP_DATA}

                # Parse the Consumer Group data to only include columns expected to match, remove unneeded consumer group data, remove the offset data for unused consumers that is not synced over the link, and sort the data on the partition number to prepare for the diff
                printf "======================= SRC =======================\n" > ${PARSED_SRC_GROUP_DATA}
                printf "======================= DEST =======================\n" > ${PARSED_CCLOUD_GROUP_DATA}
                awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '$col4 == "-" { next } {print $col1, $col2, $col3, $col4, $col6}' ${SRC_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_SRC_GROUP_DATA}
                awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '$col4 == "-" { next } {print $col1, $col2, $col3, $col4, $col6}' ${CCLOUD_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_CCLOUD_GROUP_DATA}

                # Diff the two sorted files
                printf "=========================== Group Name: %s ============================\n" "${group_name}" >> ${DIFF}
                diff ${PARSED_SRC_GROUP_DATA} ${PARSED_CCLOUD_GROUP_DATA} >> ${DIFF}
                printf "\n" >> ${DIFF}
            fi
        done
    else
        cat ${CONSUMER_GROUPS} | while read -r group_name
        do
            if [[ -z "${group_name}" ]]
            then
                :
            else
                # Describe the Consumer Groups in SRC and DEST
                kafka-consumer-groups --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_SRC} --group ${group_name} --describe > ${SRC_GROUP_DATA}
                kafka-consumer-groups --bootstrap-server ${CCLOUD_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_CCLOUD} --group ${group_name} --describe > ${CCLOUD_GROUP_DATA}

                # Parse the Consumer Group data to only include columns expected to match, remove unneeded consumer group data, and sort the data on the partition number to prepare for the diff
                printf "======================= SRC =======================\n" > ${PARSED_SRC_GROUP_DATA}
                printf "======================= DEST =======================\n" > ${PARSED_CCLOUD_GROUP_DATA}
                awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${SRC_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_SRC_GROUP_DATA}
                awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${CCLOUD_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_CCLOUD_GROUP_DATA}

                # Diff the two sorted files
                printf "=========================== Group Name: %s ============================\n" "${group_name}" >> ${DIFF}
                diff ${PARSED_SRC_GROUP_DATA} ${PARSED_CCLOUD_GROUP_DATA} >> ${DIFF}
                printf "\n" >> ${DIFF}
            fi
        done
    fi

    # Cleanup temp files
    rm ${CONSUMER_GROUPS}
    rm ${SRC_GROUP_DATA}
    rm ${CCLOUD_GROUP_DATA}
    rm ${PARSED_SRC_GROUP_DATA}
    rm ${PARSED_CCLOUD_GROUP_DATA}

else
    DIFF=(${PWD}/`date +"%d-%m-%y-%T"`_diff.txt)
    SRC_GROUP_DATA=(${PWD}/src_group_data.txt)
    CCLOUD_GROUP_DATA=(${PWD}/ccloud_group_data.txt)
    PARSED_SRC_GROUP_DATA=(${PWD}/parsed_src_group_data.txt)
    PARSED_CCLOUD_GROUP_DATA=(${PWD}/parsed_ccloud_group_data.txt)

    echo ""
    echo "============================================================================"
    echo "=================================== DIFF ==================================="
    echo ""
    echo "Comparing consumer group data between the Source and CCloud clusters to validate the syncing"
    echo "Output written to" `date +"%d-%m-%y-%T"`"_diff.txt"
    echo ""

    if [[ "$REMOVE_UNUSED_CONSUMERS" = true ]]
    then
        echo "================================================"
        echo "||Removing inactive consumer group information||"
        echo "================================================"

        # Describe the Consumer Groups in SRC and DEST
        kafka-consumer-groups --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_SRC} --all-groups --describe > ${SRC_GROUP_DATA}
        kafka-consumer-groups --bootstrap-server ${CCLOUD_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_CCLOUD} --all-groups --describe > ${CCLOUD_GROUP_DATA}

        # Parse the Consumer Group data to only include columns expected to match, remove unneeded consumer group data, remove the offset data for unused consumers that is not synced over the link, and sort the data on the partition number to prepare for the diff
        printf "======================= SRC =======================\n" > ${PARSED_SRC_GROUP_DATA}
        printf "======================= DEST =======================\n" > ${PARSED_CCLOUD_GROUP_DATA}
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '$col4 == "-" { next } {print $col1, $col2, $col3, $col4, $col6}' ${SRC_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_SRC_GROUP_DATA}
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '$col4 == "-" { next } {print $col1, $col2, $col3, $col4, $col6}' ${CCLOUD_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_CCLOUD_GROUP_DATA}

        # Diff the two sorted files
        diff ${PARSED_SRC_GROUP_DATA} ${PARSED_CCLOUD_GROUP_DATA} >> ${DIFF}
        printf "\n" >> ${DIFF}

    else

        # Describe the Consumer Groups in SRC and DEST
        kafka-consumer-groups --bootstrap-server ${SRC_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_SRC} --all-groups --describe > ${SRC_GROUP_DATA}
        kafka-consumer-groups --bootstrap-server ${CCLOUD_BOOTSTRAP_SERVERS} --command-config ${COMMAND_CONFIG_CCLOUD} --all-groups --describe > ${CCLOUD_GROUP_DATA}

        # Parse the Consumer Group data to only include columns expected to match, remove unneeded consumer group data, and sort the data on the partition number to prepare for the diff
        printf "======================= SRC =======================\n" > ${PARSED_SRC_GROUP_DATA}
        printf "======================= DEST =======================\n" > ${PARSED_CCLOUD_GROUP_DATA}
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${SRC_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_SRC_GROUP_DATA}
        awk -v col1=1 -v col2=2 -v col3=3 -v col4=4 -v col5=5 -v col6=6 '{print $col1, $col2, $col3, $col4, $col6}' ${CCLOUD_GROUP_DATA} | sort -t, -nk3 | column -t >> ${PARSED_CCLOUD_GROUP_DATA}

        # Diff the two sorted files
        diff ${PARSED_SRC_GROUP_DATA} ${PARSED_CCLOUD_GROUP_DATA} >> ${DIFF}
        printf "\n" >> ${DIFF}
    fi

    # Cleanup temp files
    rm ${SRC_GROUP_DATA}
    rm ${CCLOUD_GROUP_DATA}
    rm ${PARSED_SRC_GROUP_DATA}
    rm ${PARSED_CCLOUD_GROUP_DATA}
fi

echo ""