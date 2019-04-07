import lib.kubernetes.deployment_builder.deployment as d


def deployment(ctx):
    return {
        'apiVersion': 'apps/v1',
        'kind': 'Deployment',
        'metadata': {
            'name': 'example',
        },
        'spec': {
            'replicas': 1,
            'selector': {
                'matchLabels': dict(app='example'),
            },
            'template': {
                'metadata': {
                    'annotations': {
                        d.SAFE_TO_EVICT: 'true',
                    },
                    'labels': dict(app='example'),
                },
                'spec': {
                    'volumes': [
                        dict(name='search-log', emptyDir={}),
                        {
                            'name': 'gcp-gcs-writer-sa-key',
                            'secret': {
                                'defaultMode': 420,
                                'items': [
                                    dict(key='key-content', path='key-content'),
                                ],
                                'secretName': 'gcp-gcs-writer-sa-key',
                            },
                        },
                    ],
                    'containers': [
                        {
                            'name': 'example',
                            'image': d.taggedImage('example'),
                            'imagePullPolicy': 'IfNotPresent',
                            'env': [
                                d.var('CLOUDSDK_CONFIG', '/tmp/gcloud'),
                                d.var('BOTO_CONFIG', '/tmp/gcloud/.boto'),
                                d.var('GOOGLE_APPLICATION_CREDENTIALS', '/search/.gcp-gcs-writer-sa-key/key-content'),
                                d.var('KUBERNETES_CLUSTER', 'cnrm-eap'),
                                d.varRef('KUBERNETES_NAMESPACE', 'metadata.namespace'),
                                d.var('KUBERNETES_CONTAINER_NAME', 'example'),
                            ],
                            'command': [
                                '/search/dist/run.sh',
                            ],
                            'ports': [ dict(containerPort=8000)],
                            'volumeMounts': [
                                { 'name': 'search-log', 'mountPath': '/var/log/search'},
                                { 'name': 'gcp-gcs-writer-sa-key', 'mountPath': '/search/.gcp-gcs-writer-sa-key', 'readOnly': True},
                            ]
                        },
                    ],
                },
            },
        },
    }

def service(ctx):
    return {
        'apiVersion': 'v1',
        'kind': 'Service',
        'metadata': {
            'labels': dict(app='example'),
            'name': 'example-service',
        },
        'spec': {
            'ports': [
                dict(name='http', port=8000, protocol='TCP', targetPort=8000),
            ],
            'selector': dict(app='example'),
            'type': 'ClusterIP',
        },
    }


def main():
    ctx = d.parseArgs()
    d.writeDocsAsYaml(ctx, [deployment(ctx), service(ctx)])


if __name__ == "__main__":
    main()
