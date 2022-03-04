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
