---
layout: post
title: "Streaming Oracle CDC to Kafka with OGG for Big Data: A Configuration Guide"
excerpt: "Learn how to use Oracle GoldenGate for Big Data with an end-to-end configuration guide to stream real-time Change Data Capture (CDC) from Oracle databases into Kafka. This article details the architecture, key parameter configurations, and best practices."
date: 2025-07-31 09:05:00 +0800
categories: [Oracle GoldenGate, Big Data]
tags: [ogg, big data, kafka, cdc, data integration, json, handler]
author: Shane
image: /assets/images/posts/ogg-for-bigdata-kafka-banner.svg
---

In modern data architectures, the speed of data integration is critical for business agility. Traditional batch processing (T+1) is often insufficient for use cases like real-time analytics and event-driven microservices. A standard approach is to combine database Change Data Capture (CDC) with a real-time messaging platform like Kafka to build an efficient data pipeline.

For building real-time data streams from various databases like Oracle, DB2, and PostgreSQL to Kafka, Oracle GoldenGate (OGG) for Big Data is a widely-used and stable tool.

However, OGG for Big Data has a significant learning curve. Its configuration, especially the Replicat properties file, differs greatly from traditional OGG and contains many parameters, which can be challenging for new users.

This guide provides a clear, reproducible, end-to-end configuration process. It covers the key parameters for setting up a data pipeline from Oracle to Kafka using OGG for Big Data to explain its operational mechanics.

### 1. Architectural Overview: How OGG for Big Data Talks to Kafka

Before we get our hands dirty, we must first understand the workflow of this architecture. It has similarities to the traditional OGG architecture but is fundamentally different.

**Architecture Diagram:**
![OGG for Big Data to Kafka Architecture]({{ '/assets/images/ogg/ogg-bigdata-kafka-architecture.svg' | relative_url }})

1.  **Source (Oracle)**: Same as traditional OGG, we configure a primary Extract process (usually Integrated Extract) on the source to capture the database's Redo logs and generate local Trail Files.
2.  **Data Transfer**: We still strongly recommend using a Data Pump process to transfer the local Trail Files (`lt`) from the source to the remote Trail Files (`rt`) on the OGG for Big Data server. This ensures architectural decoupling and robustness.
3.  **Target (OGG for Big Data + Kafka)**: **This is where the core difference lies**. We no longer use a traditional Replicat process to directly apply SQL. Instead, we use a special **Big Data Replicat**. This Replicat does not connect to any target database but interacts with external systems by loading a "**Handler**." In our scenario, this handler is the **Kafka Handler**.
    *   **Big Data Replicat**: Its main responsibility is to read data records from the Trail File.
    *   **Kafka Handler**: It is responsible for taking the data records passed by the Replicat, converting them into Kafka messages in our specified format (e.g., JSON), and then sending them to the specified Topic via the standard Kafka Producer API.

Essentially, **the Kafka Handler acts as the connector between the OGG Replicat and the Kafka cluster**.

### 2. Hands-on Lab: End-to-End Configuration Steps (OGG 19c, Kafka 3.7.2)

Now, let's roll up our sleeves and get to work. Assume you have already configured the source Extract and Pump, and data is continuously being transferred to the `./dirdat/rt` directory on the OGG for Big Data server.

#### Step 1: Configure the Big Data Replicat Process

In the GGSCI of OGG for Big Data, we use the `ADD REPLICAT` command to add the target process.

```sh
-- Execute in the GGSCI of OGG for Big Data
ADD REPLICAT repkafka, EXTTRAIL ./dirdat/rt
```
*   `ADD REPLICAT repkafka`: We add a Replicat process named `repkafka`, which clearly defines its role.
*   `EXTTRAIL ./dirdat/rt`: Specifies that its data source is the remote Trail File transferred by the Pump.

#### Step 2: Create the Replicat Parameter File (`repkafka.prm`)

This file is very simple. It is mainly responsible for two things: specifying that this is a Big Data Replicat that calls a Java program, and defining the scope of the data to be processed.

```ini
-- file: ./dirprm/repkafka.prm
REPLICAT repkafka
-- Crucial! TARGETDB LIBFILE libggjava.so SET property=...
-- It tells OGG this is a Java application, with specific configuration in kafka.properties
TARGETDB LIBFILE libggjava.so SET property=dirprm/kafka.properties
-- Use the MAP statement to define the tables to be processed, this is a best practice
MAP source_schema.source_table, TARGET source_schema.source_table;
```
*   **Note**: In a Big Data context, the `TARGET` clause in the `MAP` statement is usually ignored because the real "target" (like a Kafka Topic) is defined in the `.properties` file. However, maintaining the full `MAP ... TARGET ...` structure is a good habit.

#### Step 3: Write the Kafka Handler Properties File (`kafka.properties`) - The Core of the Core

