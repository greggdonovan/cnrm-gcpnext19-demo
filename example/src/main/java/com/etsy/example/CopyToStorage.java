package com.etsy.example;

import com.google.cloud.storage.BlobId;
import com.google.cloud.storage.BlobInfo;
import com.google.cloud.storage.Bucket;
import com.google.cloud.storage.Storage;
import com.google.cloud.storage.StorageOptions;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.stream.Stream;

public class CopyToStorage {
  public static void main(String[] args) {
    if (args.length != 2) {
      System.err.println("Usage CopyToStorage <sourceDirectory> <destinationBucket>");
      System.exit(-1);
    }
    String sourceDirectory = args[0];
    String destinationBucket = args[1];

    System.out.println(
        String.format(
            "Copying all files from sourceDirectory=%s to destinationBucket=%s",
            sourceDirectory, destinationBucket));

    // Instantiates a client
    Storage storage = StorageOptions.getDefaultInstance().getService();

    // The name for the new bucket
    String bucketName = args[1];

    // Check if our bucket already exists
    try {
      Bucket bucket = storage.get(destinationBucket);
      if (bucket != null) {
        System.out.println("Found our bucket: " + bucket);
      } else {
        System.out.println("Bucket does not exist. Exiting.");
        System.exit(1);
      }
    } catch (Exception e){
      System.err.println("Error getting the bucket: " + e.getMessage());
      e.printStackTrace(System.err);
      System.exit(1);
    }

    try (Stream<Path> files = Files.walk(Paths.get(sourceDirectory))) {
      files
          .filter(Files::isRegularFile)
          .forEach(
              f -> {
                try {
                  BlobId blobId = BlobId.of(destinationBucket, f.getFileName().toString());
                  BlobInfo blobInfo = BlobInfo.newBuilder(blobId).build();
                  byte[] bytes = Files.readAllBytes(f);
                  storage.create(blobInfo, bytes);
                  System.out.println("copied file " + f.getFileName().toString());
                } catch (IOException io) {
                  System.err.println("io exception " + io.getMessage());
                  io.printStackTrace();
                  throw new RuntimeException(io);
                } finally{
                  f.toFile().deleteOnExit();
                }
              });

    } catch (IOException ioe) {
      ioe.printStackTrace();
      System.exit(1);
    }
  }
}
