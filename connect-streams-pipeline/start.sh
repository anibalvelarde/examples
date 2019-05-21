#!/bin/bash

# Source library
. ../utils/helper.sh

check_env || exit 1
check_mvn || exit 1
check_running_cp 5.1 || exit 

./stop.sh

mvn clean compile

echo "auto.offset.reset=earliest" >> $CONFLUENT_HOME/etc/ksql/ksql-server.properties
confluent start

# Create the SQL table
TABLE_LOCATIONS=/usr/local/lib/table.locations
prep_sqltable_locations

# --------------------------------------------------------------

PACKAGE="consoleproducer"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 1: Kafka console producer -> Key:String and Value:String"
sleep 2

# Write the contents of the file TABLE_LOCATIONS to a Topic, where the id is the message key and the name and sale are the message value.
cat $TABLE_LOCATIONS | \
confluent produce $TOPIC \
--property parse.key=true \
--property key.separator='|' &>/dev/null

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--from-beginning \
--property print.key=true \
--max-messages 10

# Run the Java consumer application
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.StreamsIngest

# --------------------------------------------------------------

PACKAGE="jdbcjson"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 2: JDBC source connector with Single Message Transformations -> Key:Long and Value:JSON"
sleep 2

# Run source connector
confluent unload $PACKAGE &>/dev/null
confluent config $PACKAGE -d ./$PACKAGE-connector.properties &>/dev/null

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--from-beginning \
--property print.key=true \
--key-deserializer org.apache.kafka.common.serialization.LongDeserializer \
--max-messages 10

# Run the Java consumer application
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.StreamsIngest

# --------------------------------------------------------------

PACKAGE="jdbcspecificavro"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 3a: JDBC source connector with SpecificAvro -> Key:String(null) and Value:SpecificAvro"
sleep 2

# Run source connector
confluent unload $PACKAGE &>/dev/null
confluent config $PACKAGE -d ./$PACKAGE-connector.properties &>/dev/null

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--value-format avro \
--from-beginning \
--property print.key=true \
--max-messages 10

# Run the Java consumer application
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.StreamsIngest

# --------------------------------------------------------------

PACKAGE="jdbcgenericavro"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 3b: JDBC source connector with GenericAvro -> Key:String(null) and Value:GenericAvro"
sleep 2

# Run source connector
confluent unload $PACKAGE &>/dev/null
confluent config $PACKAGE -d ./$PACKAGE-connector.properties &>/dev/null

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--value-format avro \
--from-beginning \
--property print.key=true \
--max-messages 10

# Run the Java consumer application
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.StreamsIngest

# --------------------------------------------------------------

PACKAGE="javaproducer"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 4: Java client producer with SpecificAvro -> Key:Long and Value:SpecificAvro"
sleep 2

# Producer
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.Driver -Dexec.args="localhost:9092 http://localhost:8081 /usr/local/lib/table.locations"

curl -X GET http://localhost:8081/subjects/$TOPIC-value/versions/1

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--value-format avro \
--key-deserializer org.apache.kafka.common.serialization.LongDeserializer \
--from-beginning \
--property print.key=true \
--max-messages 10

# Consumer
timeout 10s mvn -q exec:java -Dexec.mainClass=io.confluent.examples.connectandstreams.$PACKAGE.StreamsIngest -Dexec.args="localhost:9092 http://localhost:8081"

# --------------------------------------------------------------

PACKAGE="jdbcavroksql"
TOPIC="$PACKAGE-locations"
echo -e "\n========== $PACKAGE: Example 5: JDBC source connector with Avro to KSQL -> Key:String(null) and Value:Avro"
sleep 2

# Run source connector
confluent unload $PACKAGE &>/dev/null
confluent config $PACKAGE -d ./$PACKAGE-connector.properties &>/dev/null

# Run the Consumer to print the key as well as the value from the Topic
confluent consume $TOPIC \
--value-format avro \
--from-beginning \
--property print.key=true \
--max-messages 10

# Create KSQL queries
ksql http://localhost:8088 <<EOF
run script '$PACKAGE.commands';
exit ;
EOF

# Read queries
timeout 5s ksql http://localhost:8088 <<EOF
SELECT * FROM JDBCAVROKSQLLOCATIONSWITHKEY LIMIT 10;
exit ;
EOF

timeout 5s ksql http://localhost:8088 <<EOF
SELECT * FROM COUNTLOCATIONS LIMIT 5;
exit ;
EOF

timeout 5s ksql http://localhost:8088 <<EOF
SELECT * FROM SUMLOCATIONS LIMIT 5;
exit ;
EOF
