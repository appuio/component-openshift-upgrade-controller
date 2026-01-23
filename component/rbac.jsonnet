local kube = import 'kube-ssa-compat.libsonnet';

local api = import 'api.libsonnet';

local aggregatedRoles = [
  kube.ClusterRole('syn:openshift-upgrade-controller:view') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
        'rbac.authorization.k8s.io/aggregate-to-view': 'true',
      },
    },
    rules: [
      {
        apiGroups: [ api.apiGroup ],
        resources: [
          'clusterversions',
          'upgradeconfigs',
          'upgradejobs',
          'upgradejobhooks',
        ],
        verbs: [
          'get',
          'list',
          'watch',
        ],
      },
    ],
  },
  kube.ClusterRole('syn:openshift-upgrade-controller:edit') {
    metadata+: {
      labels+: {
        'rbac.authorization.k8s.io/aggregate-to-admin': 'true',
        'rbac.authorization.k8s.io/aggregate-to-edit': 'true',
      },
    },
    rules: [
      {
        apiGroups: [ api.apiGroup ],
        resources: [
          'clusterversions',
          'upgradeconfigs',
          'upgradejobs',
          'upgradejobhooks',
        ],
        verbs: [
          'create',
          'delete',
          'deletecollection',
          'patch',
          'update',
        ],
      },
    ],
  },
];

{
  '30_rbac': aggregatedRoles,
}
