from kubernetes import config
from kubernetes.client.models.v1_object_meta import V1ObjectMeta
from kubernetes.client.models.v1_namespace import V1Namespace


def main():
    kube_client = config.new_client_from_config()
    metadata = V1ObjectMeta(name="cnrmdemo")
    namespace = V1Namespace(api_version="v1",
                            kind="Namespace",
                            metadata=metadata,
                            )
    print(kube_client.sanitize_for_serialization(namespace))


if __name__ == '__main__':
    main()
