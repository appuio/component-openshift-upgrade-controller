// main template for openshift4-slos
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';

local slo = import 'slos.libsonnet';

local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local upstreamNamespace = 'openshift-upgrade-controller-system';

local removeUpstreamNamespace = kube.Namespace(upstreamNamespace) {
  metadata: {
    name: upstreamNamespace,
  } + com.makeMergeable(params.namespaceMetadata),
};

local setPriorityClass = {
  patch: |||
    - op: add
      path: "/spec/template/spec/priorityClassName"
      value: "system-cluster-critical"
  |||,
  target: {
    kind: 'Deployment',
    name: 'openshift-upgrade-controller-controller-manager',
  },
};

local patch = function(p) {
  patch: std.manifestJsonMinified(p),
};

com.Kustomization(
  'https://github.com/appuio/openshift-upgrade-controller//config/default',
  params.manifests_version,
  {
    'ghcr.io/appuio/openshift-upgrade-controller': {
      local image = params.images.openshift_upgrade_controller,
      newTag: image.tag,
      newName: '%(registry)s/%(image)s' % image,
    },
    'gcr.io/kubebuilder/kube-rbac-proxy': {
      local image = params.images.kube_rbac_proxy,
      newTag: image.tag,
      newName: '%(registry)s/%(image)s' % image,
    },
  },
  params.kustomize_input {
    patches+: [
      patch(removeUpstreamNamespace),
      setPriorityClass,
    ],
    labels+: [
      {
        pairs: {
          'app.kubernetes.io/managed-by': 'commodore',
        },
      },
    ],
  },
)
