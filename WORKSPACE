workspace(name = "com_etsy_cnrm")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "bazel_skylib",
    remote = "https://github.com/bazelbuild/bazel-skylib.git",
    tag = "0.7.0",
)

load("@bazel_skylib//lib:versions.bzl", "versions")

versions.check(minimum_bazel_version = "0.24.0")

load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "io_bazel_rules_docker",
    branch = "master",
    remote = "https://github.com/bazelbuild/rules_docker.git",
)

load(
    "@io_bazel_rules_docker//repositories:repositories.bzl",
    container_repositories = "repositories",
)

container_repositories()

load(
    "@io_bazel_rules_docker//container:container.bzl",
    "container_pull",
)
load(
    "@io_bazel_rules_docker//java:image.bzl",
    _java_image_repos = "repositories",
)

_java_image_repos()

# This requires rules_docker to be fully instantiated before
# it is pulled in.
git_repository(
    name = "io_bazel_rules_k8s",
    branch = "master",
    remote = "https://github.com/bazelbuild/rules_k8s.git",
)

load("@io_bazel_rules_k8s//k8s:k8s.bzl", "k8s_defaults", "k8s_repositories")

k8s_repositories()

_CLUSTER = "gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap"

_CONTEXT = _CLUSTER

_NAMESPACE = "cnrm-gcpnext19-demo"

k8s_defaults(
    name = "k8s_object",
    cluster = _CLUSTER,
    context = _CONTEXT,
    image_chroot = "us.gcr.io/cnrm-gcpnext19-demo",
    namespace = _NAMESPACE,
)

k8s_defaults(
    name = "k8s_deploy",
    cluster = _CLUSTER,
    context = _CONTEXT,
    image_chroot = "us.gcr.io/cnrm-gcpnext19-demo",
    kind = "deployment",
    namespace = _NAMESPACE,
)

[k8s_defaults(
    name = "k8s_" + kind,
    cluster = _CLUSTER,
    context = _CONTEXT,
    kind = kind,
    namespace = _NAMESPACE,
) for kind in [
    "service",
]]

container_pull(
    name = "ubuntu_1810",
    digest = "sha256:4e5b56bb3b5eb670e45bb853fd0513aee02df2ed8d19f5ab2f2ebd3b4195bc99",
    registry = "index.docker.io",
    repository = "adoptopenjdk/openjdk8",
)

gcloud_vesion = "229.0.0"

gcloud_sha256 = "b1c87fc9451598a76cf66978dd8aa06482bfced639b56cf31559dc2c7f8b7b90"

http_archive(
    name = "cloud_sdk",
    build_file_content = "filegroup(name = \"cloud_sdk\", srcs = glob([\"**/*\"]), visibility = [\"//visibility:public\"], )",
    sha256 = gcloud_sha256,
    strip_prefix = "google-cloud-sdk",
    type = "tar.gz",
    url = "https://dl.google.com/dl/cloudsdk/channels/rapid/downloads/google-cloud-sdk-%s-linux-x86_64.tar.gz" % gcloud_vesion,
)

#gcloud debian
# Find the latest at https://packages.cloud.google.com/apt/dists/cloud-sdk/main/binary-amd64/Packages
http_file(
    name = "gcloud_deb",
    downloaded_file_path = "gcloud.deb",
    sha256 = "71ccb1aa12cb6d484347e94e5b17373d468b2981f83d764c1a63125b9c57a589",
    urls = [
        "https://packages.cloud.google.com/apt/pool/google-cloud-sdk_229.0.0-0_all_71ccb1aa12cb6d484347e94e5b17373d468b2981f83d764c1a63125b9c57a589.deb",
    ],
)

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")

RULES_JVM_EXTERNAL_TAG = "1.2"

RULES_JVM_EXTERNAL_SHA = "e5c68b87f750309a79f59c2b69ead5c3221ffa54ff9496306937bfa1c9c8c86b"

http_archive(
    name = "rules_jvm_external",
    sha256 = RULES_JVM_EXTERNAL_SHA,
    strip_prefix = "rules_jvm_external-%s" % RULES_JVM_EXTERNAL_TAG,
    url = "https://github.com/bazelbuild/rules_jvm_external/archive/%s.zip" % RULES_JVM_EXTERNAL_TAG,
)

load("@rules_jvm_external//:defs.bzl", "maven_install")

maven_install(
    artifacts = [
        "com.google.cloud:google-cloud-storage:1.66.0",
    ],
    fetch_sources = True,
    repositories = [
        "https://jcenter.bintray.com/",
        "https://maven.google.com",
        "https://repo1.maven.org/maven2",
    ],
)
