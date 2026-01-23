local kube = import 'kube-ssa-compat.libsonnet';
local kap = import 'lib/kapitan.libjsonnet';

local api = import 'api.libsonnet';
local esp = import 'lib/espejote.libsonnet';

local inv = kap.inventory();
local params = inv.parameters.openshift_upgrade_controller;

local name = 'dynamic-pdb-alerts';
local sa = kube.ServiceAccount(name) {
  metadata+: {
    namespace: params.namespace,
  },
};

local role = kube.Role(name) {
  metadata+: {
    namespace: params.namespace,
  },
  rules: [
    {
      apiGroups: [ 'monitoring.coreos.com' ],
      resources: [ 'prometheusrules' ],
      verbs: [ 'get', 'list', 'watch', 'create', 'delete', 'patch' ],
    },
    {
      apiGroups: [ api.apiGroup ],
      resources: [ 'nodeforcedrains' ],
      verbs: [ 'get', 'list', 'watch' ],
    },
  ],
};

local rolebinding = kube.RoleBinding(name) {
  metadata+: {
    namespace: params.namespace,
  },
  subjects_: [ sa ],
  roleRef_: role,
};

local mr = esp.managedResource(name, params.namespace) {
  spec+: {
    serviceAccountRef: {
      name: sa.metadata.name,
    },
    context: [
      {
        name: 'prometheusrules',
        resource: {
          apiVersion: 'monitoring.coreos.com/v1',
          kind: 'PrometheusRule',
        },
      },
      {
        name: 'nodeforcedrains',
        resource: {
          apiVersion: api.apiVersion,
          kind: 'NodeForceDrain',
        },
      },
      {
        name: 'namespaces',
        resource: {
          apiVersion: 'v1',
          kind: 'Namespace',
        },
      },
    ],
    triggers: [
      {
        name: 'prometheusrule',
        watchContextResource: {
          name: 'prometheusrules',
        },
      },
      {
        name: 'nodeforcedrain',
        watchContextResource: {
          name: 'nodeforcedrains',
        },
      },
      {
        name: 'namespaces',
        watchContextResource: {
          name: 'namespaces',
        },
      },
    ],
    template: importstr 'espejote-templates/dynamic-pdb-alerts.jsonnet',
  },
};

if std.member(inv.applications, 'espejote') then
  {
    '40_pdb_alerts_managedresource': mr,
    '40_pdb_alerts_rbac': [
      sa,
      role,
      rolebinding,
    ],
  }
else
  std.trace(
    'Unable to deploy dynamic PDB alert: Espejote not present on target cluster',
    {}
  )
