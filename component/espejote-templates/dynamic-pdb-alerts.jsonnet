local esp = import 'espejote.libsonnet';

local nodeforcedrains = esp.context().nodeforcedrains;

local nfd_ns_selectors = [
  std.get(nfd.spec, 'namespaceSelector', {})
  for nfd in nodeforcedrains
];

local syn_namespaces = [
  ns.metadata.name
  for ns in esp.context().namespaces
  if std.get(ns.metadata.labels, 'openshift.io/cluster-monitoring', 'false') == 'true'
];

local include_ns_sel = 'namespace=~"(%s)"' % std.join('|', syn_namespaces);

local makePdbRules(limitNamespaces) =
  local ns_sel = if limitNamespaces then
    include_ns_sel
  else
    '';
  {
    apiVersion: 'monitoring.coreos.com/v1',
    kind: 'PrometheusRule',
    metadata: {
      name: 'dynamic-pdb-alerts',
      annotations: {
        'espejote.io/ignore': 'openshift4-monitoring-rules',
      },
    },
    spec: {
      groups: [
        {
          name: 'pdb.alerts',
          rules: [
            {
              alert: 'PodDisruptionBudgetAtLimit',
              expr: |||
                max by (namespace, poddisruptionbudget) (
                  kube_poddisruptionbudget_status_current_healthy{%(ns_sel)s} == kube_poddisruptionbudget_status_desired_healthy{%(ns_sel)s}
                  and on (namespace, poddisruptionbudget)
                  kube_poddisruptionbudget_status_expected_pods{%(ns_sel)s} > 0
                )
              ||| % { ns_sel: ns_sel },
              labels: {
                syn: 'true',
                severity: 'critical',
              },
            },
            {
              alert: 'PodDisruptionBudgetLimit',
              expr: |||
                max by(namespace, poddisruptionbudget) (
                  kube_poddisruptionbudget_status_current_healthy{%(ns_sel)s} < kube_poddisruptionbudget_status_desired_healthy{%(ns_sel)s}
                )
              ||| % { ns_sel: ns_sel },
              labels: {
                syn: 'true',
                severity: 'warning',
              },
            },
          ],
        },
      ],
    },
  };

makePdbRules(std.length(nodeforcedrains) > 0)
