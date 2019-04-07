load("@bazel_skylib//lib:unittest.bzl", "asserts", "unittest")
load("@com_github_atlassian_bazel_tools//:multirun/def.bzl", "command", "multirun")
load("//tools/build_rules:container_images.bzl", "k8s_container_bundle")
load("@io_bazel_rules_docker//contrib:push-all.bzl", "docker_push")

cluster = provider(
    doc = "Declares a Kubernetes cluster to receive deploys.",
    fields = {
        "name": "cluster name, matching KUBECONFIG",
        "kubernetes_version": "used to generate compatible YAML for a k8s api version",
        "image_chroot": "GCR registry URL to push images to",
        "user": "Kubernetes user, matching KUBECONFIG",
    },
)
app = provider(
    doc = "Declares an app that can be deployed to one or more contexts.",
    fields = {
        "name": "key for finding this app's contexts",
        "target": "executable binary that deploys the app (e.g. a `k8s_apps_for_contexts` target)",
    },
)
namespace = provider(
    doc = "Declares a namespace that can deploy apps to one or more clusters.",
    fields = {
        "name": "namespace name",
        "deploys": "list of `deploy` objects that will be deployed to this namespace",
    },
)
deploy = provider(
    doc = "Declares an application to be deployed to a namespace",
    fields = {
        "app": "`name` of an `app` entry",
        "clusters": "list of `cluster` names to deploy this app to",
        "constant_args": "dict of key-value pairs that will be available for generating YAML for this app in this namespace/clusters",
    },
)
context = provider(
    doc = "Represents a single deployable app in a cluster + namespace",
    fields = {
        "app": "app name",
        "constant_args": "dict of key-value pairs available for this context",
        "cluster": "cluster name",
        "user": "k8s user for the cluster",
        "namespace": "namespace name",
        "kubernetes_version": "the k8s version of this context's cluster",
        "image_chroot": "GCR registry URL for this context",
    },
)

def k8s_name_for_context(name, context):
    """Generates a unique name for the arguments, including the passed name and details about the
    context.  Designed for munging rules_k8s target labels to be unique per-context in a
    consistent, predictable way.  The munging preserves the '.apply' and other suffixes `rules_k8s`
    attaches, so this function can be used to generate context-aware labels as both inputs and
    outputs of `rules_k8s` macros.  See tests below for examples."""
    (prefix, dot, suffix) = name.partition(".")
    return "%s.%s.%s%s%s" % (prefix, context.cluster, context.namespace, dot, suffix)

def k8s_contexts_by_app(clusters, apps, namespaces):
    """Takes a set of clusters+apps+namespaces and returns a dict mapping each app name to the list
    of contexts it is applied into.  The contexts for that app are suitable for passing to
    contextual_k8s_object."""
    app_to_contexts = {app.name: [] for app in apps}
    for k8s_context in _build_k8s_contexts(clusters, apps, namespaces):
        app_to_contexts[k8s_context.app].append(k8s_context)
    return app_to_contexts

def _build_k8s_contexts(clusters, apps, namespaces):
    contexts = []
    apps_by_name = {app.name: app for app in apps}
    clusters_by_name = {cluster.name: cluster for cluster in clusters}
    for namespace in namespaces:
        for deploy in namespace.deploys:
            for cluster_name in deploy.clusters:
                if deploy.app not in apps_by_name:
                    fail("app '%s' not found in (%s)" % (deploy.app, namespace.name))
                if cluster_name not in clusters_by_name:
                    fail("cluster '%s' not found (in %s/%s)" % (cluster_name, namespace.name, deploy.app))
                cluster = clusters_by_name[cluster_name]
                constant_args = getattr(deploy, "constant_args", None) or {}
                contexts.append(context(
                    app = deploy.app,
                    constant_args = constant_args,
                    cluster = cluster.name,
                    user = cluster.user,
                    namespace = namespace.name,
                    kubernetes_version = cluster.kubernetes_version,
                    image_chroot = cluster.image_chroot,
                ))
    return contexts

def _string_to_file_impl(ctx):
    """Helper rule for dumping a string into a file."""
    ctx.actions.write(
        output = ctx.outputs.file,
        content = ctx.attr.content,
        is_executable = ctx.attr.is_executable,
    )

_string_to_file = rule(
    attrs = {
        "content": attr.string(mandatory = True),
        "file": attr.output(mandatory = True),
        "is_executable": attr.bool(default = False),
    },
    implementation = _string_to_file_impl,
)

