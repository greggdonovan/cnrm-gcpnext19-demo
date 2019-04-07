import lib.kubernetes.deployment_builder.deployment as d


def namespace(ctx):
  (project, cluster) = d.extractProjectAndCluster(ctx.cluster)
  return {
    'apiVersion': 'v1',
    'kind': 'Namespace',
    'metadata': {
      'name': ctx.namespace,
      'annotations': {'cnrm.cloud.google.com/project-id': project},
    },
  }


def main():
  ctx = d.parseArgs()
  d.writeDocsAsYaml(ctx, [namespace(ctx)])


if __name__ == "__main__":
  main()
