# ccloud-migration-scripts

Scripts to help automate the migration of applications to a new Confluent Cloud cluster using Cluster Linking

## Prerequisites

  1. Working cluster link between the source and destination cluster
  2. API keys created for the destination cluster (and the source cluster if migrating between Confluent Cloud clusters)
  3. Mirror topics created (either automatically with the cluster link configuration or manually)
  4. Kafka and Confluent CLI must be installed and referenced in your PATH

## Description

### consumer-offset-validation.sh

This script validates that consumer offsets are successfully synced over the cluster link from source to destination

A legend is printed with each consumer group to display which side of the diff is the source and which is the destination

Example execution:
    
    ./consumer-offset-validation-test.sh \
    --dest-bootstrap-server { DEST bootstrap URL } \
    --src-bootstrap-server { SRC bootstrap URL } \
    --command-config-dest { DEST properties } \
    --command-config-src { SRC properties }
    
Example properties files:

    bootstrap.servers={ bootstrap URL }
    ssl.endpoint.identification.algorithm=https
    security.protocol=SASL_SSL
    sasl.mechanism=PLAIN
    sasl.jaas.config=org.apache.kafka.common.security.plain.PlainLoginModule required username="{ username }" password="{ password }";
    
Example diff file output **without removing** unused consumers:

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
    
Example diff file output **removing** unused consumers (removing null offset data):

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
