# Pre-Requisites

- [Install Bazel 0.24.1](https://github.com/bazelbuild/bazel/releases/download/0.24.1/bazel-0.24.1-installer-linux-x86_64.sh)
E.g.:
```bash
wget https://github.com/bazelbuild/bazel/releases/download/0.24.1/bazel-0.24.1-installer-linux-x86_64.sh
chmod +x bazel-0.24.1-installer-linux-x86_64.sh
sudo ./bazel-0.24.1-installer-linux-x86_64.sh
```

- [Install gcloud](https://cloud.google.com/sdk/install)

- Authenticate to GCR

```bash
gcloud auth configure-docker
```

- Authenticate to the GKE cluster
E.g.:
```bash
gcloud container clusters get-credentials cnrm-eap
```

- Install CNRM

Consult the CNRM docs.

- Install kubeon, kubeoff, kubens

Install [kube-ps1](https://github.com/jonmosco/kube-ps1) to see kube context in your Bash PS1.
Install [kubectx](https://github.com/ahmetb/kubectx) to switch faster between clusters and namespaces in kubectl.


# Update the CRDs

```bash
curl -X GET -H "Authorization: Bearer $(gcloud auth print-access-token)" -sL -o ./install-bundle.tar.gz --location-trusted https://us-central1-cnrm-eap.cloudfunctions.net/download/bigquery-test/infra/install-bundle.tar.gz
tar -xzvf install-bundle.tar.gz
cd install-bundle/
kubectl apply -f .
```

# Add the gcp-gcs-writer-sa-key secret

This secret allows the `example` service to write to the GCS bucket and stream rows to BigQuery. 

First, grant this service account the following:
- BigQuery Admin
- BigQuery Data Owner
- BigQuery Data Viewer
- Storage Admin
- Storage Object Admin 

TODO: scope these permissions down.

Download the ServiceAccount JSON and use it to create a Secret. E.g.:

```bash
kubectl create secret generic gcp-gcs-writer-sa-key --from-file=key-content=/home/gdonovan/Downloads/cnrm-gcpnext19-demo-644d9415ae5d.json
```

# Deploy the service

To deploy the `example` service:

```bash
bazel run //example/kubernetes:k8s.gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap.cnrm-gcpnext19-demo.apply
```

# Get a shell in the `example` container image

```bash
bazel run //example/src/main/java/com/etsy/example:Example-With-YourKit && \
docker run -it bazel/example/src/main/java/com/etsy/example:Example-With-YourKit /bin/bash
```

# Get all relevant k8s objects

```bash
kubectl get storagebuckets,bigquerydatasets,deployments,services,secrets
```