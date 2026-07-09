// main template for openshift-upgrade-controller
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;
local hasEspejote = std.member(inv.applications, 'espejote');
local hasSteward = std.member(inv.applications, 'steward');

local api = import 'api.libsonnet';

local alertlabels = {
  syn: 'true',
  syn_component: 'openshift-upgrade-controller',
};

local alerts = function(name, groupName, alerts)
  com.namespaced(params.namespace, kube._Object('monitoring.coreos.com/v1', 'PrometheusRule', name) {
    spec+: {
      groups+: [
        {
          name: groupName,
          rules:
            std.sort(std.filterMap(
              function(field) alerts[field].enabled == true,
              function(field) alerts[field].rule {
                alert: field,
                labels+: alertlabels,
              },
              std.objectFields(alerts)
            ), function(x) x.alert),
        },
      ],
    },
  });

local upgradeConfigs = com.generateResources(
  params.upgrade_configs,
  function(name) kube._Object(api.apiVersion, 'UpgradeConfig', name) {
    metadata+: {
      namespace: params.namespace,
    },
  },
);

local upgradeJobHookSA = kube.ServiceAccount('hook-manager') {
  metadata+: {
    namespace: params.namespace,
  },
};

local upgradeJobHookCRB =
  kube.ClusterRoleBinding('openshift-upgrade-controller:hook-manager:cluster-admin')
  {
    roleRef: {
      apiGroup: 'rbac.authorization.k8s.io',
      kind: 'ClusterRole',
      name: 'cluster-admin',
    },
    subjects_: [ upgradeJobHookSA ],
  };

local upgradeJobHooks = com.generateResources(
  params.upgrade_job_hooks,
  function(name) kube._Object(api.apiVersion, 'UpgradeJobHook', name) + com.makeMergeable(params.upgrade_job_hook_defaults) {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      template+: {
        spec+: {
          template+: {
            spec+: {
              serviceAccountName: upgradeJobHookSA.metadata.name,
            },
          },
        },
      },
    },
  },
);

local upgradeSuspensionWindows = com.generateResources(
  params.upgrade_suspension_windows,
  function(name) kube._Object(api.apiVersion, 'UpgradeSuspensionWindow', name) {
    metadata+: {
      namespace: params.namespace,
    },
  },
);

local nodeForceDrains = com.generateResources(
  params.node_force_drains,
  function(name) kube._Object(api.apiVersion, 'NodeForceDrain', name) {
    metadata+: {
      namespace: params.namespace,
    },
  },
);

{
  '10_prometheusrule': alerts('openshift-upgrade-controller', 'drain.alerts', params.alerts),
  '15_upgradejobhook_rbac': [ upgradeJobHookSA, upgradeJobHookCRB ],
  '20_upgradeconfigs': upgradeConfigs,
  '22_upgradejobhooks': upgradeJobHooks,
  '24_upgradesuspensionwindows': upgradeSuspensionWindows,
  '26_nodeforcedrains': nodeForceDrains,
  '90_upgrade_silence': import 'silence.libsonnet',
  '90_admin_ack': import 'admin-ack.libsonnet',
  [if hasEspejote && hasSteward then '90_dynamic_facts']: import 'dynamic-facts.libsonnet',
}
