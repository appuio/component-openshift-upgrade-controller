// main template for openshift-upgrade-controller
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

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
  function(name) kube._Object('managedupgrade.appuio.io/v1beta1', 'UpgradeConfig', name) {
    metadata+: {
      namespace: params.namespace,
    },
  },
);

local upgradeJobHooks = com.generateResources(
  params.upgrade_job_hooks,
  function(name) kube._Object('managedupgrade.appuio.io/v1beta1', 'UpgradeJobHook', name) {
    metadata+: {
      namespace: params.namespace,
    },
    spec+: {
      template+: {
        spec+: {
          template+: {
            spec+: {
              priorityClassName: 'system-cluster-critical',
            },
          },
        },
      },
    },
  },
);

local upgradeSuspensionWindows = com.generateResources(
  params.upgrade_suspension_windows,
  function(name) kube._Object('managedupgrade.appuio.io/v1beta1', 'UpgradeSuspensionWindow', name) {
    metadata+: {
      namespace: params.namespace,
    },
  },
);

{
  '10_prometheusrule': alerts('openshift-upgrade-controller', 'drain.alerts', params.alerts),
  '20_upgradeconfigs': upgradeConfigs,
  '22_upgradejobhooks': upgradeJobHooks,
  '24_upgradesuspensionwindows': upgradeSuspensionWindows,
  '90_upgrade_silence': import 'silence.libsonnet',
  '90_admin_ack': import 'admin-ack.libsonnet',
}
