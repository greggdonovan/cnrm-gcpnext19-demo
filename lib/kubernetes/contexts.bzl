load("//tools/build_rules:k8s_contexts.bzl", "app", "cluster", "deploy", "k8s_contexts_by_app", "k8s_name_for_context", "namespace")

# Declaration of what applications are deployed to each namespace in our clusters.

# Clusters: Kubernetes clusters that can be deployed to.
clusters = [
    # cnrm-eap GKE cluster, matching the kubeconfig entries created by gcloud
    cluster(
        name = "gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap",
        kubernetes_version = "v1.11.7",
        image_chroot = "us.gcr.io/cnrm-gcpnext19-demo",
        user = "gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap",
    ),
]

# Apps: targets that deploy Kubernetes objects.
apps = [
    app(
        name = "example",
        target = "//example/kubernetes:k8s.apply",
    ),
]

# Namespaces: declare which apps are declared to each cluster; the namespaces must already exist.
namespaces = [
    namespace(
        name = "cnrm-gcpnext19-demo",
        deploys = [
            deploy(
                app = "example",
                clusters = ["gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap"],
            ),
        ],
    ),
    namespace(
        name = "sonam-test",
        deploys = [
            deploy(
                app = "example",
                clusters = ["gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap"],
            ),
        ],
    ),
]

# Build the declarations above into a map of app name -> contexts for that app, which apps then use
# to generate Kubernetes objects.
k8s_contexts = k8s_contexts_by_app(clusters, apps, namespaces)
