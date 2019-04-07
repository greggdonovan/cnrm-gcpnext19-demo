#!/usr/bin/env python

import os
import math
import json
import re
import yaml
import sys
from collections import namedtuple
from docopt import docopt

_GCP_SA_KEY_SECRET_LOCAL_VOLUME_FORMAT = '/search/.{secret_name}'
GCP_GKE_GCS_WRITER_SA_KEY_SECRET_NAME = 'gcp-gcs-writer-sa-key'
GCP_SA_KEY_SECRET_ITEM_KEY = 'key-content'
GCP_SA_KEY_SECRET_ITEM_PATH = 'key-content'

BOGUS_DOCKER_TAG = '0xC0DEA5CF'
IMAGE_PULL_SECRET = 'gcr-k8s-read-only'


# Allows the autoscaler to relocate this pod, even if it has local storage (see
# https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/FAQ.md#what-types-of-pods-can-prevent-ca-from-removing-a-node):
SAFE_TO_EVICT = 'cluster-autoscaler.kubernetes.io/safe-to-evict'


def merge(*dicts):
    """do not mutate, return new dict
    >>> a = { 'a': 1 }
    >>> b = { 'b': 1 }
    >>> merge(a, b)
    {'a': 1, 'b': 1}

    overwrites if key appears twice
    >>> also_a = { 'a': 2 }
    >>> merge(a, also_a)
    {'a': 2}

    >>> import pprint

    inner dicts are merged; pprint for output stability
    >>> pprint.pprint(merge(dict(a=dict(b='c', d='e'), f=['g']), dict(a=dict(b='h', i='j'), k='l'), dict(m='n')))
    {'a': {'b': 'h', 'd': 'e', 'i': 'j'}, 'f': ['g'], 'k': 'l', 'm': 'n'}
    """
    acc = {}
    for d in dicts:
        for k, v in d.iteritems():
            if k in acc and isinstance(acc[k], dict) and isinstance(v, dict):
                acc[k] = merge(acc[k], v)
            else:
                acc[k] = v
    return acc


# document parts
def buildDocument(kind, api_version, annot, metadata, **kwargs):
    doc = {
        'apiVersion': api_version,
        'kind': kind,
    }
    if annot or metadata:
        meta = {'metadata': merge(annot, metadata)}
        return merge(doc, meta, kwargs)
    else:
        return merge(doc, kwargs)


def extractProjectAndCluster(cluster):
    """
    :param : cluster name as it appears in context: gke_cnrm-gcpnext19-demo_us-central1-a_cnrm-eap
    :return: list of ["project_name", "cluster_name"]
    """
    return re.search("gke_(.+?)_.+_(.+)", cluster).group(1, 2)


# containers

def getGCPSecretMountPath(secret_name):
    '''returns the absolute path where the given secret is mounted inside a container.'''
    return _GCP_SA_KEY_SECRET_LOCAL_VOLUME_FORMAT.format(
        secret_name=secret_name)


def buildGCPSecretVolume(ctx, secret_name):
    return {
        'name': secret_name,
        'secret': {
            'secretName': secret_name,
            'items': [
                {
                    'key': GCP_SA_KEY_SECRET_ITEM_KEY,
                    'path': GCP_SA_KEY_SECRET_ITEM_PATH
                },
            ]
        }
    }


def mountGCPSecretVolume(secret_name):
    return mount(
        secret_name, getGCPSecretMountPath(secret_name), read_only=True)


def buildGCloudVolumes(ctx, gcs_read_only):
    if gcs_read_only:
        # GKE pods have RO access to GCS via the system service account, so no secret is needed.
        return []
    # But RW access requires a custom service account.
    return [
        buildGCPSecretVolume(ctx, GCP_GKE_GCS_WRITER_SA_KEY_SECRET_NAME)
    ]


def buildGCloudMounts(ctx, gcs_read_only):
    '''returns container volume mounts needed to run gcloud in a container; add buildGCloudEnv to the container too'''
    if gcs_read_only:
        return []
    return [mountGCPSecretVolume(GCP_GKE_GCS_WRITER_SA_KEY_SECRET_NAME)]


