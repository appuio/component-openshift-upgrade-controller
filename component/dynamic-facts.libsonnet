// main template for openshift-upgrade-controller
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local factsNamespace = inv.parameters.steward.namespace;
local factsConfigLabel = inv.parameters.steward.additional_facts_config_label;

local versionOverlay =
  local sorted = std.sort(params.cluster_version.overlays, function(i) i.from);
  local last = sorted[std.length(sorted) - 1];
  {
    from: std.get(last, 'from', ''),
    channel: std.get(std.get(std.get(last, 'overlay', {}), 'spec', {}), 'channel', ''),
  };

{
  apiVersion: 'v1',
  kind: 'ConfigMap',
  metadata: {
    annotations: {
      'syn.tools/source': 'https://github.com/appuio/component-openshoft-upgrade-controller.git',
    },
    labels: {
      'app.kubernetes.io/managed-by': 'commodore',
      'app.kubernetes.io/part-of': 'syn',
      'app.kubernetes.io/component': 'openshift-upgrade-controller',
      [factsConfigLabel]: '',
    },
    name: 'openshift-upgrade-controller-additional-facts',
    namespace: factsNamespace,
  },
  data: {
    facts: std.manifestJson({
      version_overlay: {
        from: params.cluster_version.openshiftVersion,
        channel: params.upgrade_configs,
      },
    }),
  },
}
