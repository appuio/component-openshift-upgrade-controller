local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local enabled =
  std.length(params.admin_ack.upgrade_job_selector) > 0;

local manifestName = 'admin-ack';

local namespace = {
  metadata+: {
    namespace: params.namespace,
  },
};

local sa = kube.ServiceAccount(manifestName) + namespace {
  automountServiceAccountToken: true,
};

local crb = kube.ClusterRoleBinding(manifestName) + namespace {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'cluster-admin',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: sa.metadata.name,
      namespace: sa.metadata.namespace,
    },
  ],
};

local cm = kube.ConfigMap(manifestName) + namespace {
  data: {
    adminack: importstr './scripts/admin-ack.sh',
  },
};

local ujh = kube._Object('managedupgrade.appuio.io/v1beta1', 'UpgradeJobHook', manifestName) + namespace {
  spec+: {
    selector: params.admin_ack.upgrade_job_selector,
    events: [
      'Create',
    ],
    template+: {
      spec+: {
        template+: {
          spec+: {
            restartPolicy: 'Never',
            priorityClassName: 'system-cluster-critical',
            serviceAccountName: sa.metadata.name,
            containers: [
              kube.Container('adminack') {
                image: params.images.oc.registry + '/' + params.images.oc.image + ':' + params.images.oc.tag,
                command: [ '/usr/local/bin/adminack' ],
                env_+: {
                  CM_NAMESPACE: params.admin_ack.config_map_ref.namespace,
                  CM_NAME: params.admin_ack.config_map_ref.name,
                  OVERRIDES_JSON: std.manifestJsonMinified(params.admin_ack.overrides),
                },
                volumeMounts_+: {
                  scripts: {
                    mountPath: '/usr/local/bin/adminack',
                    subPath: 'adminack',
                    readOnly: true,
                  },
                },
              },
            ],
            volumes: [
              {
                name: 'scripts',
                configMap: {
                  name: cm.metadata.name,
                  defaultMode: std.parseOctal('0550'),
                },
              },
            ],
          },
        },
      },
    },
  },
} + com.makeMergeable(params.admin_ack.additional_job_configuration);

if enabled then
  [ sa, crb, cm, ujh ]
else
  {}
