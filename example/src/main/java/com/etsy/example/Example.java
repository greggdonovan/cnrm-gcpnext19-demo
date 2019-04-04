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
    System.out.println("Starting Example server.");

    try {
      bigquery = BigQueryOptions.getDefaultInstance().getService();
      sendStructuredLogToBigQuery("test message", 100);
    } catch (Exception e) {
      System.err.println("Error writing a test message to BigQuery" + e.getMessage());
      e.printStackTrace();
    }

    HttpServer server = HttpServer.create(new InetSocketAddress(8000), 0);
    Runtime.getRuntime().addShutdownHook(new Thread(() -> server.stop(0)));
    server.createContext("/hello", new HelloHandler());
    server.createContext("/goodbye", new GoodbyeHandler());
    server.setExecutor(null); // creates a default executor
    System.out.println("Listening on port 8000.");
    server.start();
  }

  private static void sendStructuredLogToBigQuery(String message, int length) {
    TableId tableId =
        TableId.of("cnrm-gcpnext19-demo", "examplebigquerydataset", "exampletablename");

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
    }
  }

  static class HelloHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange t) throws IOException {
      String response = "\nHello, GCP Next 2019!\n";
      t.sendResponseHeaders(200, response.length());
      OutputStream os = t.getResponseBody();
      os.write(response.getBytes());
      os.close();
    }
  }

  static class GoodbyeHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange httpExchange) throws IOException {
      try {
        String response =
            "\n\"Cowards die many times before their deaths; the valiant never taste death but once.\" \n -- Shakespeare\n";
        httpExchange.sendResponseHeaders(200, response.length());
        OutputStream os = httpExchange.getResponseBody();
        os.write(response.getBytes());
        os.close();
      } catch (Throwable t){
        t.printStackTrace(System.err);
      }
      System.out.println("Exiting example application.");
      System.exit(0);
    }
  }
}