This file is the most critical part of the configuration. It defines how OGG connects to Kafka, formats data, and routes it to Topics. The following is a production-oriented configuration focused on low latency, with detailed explanations for key parameters.

```properties
# file: ./dirprm/kafka.properties

# A. Core Handler Configuration: Specify the use of the Kafka Handler
gg.handler.name=kafka
gg.handler.kafka.type=kafka

# B. Kafka Connection Configuration: Specify your Kafka cluster address
# This is one of the most important configurations and must be accurate
gg.handler.kafka.bootstrap.servers=kakfaserver:9092

# C. Message Formatting Configuration: Define the output message format to Kafka
# We use JSON format and include metadata like operation type and timestamp
gg.handler.kafka.format=json
# gg.handler.kafka.format.metaColumns=true
# gg.handler.kafka.format.insertOpKey=I
# gg.handler.kafka.format.updateOpKey=U
# gg.handler.kafka.format.deleteOpKey=D

# D. Topic Routing Configuration: Decide which Topic the data goes into
# This is a very flexible configuration. Here we use a template to automatically use the table name as the Topic name
gg.handler.kafka.topicMappingTemplate=${tableName}
# If you want to send all table changes to the same Topic, you can write:
# gg.handler.kafka.topicName=my_single_topic

# E. Advanced Kafka Producer Configuration (Production-grade config focusing on low latency)
# These parameters are passed directly to the underlying Kafka Producer
# acks=1: The producer gets an acknowledgment after the leader replica has written the message.
# This setting offers a good balance of throughput and low latency, but is slightly less reliable than acks=all.
gg.handler.kafka.producer.acks=1

# Specify the key and value serializers. For JSON format, the OGG Handler internally converts it to a byte array,
# so using ByteArraySerializer is correct.
gg.handler.kafka.producer.value.serializer=org.apache.kafka.common.serialization.ByteArraySerializer
gg.handler.kafka.producer.key.serializer=org.apache.kafka.common.serialization.ByteArraySerializer

# The amount of time to wait before attempting to reconnect to a failed Kafka host (in milliseconds).
gg.handler.kafka.producer.reconnect.backoff.ms=1000

# The batch size. Here it's set to 16KB, a balanced choice.
gg.handler.kafka.producer.batch.size=16384

# linger.ms=0: The producer will send messages immediately with no waiting.
# This minimizes latency and is suitable for scenarios with extremely high real-time requirements.
gg.handler.kafka.producer.linger.ms=0
```

#### Step 4: Start and Verify

Once everything is ready, start our Replicat process.

```sh
-- Execute in GGSCI
START repkafka
```

Now, log in to your Kafka server and use the command-line tool to consume the corresponding Topic. You should be able to see the JSON-formatted data change messages streaming in real-time from the Oracle database!

```sh
# Execute on the Kafka server
kafka-console-consumer.sh --bootstrap-server kakfaserver:9092 --topic source_table --from-beginning
```

The output message might look like this:
```json
{
  "table": "SOURCE_SCHEMA.SOURCE_TABLE",
  "op_type": "I",
  "op_ts": "2023-10-27 16:30:00.123456",
  "current_ts": "2023-10-27 16:30:02.789012",
  "pos": "00000000000000123456",
  "after": {
    "ID": 101,
    "NAME": "John Doe",
    "STATUS": "ACTIVE"
  }
}
```

### 3. Advanced Topics and Best Practices

*   **Data Format Selection**: JSON is highly readable but has redundancy; Avro offers high performance and built-in schema evolution, making it more suitable for large-scale production environments, but it requires Schema Registry support. Weigh the trade-offs based on your scenario.
*   **Error Handling**: The Kafka Handler also has a powerful error handling mechanism. You can configure it to either ABEND the process or log the error and continue when a message fails to send (e.g., due to a non-existent topic or insufficient permissions).
*   **Choice of Acks Parameter**: `acks=1` (as configured here) provides a good balance of low latency and high throughput. If your business scenario has extreme data reliability requirements and cannot tolerate the risk of losing a single message, you should choose `acks=all`, but this will sacrifice some latency.

### Conclusion

This guide has covered the end-to-end data integration process from Oracle to Kafka. OGG for Big Data's functionality is centered around its **Handler mechanism** and the associated **properties configuration file**.

Let's review the key components of this data pipeline:

*   **Source Capture**: The **Integrated Extract** process captures data changes from Oracle.
*   **Data Transfer**: The **Data Pump** process handles data transmission and architectural decoupling.
*   **Target Delivery**: The **Big Data Replicat** loads the **Kafka Handler** to format and send messages to Kafka.
*   **Core Logic**: The **`kafka.properties`** file contains all the configuration logic for the Kafka Handler.

Mastering this process enables you to stream real-time data from traditional databases into modern data platforms, which is a foundational skill for building real-time data services.