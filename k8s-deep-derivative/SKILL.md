---
name: k8s-deep-derivative
version: 1.2.0
author: Matthias Wessendorf
description: |
  Review and enforce the DeepDerivative/DeepEqual hybrid pattern for
  Kubernetes controller reconciliation update logic. Use when writing
  or reviewing controller code that compares desired vs live resource
  specs (Deployments, StatefulSets, DaemonSets, Jobs, etc.).
  Ensures correct handling of API server defaulting and user
  field removals.
allowed-tools:
  - Read
  - Bash
  - LSP
  - AskUserQuestion
---

# Kubernetes DeepDerivative/DeepEqual Review

You are a Kubernetes controller code reviewer specializing in the correct use of `equality.Semantic.DeepDerivative` and `equality.Semantic.DeepEqual` for reconciliation update detection.

## Quick Checklist

Use this as a fast sanity check. The full explanation follows below.

- [ ] Using `equality.Semantic`, not `reflect.DeepEqual`?
- [ ] `DeepDerivative(desired, existing)` - argument order correct (desired first)?
- [ ] Explicit `DeepEqual` for every removable slice field (Args, Env, EnvFrom, VolumeMounts, Volumes, InitContainers)?
- [ ] Explicit `DeepEqual` for every removable map field (Labels, Annotations, Resources)?
- [ ] Explicit `DeepEqual` for every removable pointer field (SecurityContext, PodSecurityContext, LivenessProbe, ReadinessProbe, StartupProbe)?
- [ ] Explicit `DeepEqual` for Ports, Command if controller sets them?
- [ ] String fields that can be zeroed use `!=` (e.g. ServiceAccountName)?
- [ ] `Spec.Replicas` checked (lives outside PodSpec)?
- [ ] Other outer Spec fields audited (Selector, Strategy, MinReadySeconds, etc.)?
- [ ] All managed containers covered (init containers, sidecars), not just `Containers[0]`?
- [ ] Container index bounds safe (len check before accessing `Containers[i]`)?

## The Pattern

When a controller reconciles a resource with a PodTemplateSpec (Deployment, StatefulSet, DaemonSet, Job, CronJob, etc.), it must compare the **desired** spec (built by the controller) against the **existing** spec (live from the API server) to decide whether an update is needed.

There are two competing concerns:

1. **API server defaulting**: After creation, the API server sets default values on many fields the controller never explicitly sets (e.g. `terminationGracePeriodSeconds`, `dnsPolicy`, `restartPolicy`, `schedulerName`, `imagePullPolicy`). A naive `DeepEqual` on the full PodSpec will see these as differences and trigger a spurious update on **every reconcile**.

2. **User removals**: When a user removes a field (e.g. clears all `args`, removes `env` vars, deletes storage mounts), the desired spec will have zero/nil/empty values for those fields. These removals must be detected and applied.

## The Solution: Hybrid Approach

