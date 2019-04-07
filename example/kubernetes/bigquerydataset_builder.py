import lib.kubernetes.deployment_builder.deployment as d
import re


def to_valid_dataset_name(s):
    return re.sub('[^0-9a-zA-Z]+', '', s)


def bigquerydataset(ctx):
    (project, cluster) = d.extractProjectAndCluster(ctx.cluster)
    return {
        'apiVersion': 'bigquery.cnrm.cloud.google.com/v1alpha1',
        'kind': 'BigQueryDataset',
        'metadata': {
            'name': to_valid_dataset_name('%s%sexample' % (cluster, ctx.namespace)),
        },
        'spec': {
            'defaultTableExpirationMs': "3600000",
            'description': 'BigQuery Dataset Example %s' % ctx.cluster,
            'friendlyName': '%s-%s-example' % (cluster, ctx.namespace),
        },
    }


def main():
    ctx = d.parseArgs()
    d.writeDocsAsYaml(ctx, [bigquerydataset(ctx)])


if __name__ == "__main__":
    main()
