// main template for openshift-upgrade-controller
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();

// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local factsNamespace = inv.parameters.steward.namespace;
local factsConfigLabel = std.get(inv.parameters.steward, 'additional_facts_config_label', '');

local lastVersionOverlay =
  local sorted = [ { from: k, spec: params.cluster_version.overlays[k].spec } for k in std.sort(std.objectFields(params.cluster_version.overlays)) ];
  sorted[std.length(sorted) - 1];

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
      [if factsConfigLabel != '' then factsConfigLabel]: '',
    },
    name: 'openshift-upgrade-controller-additional-facts',
    namespace: factsNamespace,
  },
  data: {
    facts: std.manifestJson({
      openshiftVersionOverlayFrom: std.get(lastVersionOverlay, 'from', ''),
      openshiftVersionOverlayChannel: std.get(std.get(lastVersionOverlay, 'spec', {}), 'channel', ''),
    }),
  },
}
