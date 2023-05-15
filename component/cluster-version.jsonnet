// main template for openshift-upgrade-controller
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local cluster_gt_411 =
  params.cluster_version.openshiftVersion.Major == '4' &&
  std.parseInt(params.cluster_version.openshiftVersion.Minor) >= 11;

local clusterVersion = kube._Object('managedupgrade.appuio.io/v1beta1', 'ClusterVersion', 'version') {
  metadata+: {
    namespace: 'openshift-cluster-version',
    labels+: {
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
  spec: {
    [if cluster_gt_411 then 'capabilities']: {
      baselineCapabilitySet: 'v4.11',
    },
    channel: 'stable-%(Major)s.%(Minor)s' % params.cluster_version.openshiftVersion,
  } + com.makeMergeable(params.cluster_version.spec),
};

{
  version: clusterVersion,
}
