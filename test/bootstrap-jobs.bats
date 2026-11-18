#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  RENDERED="$(helm template healthchecks-test manifests)"
  export RENDERED
}

@test "healthchecks-bootstrap-secrets runs as a PreSync hook, deleted and recreated on every sync" {
  hook=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Job" and .metadata.name == "healthchecks-bootstrap-secrets") | .metadata.annotations["argocd.argoproj.io/hook"]
  ' -)
  [ "$hook" = "PreSync" ]

  delete_policy=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Job" and .metadata.name == "healthchecks-bootstrap-secrets") | .metadata.annotations["argocd.argoproj.io/hook-delete-policy"]
  ' -)
  [ "$delete_policy" = "BeforeHookCreation,HookSucceeded" ]
}

@test "healthchecks-create-superuser runs as a PostSync hook, after the Deployment is Healthy" {
  hook=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Job" and .metadata.name == "healthchecks-create-superuser") | .metadata.annotations["argocd.argoproj.io/hook"]
  ' -)
  [ "$hook" = "PostSync" ]
}

@test "healthchecks-create-superuser mounts the same PVC the main Deployment uses, at /data" {
  claim=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Job" and .metadata.name == "healthchecks-create-superuser") |
    .spec.template.spec.volumes[] | select(.name == "data") | .persistentVolumeClaim.claimName
  ' -)
  [ "$claim" = "healthchecks" ]
}
