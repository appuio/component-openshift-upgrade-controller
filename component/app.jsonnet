local kap = import 'lib/kapitan.libjsonnet';
local inv = kap.inventory();
local params = inv.parameters.openshift_upgrade_controller;
local argocd = import 'lib/argocd.libjsonnet';

local app = argocd.App('openshift-upgrade-controller', params.namespace);

{
  'openshift-upgrade-controller': app,
}
