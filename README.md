# ccloud-migration-scripts

Scripts to help automate the migration of applications to a new Confluent Cloud cluster using Cluster Linking

## Prerequisites

  1. Working cluster link between the source and destination cluster
  2. API keys created for the destination cluster (and the source cluster if migrating between Confluent Cloud clusters)
  3. ACLs for both the source and destination cluster (if applicable)
     https://docs.confluent.io/cloud/current/multi-cloud/cluster-linking/security-cloud.html
  4. Mirror topics created (either automatically with the cluster link configuration or manually)
  5. Kafka and Confluent CLI must be installed and referenced in your $PATH

## Description

Typically, the scripts will be run in the following order as part of the migration:

  1. consumer-offset-validation.sh
  2. consumer-offset-filter.sh
  3. promote-mirror-topic.sh

### consumer-offset-validation.sh

This script validates that consumer offsets are successfully synced over the cluster link from source to destination

A legend is printed with each consumer group to display which side of the diff is the source and which is the destination

#### Example execution:
    
    ./consumer-offset-validation.sh \
    --dest-bootstrap-server { DEST bootstrap URL } \
    --src-bootstrap-server { SRC bootstrap URL } \
    --command-config-dest { DEST properties } \
    --command-config-src { SRC properties } \
    --remove-unused-consumers \
    --input-file { list of target consumers }
    
#### Example properties files:

    bootstrap.servers={ bootstrap URL }
    ssl.endpoint.identification.algorithm=https
    security.protocol=SASL_SSL
    sasl.mechanism=PLAIN
    sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="{ username }" password="{ password }";
    
#### Example diff file output **without removing** unused consumers:

    =========================== Group Name: example-v1 ============================
    1c1
    < =================== SRC ===================
    ---
    > =================== DEST ===================

    =========================== Group Name: example-v2 ============================
    1c1
    < =================== SRC ===================
    ---
    > =================== DEST ===================
    9,10d8
    < example-v2 example-topic2 14 - -
    < example-v2 example-topic2 15 - -

    =========================== Group Name: example-v3 ============================
    1c1
    < =================== OSK ===================
    ---
    > =================== CCLOUD ===================
    3,6c3,6
    < example-v3 example-topic3 0 77198 0
    < example-v3 example-topic3 1 37189 0
    < example-v3 example-topic3 2 83083 1
    < example-v3 example-topic3 3 107846 0
    ---
    > example-v3 example-topic3 0 77197 1
    > example-v3 example-topic3 1 37188 2
    > example-v3 example-topic3 2 83082 2
    > example-v3 example-topic3 3 107846 1
    8,9c8,9
    < example-v3 load.routes.v2 5 70157 0
    < example-v3 load.routes.v2 6 44621 0
    ---
    > example-v3 load.routes.v2 5 70156 1
    > example-v3 load.routes.v2 6 44620 1
    
