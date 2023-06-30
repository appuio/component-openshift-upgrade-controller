local com = import 'lib/commodore.libjsonnet';
local kap = import 'lib/kapitan.libjsonnet';
local kube = import 'lib/kube.libjsonnet';
local inv = kap.inventory();
// The hiera parameters for the component
local params = inv.parameters.openshift_upgrade_controller;

local enabled =
  std.length(params.upgrade_silence.upgrade_job_selector) > 0 &&
  std.length(params.upgrade_silence.alert_matchers) > 0;


local namespace = {
  metadata+: {
    namespace: params.namespace,
  },
};

local sa = kube.ServiceAccount('maintenance-silence') + namespace {
  automountServiceAccountToken: true,
};

local crb = kube.ClusterRoleBinding('maintenance-silence') + namespace {
  roleRef: {
    apiGroup: 'rbac.authorization.k8s.io',
    kind: 'ClusterRole',
    name: 'cluster-monitoring-operator',
  },
  subjects: [
    {
      kind: 'ServiceAccount',
      name: sa.metadata.name,
      namespace: sa.metadata.namespace,
    },
  ],
};

local cm = kube.ConfigMap('maintenance-silence') + namespace {
  data: {
    silence: importstr './scripts/silence.sh',
  },
};

local certcm = kube.ConfigMap('maintenance-silence-certs') + namespace {
  metadata+: {
    annotations+: {
      'service.beta.openshift.io/inject-cabundle': 'true',
    },
  },
  data:: {},
};

local ujh = kube._Object('managedupgrade.appuio.io/v1beta1', 'UpgradeJobHook', 'maintenance-silence') + namespace {
  spec+: {
    selector: params.upgrade_silence.upgrade_job_selector,
    events: [
      'Start',
      'Finish',
    ],
    template+: {
      spec+: {
        template+: {
          spec+: {
            nodeSelector: params.upgrade_silence.node_selector,
            restartPolicy: 'Never',
            serviceAccountName: sa.metadata.name,  // TODO
            containers: [
              kube.Container('silence') {
                image: params.images.oc.registry + '/' + params.images.oc.image + ':' + params.images.oc.tag,
                command: [ '/usr/local/bin/silence' ],
                env_+: {
                  SILENCES_JSON: std.manifestJsonMinified(std.filterMap(
                    function(m) params.upgrade_silence.alert_matchers[m] != null,
                    function(m) params.upgrade_silence.alert_matchers[m] { comment: m },
                    std.objectFields(params.upgrade_silence.alert_matchers)
                  )),
                  ALERTMANAGER_HOST: params.upgrade_silence.alertmanager_host,
                  ALERTMANAGER_OPERATED_SERVICE: params.upgrade_silence.alertmanager_operated_service,
                  ALERTMANAGER_NAMESPACE: params.upgrade_silence.alertmanager_namespace,
                  SILENCE_TIMEOUT_HOURS: params.upgrade_silence.silence_timeout_hours,
                  SILENCE_AFTER_FINISH_MINUTES: params.upgrade_silence.silence_after_finish_minutes,
                },
                volumeMounts_+: {
                  scripts: {
                    mountPath: '/usr/local/bin/silence',
                    subPath: 'silence',
                    readOnly: true,
                  },
                  'ca-bundle': {
                    mountPath: '/etc/ssl/certs/serving-certs/',
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
              {
                name: 'ca-bundle',
                configMap: {
                  defaultMode: std.parseOctal('0440'),
                  name: certcm.metadata.name,
                },
              },
            ],
          },
        },
      },
    },
  },
};

if enabled then
  [ sa, crb, cm, certcm, ujh ]
else
  {}
