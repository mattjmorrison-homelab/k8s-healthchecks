#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  RENDERED="$(helm template healthchecks-test manifests)"
  export RENDERED
}

@test "healthchecks Deployment runs exactly 1 replica with Recreate strategy, since it's a single sqlite file on an RWO PVC" {
  replicas=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") | .spec.replicas
  ' -)
  [ "$replicas" = "1" ]

  strategy=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") | .spec.strategy.type
  ' -)
  [ "$strategy" = "Recreate" ]
}

@test "healthchecks Deployment points DB_NAME at the mounted PVC, not the image's default in-container path" {
  db_name=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") |
    (.spec.template.spec.containers[] | select(.name == "healthchecks") | .env[] | select(.name == "DB_NAME") | .value)
  ' -)
  [ "$db_name" = "/data/hc.sqlite" ]
}

@test "healthchecks Deployment's SECRET_KEY comes from the healthchecks Secret, not a plain value" {
  secret_name=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") |
    (.spec.template.spec.containers[] | select(.name == "healthchecks") | .env[] | select(.name == "SECRET_KEY") | .valueFrom.secretKeyRef.name)
  ' -)
  [ "$secret_name" = "healthchecks" ]
}

@test "healthchecks Deployment sets SECURE_PROXY_SSL_HEADER so Django trusts Traefik's TLS termination" {
  value=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") |
    (.spec.template.spec.containers[] | select(.name == "healthchecks") | .env[] | select(.name == "SECURE_PROXY_SSL_HEADER") | .value)
  ' -)
  [ "$value" = "X-Forwarded-Proto,https" ]
}

@test "healthchecks Deployment disables Django's DEBUG setting" {
  value=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Deployment" and .metadata.name == "healthchecks") |
    (.spec.template.spec.containers[] | select(.name == "healthchecks") | .env[] | select(.name == "DEBUG") | .value)
  ' -)
  [ "$value" = "False" ]
}