#### Example diff file output **removing** unused consumers (removing null offset data):

    =========================== Group Name: example-v1 ============================
    1c1
    < =================== SRC ===================
    ---
    > =================== DEST ===================

    =========================== Group Name: example-v2 ============================
    1c1
    < =================== SRC ===================
    ---
    > =================== DEST ===================

    =========================== Group Name: example-v3 ============================
    1c1
    < =================== OSK ===================
    ---
    > =================== CCLOUD ===================
    3,6c3,6
    < example-v3 example-topic3 0 77198 0
    < example-v3 example-topic3 1 37189 0
    < example-v3 example-topic3 2 83083 1
    < example-v3 example-topic3 3 107846 0
    ---
    > example-v3 example-topic3 0 77197 1
    > example-v3 example-topic3 1 37188 2
    > example-v3 example-topic3 2 83082 2
    > example-v3 example-topic3 3 107846 1
    8,9c8,9
    < example-v3 load.routes.v2 5 70157 0
    < example-v3 load.routes.v2 6 44621 0
    ---
    > example-v3 load.routes.v2 5 70156 1
    > example-v3 load.routes.v2 6 44620 1
 
 ### consumer-offset-filter.sh
 
 This script accepts a list of consumer groups in an input file to exclude from the offset sync functionality of the cluster link
 
 A config file is output that is used to update the **consumer.offset.group.filters** and exclude target consumer groups
 
 #### Example execution:
 
    ./consumer-offset-filter.sh \
    --input-file { input file } \
    --link-id { link name } \
    --cluster { destination cluster ID } \
    --environment { environment ID }

 #### Example output:

    ============================================================================
    =============== Create New Configuration File for Link Update ==============

    consumer.offset.group.filters={"groupFilters":[ {"name": "*", "patternType": "LITERAL", "filterType": "INCLUDE"},{"name": "cg-test-app1", "patternType": "LITERAL", "filterType": "EXCLUDE"},{"name": "cg-test2-app1", "patternType": "LITERAL", "filterType": "EXCLUDE"},{"name": "cg-test2-app2", "patternType": "LITERAL", "filterType": "EXCLUDE"}]}

    ============================================================================
    ========== Update the Cluster Link Consumer Group Offset Syncing ===========

    Updated cluster link "test-link".

    ============================================================================
    ================= Validate the Updated Link Configuration ==================

               Config Name               |                 Config Value                 | Read Only | Sensitive |           Source            | Synonyms
    -----------------------------------------+----------------------------------------------+-----------+-----------+-----------------------------+-----------   
    ...
    consumer.offset.group.filters          | {"groupFilters":[ {"name":                   | false     | false     | DYNAMIC_CLUSTER_LINK_CONFIG | []
                                           | "*", "patternType":                          |           |           |                             |
                                           | "LITERAL", "filterType":                     |           |           |                             |
                                           | "INCLUDE"},{"name":                          |           |           |                             |
                                           | "cg-test-app1", "patternType":               |           |           |                             |
                                           | "LITERAL", "filterType":                     |           |           |                             |
                                           | "EXCLUDE"},{"name":                          |           |           |                             |
                                           | "cg-test2-app1",                             |           |           |                             |
                                           | "patternType":                               |           |           |                             |
                                           | "LITERAL", "filterType":                     |           |           |                             |
                                           | "EXCLUDE"},{"name":                          |           |           |                             |
                                           | "cg-test2-app2",                             |           |           |                             |
                                           | "patternType": "LITERAL",                    |           |           |                             |
                                           | "filterType": "EXCLUDE"}]}                   |           |           |                             |
    consumer.offset.sync.enable            | true                                         | false     | false     | DYNAMIC_CLUSTER_LINK_CONFIG | []
    
 ### promote-mirror-topic.sh
 
 This script accepts a list of mirror topics to promote and validates successful promotion
 
 #### Example execution:
    
    ./promote-mirror-topic.sh \
    --input-file { input file } \
    --link-id { link name } \
    --cluster { destination cluster ID } \
    --environment { environment ID }

 #### Example output:

    ============================================================================
    =========== Displaying mirror topic current status pre-promotion ===========

    Mirror Topic: test
    Command: confluent kafka mirror describe test --link test-link --cluster lkc-12rq15  --environment env-z8xj3

    Link Name | Mirror Topic Name | Partition | Partition Mirror Lag | Source Topic Name | Mirror Status | Status Time Ms | Last Source Fetch Offset
    ------------+-------------------+-----------+----------------------+-------------------+---------------+----------------+---------------------------
    test-link | test              |         1 |                    0 | test              | ACTIVE        |  1646336492686 |                        7
    test-link | test              |         0 |                    0 | test              | ACTIVE        |  1646336492686 |                        3
    test-link | test              |         3 |                    0 | test              | ACTIVE        |  1646336492686 |                        1
    test-link | test              |         2 |                    0 | test              | ACTIVE        |  1646336492686 |                        3
    test-link | test              |         5 |                    0 | test              | ACTIVE        |  1646336492686 |                        1
    test-link | test              |         4 |                    0 | test              | ACTIVE        |  1646336492686 |                        6

    Mirror Topic: test2
    Command: confluent kafka mirror describe test2 --link test-link --cluster lkc-12rq15  --environment env-z8xj3

    Link Name | Mirror Topic Name | Partition | Partition Mirror Lag | Source Topic Name | Mirror Status | Status Time Ms | Last Source Fetch Offset
    ------------+-------------------+-----------+----------------------+-------------------+---------------+----------------+---------------------------
    test-link | test2             |         1 |                    0 | test2             | ACTIVE        |  1646336492618 |                        9
    test-link | test2             |         0 |                    0 | test2             | ACTIVE        |  1646336492618 |                        2
    test-link | test2             |         3 |                    0 | test2             | ACTIVE        |  1646336492618 |                       16
    test-link | test2             |         2 |                    0 | test2             | ACTIVE        |  1646336492618 |                       11
    test-link | test2             |         5 |                    0 | test2             | ACTIVE        |  1646336492618 |                        5
    test-link | test2             |         4 |                    0 | test2             | ACTIVE        |  1646336492618 |                        5


    ============================================================================
    ========================= Promoting mirror topics ==========================

    Command: confluent kafka mirror promote test test2 --link test-link --cluster lkc-12rq15  --environment env-z8xj3

    Mirror Topic Name | Partition | Partition Mirror Lag | Error Message | Error Code | Last Source Fetch Offset
    --------------------+-----------+----------------------+---------------+------------+---------------------------
    test              |         1 |                    0 |               |            |                        7
    test              |         0 |                    0 |               |            |                        3
    test              |         3 |                    0 |               |            |                        1
    test              |         2 |                    0 |               |            |                        3
    test              |         5 |                    0 |               |            |                        1
    test              |         4 |                    0 |               |            |                        6
    test2             |         1 |                    0 |               |            |                        9
    test2             |         0 |                    0 |               |            |                        2
    test2             |         3 |                    0 |               |            |                       16
    test2             |         2 |                    0 |               |            |                       11
    test2             |         5 |                    0 |               |            |                        5
    test2             |         4 |                    0 |               |            |                        5

    Wait while the topics are promoted

    =========== Displaying mirror topic current status post-promotion ==========

    Mirror Topic: test
    Command: confluent kafka mirror describe test --link test-link --cluster lkc-12rq15  --environment env-z8xj3

    Link Name | Mirror Topic Name | Partition | Partition Mirror Lag | Source Topic Name | Mirror Status | Status Time Ms | Last Source Fetch Offset
    ------------+-------------------+-----------+----------------------+-------------------+---------------+----------------+---------------------------
    test-link | test              |         1 |                    0 | test              | STOPPED       |  1646430749830 |                        7
    test-link | test              |         0 |                    0 | test              | STOPPED       |  1646430749830 |                        3
    test-link | test              |         3 |                    0 | test              | STOPPED       |  1646430749830 |                        1
    test-link | test              |         2 |                    0 | test              | STOPPED       |  1646430749830 |                        3
    test-link | test              |         5 |                    0 | test              | STOPPED       |  1646430749830 |                        1
    test-link | test              |         4 |                    0 | test              | STOPPED       |  1646430749830 |                        6

    Mirror Topic: test2
    Command: confluent kafka mirror describe test2 --link test-link --cluster lkc-12rq15  --environment env-z8xj3

    Link Name | Mirror Topic Name | Partition | Partition Mirror Lag | Source Topic Name | Mirror Status | Status Time Ms | Last Source Fetch Offset
    ------------+-------------------+-----------+----------------------+-------------------+---------------+----------------+---------------------------
    test-link | test2             |         1 |                    0 | test2             | STOPPED       |  1646430749751 |                        9
    test-link | test2             |         0 |                    0 | test2             | STOPPED       |  1646430749751 |                        2
    test-link | test2             |         3 |                    0 | test2             | STOPPED       |  1646430749751 |                       16
    test-link | test2             |         2 |                    0 | test2             | STOPPED       |  1646430749751 |                       11
    test-link | test2             |         5 |                    0 | test2             | STOPPED       |  1646430749751 |                        5
    test-link | test2             |         4 |                    0 | test2             | STOPPED       |  1646430749751 |                        5

    =========== Displaying target mirror topics still pending promotion ==========

    TOPIC  PARTITION  STATUS
    
