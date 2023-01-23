local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.ocp_drain_monitor;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('ocp-drain-monitor', params.namespace);

{
  'ocp-drain-monitor': app,
}
