package com.etsy.example;

import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryError;
import com.google.cloud.bigquery.Field;
import com.google.cloud.bigquery.InsertAllRequest;
import com.google.cloud.bigquery.InsertAllResponse;
import com.google.cloud.bigquery.LegacySQLTypeName;
import com.google.cloud.bigquery.Schema;
import com.google.cloud.bigquery.StandardTableDefinition;
import com.google.cloud.bigquery.Table;
import com.google.cloud.bigquery.TableId;
import com.google.cloud.bigquery.TableInfo;
import java.math.BigInteger;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

class StructuredLog {
  private static final String KUBERNETES_CLUSTER = System.getenv("KUBERNETES_CLUSTER");
  private static final String KUBERNETES_NAMESPACE = System.getenv("KUBERNETES_NAMESPACE");

  private enum LogFields {
    EPOCH_SECONDS(LegacySQLTypeName.INTEGER),
    MESSAGE(LegacySQLTypeName.STRING),
    LENGTH(LegacySQLTypeName.INTEGER);

    private LegacySQLTypeName legacySQLTypeName;

    LogFields(LegacySQLTypeName legacySQLTypeName) {
      this.legacySQLTypeName = legacySQLTypeName;
    }

    private Field toField() {
      return Field.of(name(), this.legacySQLTypeName);
    }

    static List<Field> fields() {
      return Arrays.stream(values()).map(LogFields::toField).collect(Collectors.toList());
    }
  }

  private final BigQuery bigquery;

  StructuredLog(BigQuery bigquery) {
    this.bigquery = bigquery;
  }

  void init() {
    maybeCreateStructuredLogTable();
  }

  private void maybeCreateStructuredLogTable() {
    String datasetName = getDatasetName();
    try {
      Table table = bigquery.getTable(datasetName, "logs");
      if (table == null) {
        System.out.println(
            String.format("The logs table %s does not exist. Creating it.", datasetName + ":logs"));
        table = bigquery.create(StructuredLog.getTableInfo(getDatasetName()));
        System.out.println("The new logs table is " + table);
      } else {
        System.out.println(
            String.format("The table %s already exists. NOT CREATING IT.", datasetName + ":logs"));
        BigInteger rows = table.getNumRows();
        System.out.println(
            String.format("Existing table %s has %s rows", datasetName + ":logs", rows.toString()));
      }
    } catch (Throwable t) {
      System.err.println(t.getMessage());
      t.printStackTrace();
    }
  }

  private static String getDatasetName() {
    return String.format("%s%sexample", KUBERNETES_CLUSTER, KUBERNETES_NAMESPACE)
        .replaceAll("[^0-9a-zA-Z]+", "");
  }

  private static TableId getTableId(String datasetName) {
    return TableId.of(datasetName, "logs");
  }

  private static TableInfo getTableInfo(String datasetName) {
    return TableInfo.of(
        getTableId(datasetName), StandardTableDefinition.of(Schema.of(LogFields.fields())));
  }

  private Map<String, Object> getLogRow(long epochSeconds, String message, int length) {
    Map<String, Object> rowContent = new HashMap<>();
    rowContent.put(LogFields.EPOCH_SECONDS.name(), epochSeconds);
    rowContent.put(LogFields.MESSAGE.name(), message);
    rowContent.put(LogFields.LENGTH.name(), length);
    return rowContent;
  }

  void sendStructuredLogToBigQuery(String message, int length) {
    InsertAllResponse response =
        bigquery.insertAll(
            InsertAllRequest.newBuilder(getTableId(getDatasetName()))
                .addRow(getLogRow(java.time.Instant.now().getEpochSecond(), message, length))
                .build());
    if (response.hasErrors()) {
      // If any of the insertions failed, this lets you inspect the errors
      for (Map.Entry<Long, List<BigQueryError>> entry : response.getInsertErrors().entrySet()) {
        // inspect row error
        System.err.println(entry);
      }
    }
  }
}