def buildGCloudEnv(ctx, gcs_read_only):
    '''return container environment vars needed to run gcloud in a container; add buildGCloudMounts to the container too'''
    vars = [
        var('CLOUDSDK_CONFIG', '/tmp/gcloud'),
        var('BOTO_CONFIG', '/tmp/gcloud/.boto')
    ]

    # GKE's internal secrets work fine with no added env, but need these credentials for write permissions
    if not gcs_read_only:
        vars.append(
            var(
                'GOOGLE_APPLICATION_CREDENTIALS',
                getGCPSecretMountPath(GCP_GKE_GCS_WRITER_SA_KEY_SECRET_NAME)
                + '/' + GCP_SA_KEY_SECRET_ITEM_PATH))

    return vars


# utils


def commonVars(ctx):
    return [
        var('KUBERNETES_CLUSTER', ctx.cluster),
        varRef('KUBERNETES_NAMESPACE', 'metadata.namespace'),
        varRef('KUBERNETES_POD_NAME', 'metadata.name'),
    ]


def varRef(name, path):
    """See https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#capabilities-of-the-downward-api
    for available paths.
    """
    return {'name': name, 'valueFrom': {'fieldRef': {'fieldPath': path}}}


def varResourceRef(name, container, resource):
    """Example: varResourceRef('CPU_LIMIT', 'my_container_name', 'limits.cpu')

    See https://kubernetes.io/docs/tasks/inject-data-application/downward-api-volume-expose-pod-information/#capabilities-of-the-downward-api
    for available resources.
    """
    return {
        'name': name,
        'valueFrom': {
            'resourceFieldRef': {
                'containerName': container,
                'resource': resource
            }
        }
    }


def var(name, value):
    """casts value input as a string; container specs expect environment
        variables to be strings; they are not correctly parsed otherwise
    """
    return {'name': name, 'value': str(value)}


def mount(name, path, read_only=False, sub_path=None):
    m = {
        'name': name,
        'mountPath': path,
        'readOnly': read_only,
    }
    if sub_path is not None:
        m['subPath'] = sub_path
    return m



def taggedImage(image_name):
    return '%s:%s' % (image_name, BOGUS_DOCKER_TAG)


def port(name, port, targetPort=None, protocol='TCP'):
    return {
        'name': name,
        'port': port,
        'targetPort': targetPort or port,
        'protocol': protocol
    }


def containerPort(name, port):
    return {'name': name, 'containerPort': port}


def writeDocsAsYaml(ctx, documents):
    # copy instead of reference
    yaml.Dumper.ignore_aliases = lambda *args: True
    stream = yaml.dump_all(documents, default_flow_style=False)

    with open(ctx.output, "w") as f:
        f.write(stream)


def writeDocAsYaml(doc):
    # copy instead of reference
    yaml.Dumper.ignore_aliases = lambda *args: True
    return yaml.dump(doc, default_flow_style=False)


class DeploymentBuilderContext(
        namedtuple('DeploymentBuilderContext', ['args'])):
    '''Holds metadata about the current Kubernetes context (namespace, cluster) etc being deployed, so spec objects can be generated appropriately.
    '''

    @property
    def namespace(self):
        return self.args['--namespace']

    @property
    def cluster(self):
        return self.args['--cluster']

    @property
    def output(self):
        return self.args.get('--output') or '/dev/stdout'

    @property
    def kubernetesVersion(self):
        kv = self.args['--kubernetes_version']
        assert re.match('^v\d+(\.\d+)+',
                        kv) is not None, 'version format incorrect: %s' % kv
        return kv

    def to_json(self):
        '''Serializes this object to JSON; inverse of `from_json`.'''
        return json.dumps(self.args)

    @classmethod
    def from_json(cls, j):
        '''Deserializes this object from JSON; inverse of `to_json`.'''
        return cls(json.loads(j))


COMMON_CONTEXT_ARGS = '[--output=OUTPUT] --namespace=NAMESPACE --cluster=CLUSTER --kubernetes_version=KUBERNETES_VERSION'


def parseArgs(custom_args=''):
    '''Parses the command-line arguments, looking for both any custom_args for this builder and the common args.  Returns a DeploymentBuilderContext with the arguments.'''
    arguments = docopt(
        'Usage: %s %s %s' % (sys.argv[0], COMMON_CONTEXT_ARGS, custom_args))
    return DeploymentBuilderContext(arguments)


if __name__ == "__main__":
    import doctest
    doctest.testmod()
