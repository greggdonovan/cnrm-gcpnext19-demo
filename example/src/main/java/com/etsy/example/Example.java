package com.etsy.example;

import com.google.cloud.bigquery.BigQuery;
import com.google.cloud.bigquery.BigQueryOptions;
import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;
import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;

public class Example {
  private static StructuredLog structuredLog;

  public static void main(String[] args) throws Exception {
    System.out.println("Starting Example server.");

    try {
      BigQuery bigquery = BigQueryOptions.getDefaultInstance().getService();
      structuredLog = new StructuredLog(bigquery);
      structuredLog.init();
      structuredLog.sendStructuredLogToBigQuery("test message", 0);
    } catch (Exception e) {
      System.err.println("Error initializing BigQuery StructuredLog" + e.getMessage());
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


  static class HelloHandler implements HttpHandler {
    @Override
    public void handle(HttpExchange t) throws IOException {
      String response = "\nHello, GCP Next 2019!\n";
      t.sendResponseHeaders(200, response.length());
      OutputStream os = t.getResponseBody();
      os.write(response.getBytes());
      os.close();
      structuredLog.sendStructuredLogToBigQuery("/hello", response.length());
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
        structuredLog.sendStructuredLogToBigQuery("/goodbye", response.length());
      } catch (Throwable t) {
        t.printStackTrace(System.err);
      }
      System.out.println("Exiting example application.");
      System.exit(0);
    }
  }
}
