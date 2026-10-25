# voting-gitops

What runs in the cluster and how. Argo CD in every cluster (AKS, EKS, GKE) watches this repository and keeps
the cluster in the state described here. The application code lives in
[voting-app](https://github.com/anddr13/voting-app); the clusters are defined in `voting-infra-{azure,aws,gcp}`.

## Layout

```
apps/                 app of apps: one Argo CD Application per component
  values.yaml         chart versions and base values
envs/<cloud>.yaml     per-cloud differences (load balancer annotations, StorageClass, cloud name shown in the UI)
charts/data/          Kafka (Strimzi CRs), Redis, MongoDB
charts/voting/        vote-api, worker, result-api, Ingress, KEDA ScaledObject
```

How it fits together:

```
Terraform (voting-infra-*) ── helm_release ──▶ Argo CD + Application "root"
                                                  │  path: apps, values: envs/<cloud>.yaml
                                                  ▼
  wave 0: traefik (Ingress + LoadBalancer) · keda · strimzi-kafka-operator
  wave 1: data    → Kafka 4.3 (KRaft, 1 node) + topics votes/votes-dlq · Redis · MongoDB (1-member replica set)
  wave 2: voting  → vote-api ×2 · result-api ×2 · worker (1–6 replicas, KEDA on consumer lag)
```

Each wave starts only after the previous one is Healthy. That requires an Application health check in
`argocd-cm`, which Terraform adds: out of the box Argo CD does not assess the health of child Applications.

## Differences between clouds

| | Azure (AKS) | AWS (EKS) | GCP (GKE) |
|---|---|---|---|
| Load balancer for Traefik | Azure LB, TCP health probes | NLB (`aws-load-balancer-type: nlb`) | external passthrough NLB |
| StorageClass | `managed-csi` | `gp3` (created by Terraform, EBS CSI) | `standard-rwo` |

Everything else is identical. That is the point of the GitOps layer: the same charts run on all three clouds.

## Releases

After building the images, the `voting-app` CI commits a new `image.tag` to `charts/voting/values.yaml`.
Argo CD picks the commit up (it polls every ~3 minutes) and rolls the version out to every running cluster.
Rolling back is a `git revert` of that commit.

## Worth knowing

- **Server-side apply** is enabled for traefik/keda/strimzi: the Strimzi and KEDA CRDs exceed the size limit of the `last-applied-configuration` annotation.
- **SkipDryRunOnMissingResource** is needed by `data` and `voting`: their custom resources (Kafka, ScaledObject) cannot be validated until the operators have installed the CRDs.
- **Disks do not outlive their workloads.** Kafka uses `deleteClaim: true`, Mongo uses `persistentVolumeClaimRetentionPolicy: Delete`.
  Otherwise orphaned cloud disks would be left behind after `terraform destroy`.
- **The `resources-finalizer.argocd.argoproj.io` finalizer** is set on every Application, so deleting `root` cascades to everything,
  including LoadBalancer Services. The pre-destroy script in the infra repositories relies on this.
- **No Bitnami charts, on purpose:** their free images are frozen. Redis and Mongo are plain manifests.

## Check locally

```bash
helm lint apps charts/data charts/voting
helm template root apps -f apps/values.yaml -f envs/aws.yaml
```

`.github/workflows/lint.yml` does the same and also runs the output through kubeconform with CRD schemas.
