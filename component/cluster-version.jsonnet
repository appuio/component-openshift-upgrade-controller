// main template for openshift-upgrade-controller
local kube = import 'kube-ssa-compat.libsonnet';
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local clusterVersion = kube._Object('managedupgrade.appuio.io/v1beta1', 'ClusterVersion', 'version') {
  metadata+: {
    namespace: params.namespace,
    labels+: {
      'app.kubernetes.io/managed-by': 'commodore',
    },
  },
  spec: {
    template: {
      spec: {
        channel: 'stable-%(Major)s.%(Minor)s' % params.cluster_version.openshiftVersion,
      } + com.makeMergeable(params.cluster_version.spec) + {
        // desiredUpdate is removed by the openshift-upgrade-controller, but this might help causing less confusion
        // if found in the compiled manifests.
        desiredUpdate:: null,
      },
    },
    local overlays = params.cluster_version.overlays,
    overlays: std.filterMap(
      function(k) overlays[k] != null && overlays[k].spec != null,
      function(k) {
        from: k,
        overlay: {
          spec: overlays[k].spec,
        },
      },
      std.objectFields(overlays)
    ),
  },
};

{
  version: clusterVersion,
}
