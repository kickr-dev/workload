# workload <!-- omit in toc -->

<div align="center">

<!-- BEGIN_KICKR_BADGES -->
[![GitLab Release](https://img.shields.io/gitlab/v/release/kickr-dev%2Fworkload?gitlab_url=https%3A%2F%2Fgitlab.com&include_prereleases&sort=semver&style=for-the-badge)](https://gitlab.com/kickr-dev/workload/-/releases)
[![GitLab Issues](https://img.shields.io/gitlab/issues/open/kickr-dev%2Fworkload?gitlab_url=https%3A%2F%2Fgitlab.com&style=for-the-badge)](https://gitlab.com/kickr-dev/workload/-/work_items)
[![GitLab License](https://img.shields.io/gitlab/license/kickr-dev%2Fworkload?gitlab_url=https%3A%2F%2Fgitlab.com&style=for-the-badge)](https://gitlab.com/kickr-dev/workload/-/blob/HEAD/LICENSE)
[![GitLab CICD](https://img.shields.io/gitlab/pipeline-status/kickr-dev%2Fworkload?gitlab_url=https%3A%2F%2Fgitlab.com&branch=main&style=for-the-badge)](https://gitlab.com/kickr-dev/workload/-/pipelines?ref=main)
[![Plumber Score](https://img.shields.io/endpoint?url=https%3A%2F%2Fscore.getplumber.io%2Fgitlab.com%2Fkickr-dev%2Fworkload.json&style=for-the-badge)](https://score.getplumber.io/gitlab.com/kickr-dev/workload)
<!-- END_KICKR_BADGES -->

</div>

---

Workload is a Helm library chart for Kubernetes workloads.
You declare workers, jobs and crons by name in your chart values,
and the library renders the Deployments, Jobs and CronJobs that run them, along with their Services, autoscalers, routes and monitors.

- [Prerequisites](#prerequisites)
- [Getting started](#getting-started)
- [What gets rendered](#what-gets-rendered)
- [Configuration details](#configuration-details)
  - [Exposing a worker over HTTP](#exposing-a-worker-over-http)
  - [Mounting config files and secrets](#mounting-config-files-and-secrets)
  - [Keeping secrets out of your values](#keeping-secrets-out-of-your-values)
  - [Persistence](#persistence)
  - [Init containers and sidecars](#init-containers-and-sidecars)
  - [Running a job as a Helm hook](#running-a-job-as-a-helm-hook)
  - [Images](#images)
  - [Ports and environment variables](#ports-and-environment-variables)
  - [Scaling](#scaling)
  - [Rejected combinations](#rejected-combinations)
  - [Service accounts and RBAC](#service-accounts-and-rbac)
  - [Resource names and labels](#resource-names-and-labels)
  - [Templated values](#templated-values)
  - [Empty values and Kubernetes defaults](#empty-values-and-kubernetes-defaults)
- [Parameters](#parameters)

## Prerequisites

- Helm 3.8 or later, for OCI dependencies.
- Kubernetes 1.23 or later, tested against 1.37.
- The CRDs of each optional feature you enable:

| Feature           | Required CRDs                                                                                                  |
| ----------------- | -------------------------------------------------------------------------------------------------------------- |
| `externalSecrets` | [External Secrets Operator](https://external-secrets.io/latest/introduction/getting-started/) v1               |
| `httpRoute`       | [Gateway API](https://gateway-api.sigs.k8s.io/guides/#installing-gateway-api) v1                               |
| `ingressRoute`    | [Traefik](https://doc.traefik.io/traefik/reference/install-configuration/providers/kubernetes/kubernetes-crd/) |
| `keda`            | [KEDA](https://keda.sh/docs/latest/deploy/)                                                                    |
| `podMonitor`      | [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/installation/)                      |
| `serviceMonitor`  | [Prometheus Operator](https://prometheus-operator.dev/docs/getting-started/installation/)                      |
| `vpa`             | [Vertical Pod Autoscaler](https://github.com/kubernetes/autoscaler/tree/master/vertical-pod-autoscaler)        |

## Getting started

A library chart can't be installed on its own,
so you add it as a dependency of your application chart and let a single template render everything.

1. Declare the dependency in your Chart.yaml, then run `helm dependency update ./chart`:

   ```yaml
   dependencies:
     - name: workload
       version: x.y.z # replace with a released version
       repository: oci://registry.gitlab.com/kickr-dev
   ```

   Released versions are listed on [Artifact Hub](https://artifacthub.io/packages/helm/kickr-workload/workload)
   and in the [changelog](https://gitlab.com/kickr-dev/workload/-/blob/main/CHANGELOG.md).

2. Create a template, for instance templates/application.yaml, that includes the library:

   ```yaml
   {{ include "workload.application" . }}
   ```

3. Declare your components in values.yaml, knowing that workers run continuously, jobs run once and crons run on a schedule.
   The example below is the smallest working setup,
   and [chart/values.yaml](https://gitlab.com/kickr-dev/workload/-/blob/HEAD/chart/values.yaml) has every key with its comments if you'd rather start from there:

   ```yaml
   workers:
     api:
       kind: Deployment
       restartPolicy: Always
       image:
         registry: registry.example.com
         repository: api
       ports:
         http: 8080

   jobs:
     migrate:
       restartPolicy: OnFailure
       image:
         registry: registry.example.com
         repository: migrate

   crons:
     cleanup:
       schedule: "0 0 * * *"
       restartPolicy: OnFailure
       image:
         registry: registry.example.com
         repository: cleanup
   ```

   Every component needs an image repository and a restart policy, workers a kind as well, and crons a schedule.
   Their names are DNS-1123 labels of up to 20 characters, unique across all three kinds.

4. Copy [chart/values.schema.json](https://gitlab.com/kickr-dev/workload/-/blob/HEAD/chart/values.schema.json) next to your values.yaml
   so that Helm validates your values on install, upgrade, template and lint.

5. Deploy the release:

   ```sh
   helm upgrade --install my-release ./chart --namespace my-namespace
   ```

## What gets rendered

Each component gets its controller,
and every other resource below appears only for the entries you declare or the features you enable.

| Resource                | Rendered for                 | Rendered when                     |
| ----------------------- | ---------------------------- | --------------------------------- |
| ServiceAccount          | release, each component      | `serviceAccount.create` set       |
| Role and RoleBinding    | release, each component      | `serviceAccount.rules` set        |
| ConfigMap               | each `configMaps` entry      | always                            |
| Secret                  | each `secrets` entry         | always                            |
| ExternalSecret          | each `externalSecrets` entry | always                            |
| PersistentVolumeClaim   | each `volumeClaims` entry    | not a StatefulSet worker          |
| Deployment              | each worker                  | `kind: Deployment`                |
| StatefulSet             | each worker                  | `kind: StatefulSet`               |
| DaemonSet               | each worker                  | `kind: DaemonSet`                 |
| Job                     | each job, per revision       | `hook` unset                      |
| Job as Helm hook        | each job                     | `hook` set                        |
| CronJob                 | each cron                    | always                            |
| Service                 | each worker                  | `service.enabled` and `ports` set |
| Headless Service        | each worker                  | `kind: StatefulSet`               |
| HorizontalPodAutoscaler | each worker                  | `autoscaling` enabled             |
| ScaledObject            | each worker                  | `keda` enabled                    |
| VerticalPodAutoscaler   | each worker                  | `vpa` enabled                     |
| PodDisruptionBudget     | each worker                  | `pdb` enabled                     |
| IngressRoute            | each worker                  | `ingressRoute` enabled            |
| HTTPRoute               | each worker                  | `httpRoute` enabled               |
| PodMonitor              | each worker                  | `podMonitor` enabled              |
| ServiceMonitor          | each worker                  | `serviceMonitor` enabled          |

## Configuration details

### Exposing a worker over HTTP

To reach a worker from outside the cluster, enable `ingressRoute` for Traefik,
or `httpRoute` with its parent gateways and hostnames for the Gateway API, and point it at one of the worker's ports by name.

Since routes are rendered with tpl, the example below declares the host once and reuses it in each route:

```yaml
host: api.example.com

workers:
  api:
    kind: Deployment
    restartPolicy: Always
    image:
      registry: registry.example.com
      repository: api
    ports:
      http: 8080
    ingressRoute:
      enabled: true
      port: http
      entryPoints:
        - websecure
      routes:
        - match: Host(`{{ .Values.host }}`) && PathPrefix(`/api`)
        - match: Host(`{{ .Values.host }}`) && PathPrefix(`/docs`)
      tls:
        certResolver: letsencrypt
```

### Mounting config files and secrets

Each entry under `configMaps` or `secrets` renders a resource named `<fullname>-<component>-<name>`,
and a worker rolls out whenever one of them changes.
Its content merges any of:

- `files`, chart files matching the globs, copied as they are.
- `templates`, chart files matching the globs, rendered with tpl.
- `data`, inline entries, rendered with tpl.

The container then reads an entry in one of two ways:

- As files, when `mountPath` is set, through a read-only pod volume named `configmap-<name>` or `secret-<name>` that init containers and sidecars can mount too.
- As environment variables, through `envFrom`, whose names are rendered with tpl.

The example below does both, mounting config files and building the Secret name with the `workload.componentName` helper:

```yaml
db:
  password: "" # comes from DB_PASSWORD CICD env variable

workers:
  api:
    configMaps:
      - name: config.
        mountPath: /etc/config/
        files: [config/*]
    secrets:
      - name: credentials.
        data:
          DB_PASSWORD: "{{ .Values.db.password }}"
    envFrom:
      - secretRef:
          name: '{{ include "workload.componentName" . }}-credentials'
```

A ConfigMap or Secret from your own chart templates is yours to mount through `volumes` and `volumeMounts`.
Volumes are rendered with tpl as well, so the name can follow the release fullname:

```yaml
workers:
  api:
    volumes:
      - name: shared.
        configMap:
          name: '{{ include "workload.fullname" . }}-shared'
    volumeMounts:
      - name: shared.
        mountPath: /etc/shared/
        readOnly: true
```

### Keeping secrets out of your values

Secret values sit in plain text in your values files and in the Helm release.
To keep them out of your values files, you can:

- Inject them from CI, with `--set` or a values file built from CI variables.
- Encrypt your values files with [helm-secrets](https://github.com/jkroepke/helm-secrets).
- Sync them from a secret store with an operator, then reference the synced Secret through envFrom or volumes.

The library renders [External Secrets](https://external-secrets.io/latest/) resources itself from `externalSecrets` entries,
but since their values live in the store, a change there won't roll out your workers
unless a controller such as [Reloader](https://github.com/stakater/Reloader) watches them through annotations.

Any other operator needs its resources in your own chart templates, so pick one your cluster already runs:

| Operator                                                                              | API group                    |
| ------------------------------------------------------------------------------------- | ---------------------------- |
| [External Secrets](https://external-secrets.io/latest/)                               | `external-secrets.io`        |
| [Secrets Store CSI Driver](https://secrets-store-csi-driver.sigs.k8s.io/)             | `secrets-store.csi.x-k8s.io` |
| [Vault Secrets Operator](https://developer.hashicorp.com/vault/docs/platform/k8s/vso) | `secrets.hashicorp.com`      |
| [Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)                      | `bitnami.com`                |

Each one registers its own API group, so you can check which are installed with:

```sh
kubectl api-versions | grep -E 'external-secrets.io|secrets-store.csi.x-k8s.io|secrets.hashicorp.com|bitnami.com'
```

### Persistence

Each entry under `volumeClaims` requests storage and mounts it at its mount path, but how it's claimed depends on the component.
A StatefulSet worker gets one claim per pod,
while any other component shares a single PersistentVolumeClaim that survives `helm uninstall` when `retain` is set.

For example, this cron dumps the database every night into a retained claim:

```yaml
crons:
  backup:
    schedule: "0 3 * * *"
    concurrencyPolicy: Forbid
    restartPolicy: OnFailure
    image:
      repository: postgres
      tag: 17.6-alpine
    command: [sh, -c, "pg_dump --host postgres.database.svc.cluster.local --format custom --file /backups/$(date +%F).dump"]
    envFrom:
      - secretRef:
          name: database-credentials # PGDATABASE, PGUSER and PGPASSWORD
    volumeClaims:
      - name: backups.
        mountPath: /backups/
        size: 20Gi
        retain: true
```

### Init containers and sidecars

Init containers run in order before the component container.
Give one `restartPolicy: Always`
and it becomes a [native sidecar](https://kubernetes.io/blog/2023/08/25/native-sidecar-containers/) (Kubernetes 1.29+),
which runs beside the component container and stops after it so that Jobs and CronJobs still complete.

Here the job waits for its database,
then sends its telemetry to an [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) sidecar,
which outlives the job container long enough to flush the last batch:

```yaml
jobs:
  migrate:
    restartPolicy: OnFailure
    image:
      registry: registry.example.com
      repository: migrate
    env:
      OTEL_EXPORTER_OTLP_ENDPOINT: http://localhost:4317
    configMaps:
      - name: otel.
        mountPath: /etc/otelcol/
        files: [otel/config.yaml]
    initContainers:
      - name: wait-db.
        image: busybox:1.37.0
        command: [sh, -c, "until nc -z postgres.database.svc.cluster.local 5432; do sleep 1; done"]
      - name: otel-collector.
        image: otel/opentelemetry-collector:0.161.0
        volumeMounts:
          - name: configmap-otel.
            mountPath: /etc/otelcol/
        restartPolicy: Always
```

### Running a job as a Helm hook

To run a job at a given step of the release rather than alongside the workers, give it a `hook`.
It then runs as a [Helm hook](https://helm.sh/docs/topics/charts_hooks/),
and Helm waits for it to complete before going on.

Here the database is migrated on each install and upgrade, before the workers roll out:

```yaml
jobs:
  migrate:
    hook:
      events: [pre-install, pre-upgrade]
      weight: 0
      deletePolicies: [before-hook-creation, hook-succeeded]
    restartPolicy: OnFailure
    image:
      registry: registry.example.com
      repository: migrate
```

The job can count on its own ConfigMaps, Secrets, ExternalSecrets and ServiceAccount from its first run,
since Helm creates them just before it.
Its volume claims and the release ServiceAccount, however, come with the rest of the release,
so a `pre-install` job won't find them yet.

### Images

An empty image tag falls back to the `appVersion` value, then to the chart `AppVersion`.
To share one image between components, reuse it with a YAML anchor
or, since the image reference is rendered with tpl, with a template expression:

```yaml
image: &image
  registry: registry.example.com
  repository: api
  pullPolicy: &pullPolicy IfNotPresent

workers:
  api:
    image:
      registry: "{{ .Values.image.registry }}" # through 'tpl'
      repository: "{{ .Values.image.repository }}"
      pullPolicy: *pullPolicy
jobs:
  migrate:
    image: *image # through YAML anchor
```

### Ports and environment variables

Ports are declared by name, and the Service, the routes and the monitors all refer to a port through that name.
Each port:

- Is TCP, unless written as `{port: 5353, protocol: UDP}`.
- Reaches the container as an environment variable, `http-metrics: 9090` giving `HTTP_METRICS_PORT=9090`.
- Is exposed by the Service on the container port, or on the port of the same name under `service.ports`.

For example, this worker listens on 8080 and its Service serves it on 80:

```yaml
workers:
  api:
    ports:
      http: 8080
    service:
      ports:
        http: 80
```

An `env` entry is either a literal
or an [EnvVarSource](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.37/#envvarsource-v1-core),
which covers what envFrom can't, like reading a pod field or renaming a single key from a Secret the chart doesn't own:

```yaml
workers:
  api:
    env:
      POD_NAME:
        fieldRef:
          fieldPath: metadata.name
      GOMEMLIMIT:
        resourceFieldRef:
          resource: limits.memory
      DB_PASSWORD:
        secretKeyRef:
          name: database-credentials
          key: password
```

### Scaling

Once `autoscaling` or `keda` is enabled, the library drops `replicaCount`,
since every upgrade would otherwise reset the workload to that count and fight the autoscaler,
[as Kubernetes warns](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#migrating-deployments-and-statefulsets-to-horizontal-autoscaling).

Enabling it on a running release can briefly scale the workload down to one pod, until the autoscaler catches up.

### Rejected combinations

The schema rejects values that would conflict once rendered:

- `autoscaling` with `keda`, since KEDA creates its own HorizontalPodAutoscaler.
- `podMonitor` with `serviceMonitor`, since both would scrape the same pods.
- `replicaCount`, `paused`, `progressDeadlineSeconds`, `autoscaling` or `keda` on a DaemonSet.
- `paused` or `progressDeadlineSeconds` on a StatefulSet.

### Service accounts and RBAC

A component's pods run as the `serviceAccount` set on that component, or as the release-wide one when it sets none.
Both take the same keys:

- With `create: true`, the library creates the account as `name`, or under a generated name when the name is empty.
- With `create: false`, pods use the existing `name` account, or the namespace default one when the name is empty.
- With `rules`, the library also creates a Role and binds it to the account.

The generated name is `<fullname>` for the release account and `<fullname>-<component>` for a component one,
and the matching Role and RoleBinding carry the same name.

### Resource names and labels

Release-wide resources are named `<fullname>` as in a `helm create` chart, component resources `<fullname>-<component>`,
and resources built from a list entry `<fullname>-<component>-<name>`.
Each part is capped so that the longest form still fits the 63 characters of a DNS label:

- 26 characters for the fullname, which is cut.
- 20 for the component name.
- 15 for the name of a ConfigMap, Secret, ExternalSecret or volume claim entry.
- 2 for the dashes.

Pods are selected by `app.kubernetes.io/name` and `app.kubernetes.io/instance`, shared across the release,
plus `app.kubernetes.io/component` to tell components apart.

For your own metadata, `labels` and `annotations` go on the component controller, `podLabels` and `podAnnotations` on its pods.

### Templated values

Template expressions work in `command`, `args`, `volumes`, `initContainers`, `envFrom`, `annotations`, `podAnnotations`,
the image reference and `ingressRoute.routes`, which the library renders with tpl.

Besides the chart root context, they see the current component as `.Component.Name` and `.Component.Values`,
so `{{ .Component.Values.env.BINARY_NAME }}` reads one of its env values
and `workload.componentName` returns its resource name, `<fullname>-<component>`.

### Empty values and Kubernetes defaults

The library treats the following scalars as missing when they're set to `0`, `false` or `""`, so Kubernetes applies its own default:

- `activeDeadlineSeconds`
- `autoscaling.minReplicas`
- `autoscaling.targetCPUUtilizationPercentage`
- `autoscaling.targetMemoryUtilizationPercentage`
- `completionMode`
- `completions`
- `concurrencyPolicy`
- `externalSecrets[].refreshInterval`
- `image.pullPolicy`
- `image.registry`
- `keda.maxReplicaCount`
- `minReadySeconds`
- `parallelism`
- `paused`
- `pdb.maxUnavailable`
- `pdb.minAvailable`
- `podManagementPolicy`
- `podMonitor.interval`
- `podMonitor.path`
- `progressDeadlineSeconds`
- `serviceMonitor.interval`
- `serviceMonitor.path`
- `suspend`
- `timeZone`
- `volumeClaims[].storageClassName`
- `vpa.updateMode`

The following keep `0` or `false`, because there it means something different from leaving the key out:

- `automountServiceAccountToken`
- `backoffLimit`
- `failedJobsHistoryLimit`
- `keda.cooldownPeriod`
- `keda.minReplicaCount`
- `keda.pollingInterval`
- `replicaCount`
- `revisionHistoryLimit`
- `startingDeadlineSeconds`
- `successfulJobsHistoryLimit`
- `terminationGracePeriodSeconds`
- `ttlSecondsAfterFinished`

## Parameters

Every key is documented in [chart/values.yaml](https://gitlab.com/kickr-dev/workload/-/blob/HEAD/chart/values.yaml),
an example the library never reads,
and [chart/values.schema.json](https://gitlab.com/kickr-dev/workload/-/blob/HEAD/chart/values.schema.json)
carries the same descriptions for validation and completion in your editor.

Keys typed after Kubernetes objects follow the [Kubernetes API reference](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.37/).
