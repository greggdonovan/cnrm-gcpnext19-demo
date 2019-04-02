package com.etsy.example;

import com.google.cloud.bigquery.BigQueryError;
import com.google.cloud.bigquery.InsertAllRequest;
import com.google.cloud.bigquery.InsertAllResponse;
import com.google.cloud.bigquery.TableId;
import java.io.IOException;
import java.net.InetSocketAddress;

import java.io.OutputStream;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryOptions;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Example {
  private static BigQuery bigquery = null;

  public static void main(String[] args) throws Exception {
    System.out.println("Starting Example server. About to listen on 8000");
    Thread exitAfterThirtySeconds =
        new Thread(
            () -> {
              try {
                Thread.sleep(30000);
                System.out.println("Exiting after 30 seconds.");
                System.exit(0);
              } catch (InterruptedException ie) {
              }
            });
    exitAfterThirtySeconds.start();

    bigquery = BigQueryOptions.getDefaultInstance().getService();
    sendStructuredLogToBigQuery("test message", 100);

    HttpServer server = HttpServer.create(new InetSocketAddress(8000), 0);
    server.createContext("/test", new MyHandler());
    server.setExecutor(null); // creates a default executor
    server.start();
  }

  private static void sendStructuredLogToBigQuery(String message, int length) {
    TableId tableId = TableId.of("cnrm-gcpnext19-demo", "examplebigquerydataset", "exampletablename");

    Map<String, Object> rowContent = new HashMap<>();
    rowContent.put("message", message);
    rowContent.put("length", length);

    InsertAllResponse response =
        bigquery.insertAll(
            InsertAllRequest.newBuilder(tableId)
                .addRow("rowId", rowContent)
                // More rows can be added in the same RPC by invoking .addRow() on the builder
                .build());
    if (response.hasErrors()) {
      // If any of the insertions failed, this lets you inspect the errors
      for (Map.Entry<Long, List<BigQueryError>> entry : response.getInsertErrors().entrySet()) {
        // inspect row error
        System.err.println(entry);
      }
      System.exit(1);
    }
  }

  static class MyHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange t) throws IOException {
      System.out.println("got an HTTP request");
      String response = "Hello CRNM";
      t.sendResponseHeaders(200, response.length());
      OutputStream os = t.getResponseBody();
      os.write(response.getBytes());
      os.close();
    }
  }
}
