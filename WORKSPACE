workspace(name = "com_etsy_cnrm")

load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "git_repository")

git_repository(
    name = "bazel_skylib",
    remote = "https://github.com/bazelbuild/bazel-skylib.git",
    tag = "0.7.0",
)

load("@bazel_skylib//lib:versions.bzl", "versions")

versions.check(minimum_bazel_version = "0.24.1")

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
        "com.google.cloud:google-cloud-bigquery:1.66.0",
    ],
    fetch_sources = True,
    repositories = [
        "https://jcenter.bintray.com/",
        "https://maven.google.com",
        "https://repo1.maven.org/maven2",
    ],
)

# begin atlassian/bazel-tools

atlassian_bazel_tools_version = "93876497830d172b4b9c314e15d01245a926dfcb"

http_archive(
    name = "com_github_atlassian_bazel_tools",
    strip_prefix = "bazel-tools-%s" % atlassian_bazel_tools_version,
    urls = ["https://github.com/atlassian/bazel-tools/archive/%s.tar.gz" % atlassian_bazel_tools_version],
)

load("@com_github_atlassian_bazel_tools//:multirun/deps.bzl", "multirun_dependencies")

multirun_dependencies()

# end atlassian/bazel-tools


# begin rules_python

git_repository(
    name = "io_bazel_rules_python",
    commit = "8b5d0683a7d878b28fffe464779c8a53659fc645",
    remote = "https://github.com/bazelbuild/rules_python.git",
)

load("@io_bazel_rules_python//python:pip.bzl", "pip_import", "pip_repositories")

pip_repositories()

# This rule translates the specified requirements.txt into
# @kubernetes_deps//:requirements.bzl, which itself exposes a pip_install method.
pip_import(
    name = "kubernetes_deps",
    requirements = "//lib/kubernetes:requirements.lock.txt",
)

# Load the pip_install symbol for kubernetes_deps, and create the dependencies'
# repositories.
load("@kubernetes_deps//:requirements.bzl", "pip_install")

pip_install()

# end rules_python