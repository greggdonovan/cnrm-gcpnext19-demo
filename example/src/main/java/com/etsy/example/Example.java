package com.etsy.example;

import java.io.IOException;
import java.net.InetSocketAddress;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;

import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpHandler;
import com.sun.net.httpserver.HttpServer;

public class Example {

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
    HttpServer server = HttpServer.create(new InetSocketAddress(8000), 0);
    server.createContext("/test", new MyHandler());
    server.setExecutor(null); // creates a default executor
    server.start();
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