```go
oldPodSpec := existingDeployment.Spec.Template.Spec
newPodSpec := deployment.Spec.Template.Spec

// Safety: ensure both sides have the expected containers before indexing
if len(newPodSpec.Containers) == 0 || len(oldPodSpec.Containers) == 0 {
    // Handle error or force update
}

needsUpdate := !equality.Semantic.DeepDerivative(newPodSpec, oldPodSpec) ||
    // --- Per-container removable fields (repeat for each managed container) ---
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].Args, oldPodSpec.Containers[0].Args) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].Env, oldPodSpec.Containers[0].Env) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].EnvFrom, oldPodSpec.Containers[0].EnvFrom) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].VolumeMounts, oldPodSpec.Containers[0].VolumeMounts) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].Ports, oldPodSpec.Containers[0].Ports) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].Command, oldPodSpec.Containers[0].Command) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].Resources, oldPodSpec.Containers[0].Resources) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].SecurityContext, oldPodSpec.Containers[0].SecurityContext) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].LivenessProbe, oldPodSpec.Containers[0].LivenessProbe) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].ReadinessProbe, oldPodSpec.Containers[0].ReadinessProbe) ||
    !equality.Semantic.DeepEqual(newPodSpec.Containers[0].StartupProbe, oldPodSpec.Containers[0].StartupProbe) ||
    // --- Init containers (if the controller manages them) ---
    // !equality.Semantic.DeepEqual(newPodSpec.InitContainers, oldPodSpec.InitContainers) ||
    // --- Pod-level removable fields ---
    !equality.Semantic.DeepEqual(newPodSpec.Volumes, oldPodSpec.Volumes) ||
    !equality.Semantic.DeepEqual(newPodSpec.SecurityContext, oldPodSpec.SecurityContext) ||
    // --- PodTemplate labels/annotations (map types, skipped when nil/empty) ---
    !equality.Semantic.DeepEqual(deployment.Spec.Template.Labels, existingDeployment.Spec.Template.Labels) ||
    !equality.Semantic.DeepEqual(deployment.Spec.Template.Annotations, existingDeployment.Spec.Template.Annotations) ||
    // --- String fields use != (DeepDerivative skips empty strings) ---
    newPodSpec.ServiceAccountName != oldPodSpec.ServiceAccountName ||
    // --- Spec fields outside PodSpec ---
    !equality.Semantic.DeepEqual(deployment.Spec.Replicas, existingDeployment.Spec.Replicas)
    // Also audit: Spec.Selector, Spec.Strategy, Spec.MinReadySeconds, etc.
```

**CronJob note**: CronJobs nest the PodSpec one level deeper than other workload types. The path is `Spec.JobTemplate.Spec.Template.Spec` instead of `Spec.Template.Spec`. Adjust field paths accordingly when reviewing CronJob controllers.

### Why `DeepDerivative` on the outer PodSpec

`DeepDerivative(desired, existing)` returns true when every **non-zero** field in `desired` equals the corresponding field in `existing`. However, zero-value skipping only applies to **specific types**:

- **Pointers**: nil pointer in `desired` -> skipped
- **Interfaces**: nil interface in `desired` -> skipped
- **Strings**: empty string (`""`) in `desired` -> skipped
- **Slices**: nil or empty slice in `desired` -> skipped
- **Maps**: nil or empty map in `desired` -> skipped

**Numeric types (`int32`, `int64`, `float64`) and booleans are NOT skipped** -- they fall through to normal `==` comparison even when zero/false. In practice this matters less because Kubernetes API types use pointers for optional numeric/boolean fields (`*int32`, `*bool`), so nil-skipping covers them. But be aware of the distinction for non-pointer fields.

For structs, `DeepDerivative` recurses into each field individually -- it does not skip a struct at the struct level. The zero-value skipping happens at the leaf fields (pointers, strings, slices, maps).

This means:

- Fields defaulted by the API server (that the controller never sets) are ignored -- no spurious updates.
- Additions and modifications to fields the controller sets are detected correctly.
- **But**: removals (setting a field to nil/empty) are NOT detected, because `DeepDerivative` skips those leaf types in the first argument.

Additionally, for **slices**, `DeepDerivative` only compares elements `0..len(desired)-1`. If `desired` has fewer elements than `existing`, the extra elements in `existing` are silently ignored. This is another reason explicit `DeepEqual` checks are needed on slice fields that can shrink or be cleared.

### Why explicit `DeepEqual` on specific fields

For every field that:
1. The controller's `createDeployment` (or equivalent) populates, **AND**
2. A user can legitimately remove/zero out

...an explicit `DeepEqual` check is required. This catches the removal case that `DeepDerivative` misses.

### Import

```go
"k8s.io/apimachinery/pkg/api/equality"
```

Use `equality.Semantic.DeepDerivative` and `equality.Semantic.DeepEqual` -- NOT `reflect.DeepEqual`. The `equality.Semantic` equalities handle Kubernetes-specific types correctly (e.g. resource quantities, time comparisons).

## Your Review Task

When invoked, perform the following audit:

### Step 1: Find the update comparison logic

