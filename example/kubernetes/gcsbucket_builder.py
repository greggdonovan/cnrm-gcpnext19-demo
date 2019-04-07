import lib.kubernetes.deployment_builder.deployment as d


def storage(ctx):
    return {
        'apiVersion': 'storage.cnrm.cloud.google.com/v1alpha1',
        'kind': 'StorageBucket',
        'metadata': {
            'name': 'cnrm-eap-%s-example' % ctx.namespace,
        },
        'spec': {
            'lifecycle': {
                'rules': [
                    {
                        'action':{
                            'type': 'Delete',
                        },
                        'condition': {
                            'age': 7,
                        }
                    },
                ],
            }
        },
    }


def main():
    ctx = d.parseArgs()
    d.writeDocsAsYaml(ctx, [storage(ctx)])


if __name__ == "__main__":
    main()
