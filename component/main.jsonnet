// main template for ocp-drain-monitor
local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.ocp_drain_monitor;

local alertlabels = {
  syn: 'true',
  syn_component: 'ocp-drain-monitor',
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
            )),
        },
      ],
    },
  });

{
  '10_prometheusrule': alerts('ocp-drain-monitor', 'drain.alerts', params.alerts),
}