Search the controller code for `DeepDerivative`, `DeepEqual`, `reflect.DeepEqual`, or update-detection patterns in reconciliation functions.

### Step 2: Identify what `createDeployment` sets

Read the function that builds the desired resource (Deployment, StatefulSet, DaemonSet, Job, etc.). List every field it sets on:

- **PodSpec**: containers, init containers, volumes, security context, service account, etc.
- **PodTemplate metadata**: labels, annotations
- **Outer Spec**: replicas, selector, strategy, minReadySeconds, etc.

### Step 3: Classify each field

For each field set by the builder function, determine:

| Field | Type (skipped by DeepDerivative?) | Can user remove/zero it? | Needs explicit check? |
|-------|-------------------------------------|--------------------------|---------------------------|
| `Containers[0].Image` | string, but always non-empty | No | No -- DeepDerivative covers it |
| `Containers[0].Args` | `[]string` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].Env` | `[]EnvVar` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].EnvFrom` | `[]EnvFromSource` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].Resources` | `ResourceRequirements` (contains `Limits`/`Requests` which are `ResourceList`, a map type -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].SecurityContext` | `*SecurityContext` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].VolumeMounts` | `[]VolumeMount` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].Ports` | `[]ContainerPort` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].Command` | `[]string` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].LivenessProbe` | `*Probe` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].ReadinessProbe` | `*Probe` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` |
| `Containers[0].StartupProbe` | `*Probe` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` |
| `Volumes` | `[]Volume` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `SecurityContext` | `*PodSecurityContext` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` |
| `ServiceAccountName` | `string` (skipped when empty) | Yes | **Yes** -- `!=` suffices |
| `InitContainers` | `[]Container` (slice -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Template.Labels` | `map[string]string` (map -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Template.Annotations` | `map[string]string` (map -- skipped when nil/empty) | Yes | **Yes** -- `DeepEqual` |
| `Spec.Replicas` | `*int32` (pointer -- skipped when nil) | Yes | **Yes** -- `DeepEqual` (lives outside PodSpec) |
| `Spec.Selector` | `*LabelSelector` (pointer -- skipped when nil) | Rarely | Check if controller sets it |
| `Spec.Strategy` | `DeploymentStrategy` (struct -- recurses, inner fields may be skipped) | Depends | Check if controller sets it |
| ... | ... | ... | ... |

The rule: if a field's type is one that `DeepDerivative` skips at zero-value (pointers, strings, slices, maps, interfaces) AND the field can legitimately be zeroed/removed by a user, it **must** have an explicit `DeepEqual` check (or `!=` for strings). Note that non-pointer numeric and boolean fields are NOT skipped by `DeepDerivative`, so they do not need explicit checks.

> **Note**: The fields listed above are common examples. The actual set of fields requiring explicit `DeepEqual` checks depends on what your controller's builder function populates. Always perform Steps 2-3 to discover the correct set for the controller under review.

### Step 4: Report findings

Report:
- Whether `reflect.DeepEqual` is used (it should not be -- use `equality.Semantic` instead)
- Whether `DeepDerivative` is used on the outer spec (it should be)
- Whether the argument order is correct: `DeepDerivative(desired, existing)` -- desired first
- Missing explicit `DeepEqual` checks for removable fields (slices, maps, pointers, strings that can be zeroed)
- Unnecessary explicit `DeepEqual` checks (fields that are always non-zero and already covered by `DeepDerivative`, or non-pointer numeric/boolean fields that `DeepDerivative` already compares)
- Whether `Spec.Replicas` is compared (it lives outside PodSpec and is commonly forgotten)
- Whether other outer Spec fields are audited (Selector, Strategy, MinReadySeconds, etc.)
- Whether `Resources` (requests/limits) is explicitly checked (map type, commonly managed, skipped when nil)
- Whether `SecurityContext` (pod-level and container-level) is explicitly checked (pointer type, skipped when nil)
- Whether PodTemplate `Labels` and `Annotations` are explicitly checked (map type, skipped when nil/empty)
- String fields that can be zeroed (e.g. `ServiceAccountName`) -- these can use `!=` instead of `DeepEqual`
- Whether all managed containers are covered (init containers, sidecars), not just `Containers[0]`
- Whether container index access is bounds-safe (check `len()` before accessing `Containers[i]`)
- Whether the pattern applies to the correct resource type (Deployment, StatefulSet, DaemonSet, Job, etc.)

## Common Mistakes

1. **Using `reflect.DeepEqual` on the full PodSpec** -- causes spurious updates on every reconcile due to API server defaulting.
2. **Using only `DeepDerivative` without explicit checks** -- misses user removals (zeroing out args, env, volumes, resources, security context, labels, etc.) because `DeepDerivative` skips nil/empty slices, maps, pointers, strings, and interfaces in the first argument.
3. **Using only `DeepEqual` on the full PodSpec** -- same problem as `reflect.DeepEqual`, triggers unnecessary updates.
4. **Wrong argument order for `DeepDerivative`** -- `DeepDerivative(desired, existing)` is correct. Reversing the arguments would skip defaulted fields in the existing spec instead, which is wrong.
5. **Forgetting `Spec.Replicas`** -- lives outside PodSpec, needs its own check.
6. **Forgetting `Resources`** -- `ResourceRequirements.Limits` and `ResourceRequirements.Requests` are `ResourceList` (a map type), skipped by `DeepDerivative` when nil/empty. Removing resource limits goes undetected without an explicit check.
7. **Forgetting `SecurityContext`** -- both `PodSecurityContext` (pod-level) and `SecurityContext` (container-level) are pointer types, skipped when nil. Removing a security context goes undetected without an explicit check.
8. **Forgetting PodTemplate `Labels`/`Annotations`** -- these are `map[string]string`, skipped when nil/empty. If a controller sets labels for selectors or observability, removing them goes undetected without an explicit check.
9. **Not checking new fields after refactoring** -- when new optional fields are added to the CRD/controller (like storage mounts, security contexts), corresponding `DeepEqual` checks must be added if the field can be zeroed.
10. **Only checking `Containers[0]`** -- if the controller manages init containers, sidecars, or multiple containers, each needs the same explicit `DeepEqual` treatment for removable fields.
11. **Assuming `DeepDerivative` skips all zero values** -- it only skips pointers, interfaces, strings, slices, and maps at zero value. Non-pointer numeric types (`int32`, `int64`) and booleans are compared normally even when zero/false.
12. **Indexing containers without bounds check** -- accessing `Containers[0]` without verifying `len(Containers) > 0` can panic if the builder or existing resource has an unexpected shape. Always guard with a length check.
13. **Only auditing PodSpec** -- controllers commonly set fields on the outer Spec (`Replicas`, `Selector`, `Strategy`, `MinReadySeconds`) that also need comparison. Audit the full Spec, not just the PodTemplate.
14. **Forgetting `Ports` and `Command`** -- `Containers[i].Ports` (`[]ContainerPort`) and `Containers[i].Command` (`[]string`) are slices, skipped by `DeepDerivative` when nil/empty. Removing ports or overriding the entrypoint command goes undetected without explicit checks.
15. **Forgetting probes** -- `LivenessProbe`, `ReadinessProbe`, and `StartupProbe` are `*Probe` (pointer type), skipped when nil. Removing a health check probe goes undetected without an explicit `DeepEqual` check.
16. **CronJob nesting depth** -- CronJobs nest PodSpec one level deeper than other workload types (`Spec.JobTemplate.Spec.Template.Spec` instead of `Spec.Template.Spec`). Using Deployment-depth paths on a CronJob controller silently compares the wrong fields.

## References

- [DeepDerivative source](https://github.com/kubernetes/apimachinery/blob/master/third_party/forked/golang/reflect/deep_equal.go) - the actual implementation showing which types are skipped at zero value
- [equality.Semantic setup](https://github.com/kubernetes/apimachinery/blob/master/pkg/api/equality/semantic.go) - where `equality.Semantic` is initialized with Kubernetes-specific equalities
