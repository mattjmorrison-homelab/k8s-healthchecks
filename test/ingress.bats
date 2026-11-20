#!/usr/bin/env bats

setup() {
  cd "$BATS_TEST_DIRNAME/.."
  RENDERED="$(helm template healthchecks-test manifests)"
  export RENDERED
}

@test "healthchecks Ingress routes healthchecks.morrisons.site to the healthchecks Service, no TLS block" {
  host=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Ingress" and .metadata.name == "healthchecks") | .spec.rules[0].host
  ' -)
  [ "$host" = "healthchecks.morrisons.site" ]

  class=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Ingress" and .metadata.name == "healthchecks") | .spec.ingressClassName
  ' -)
  [ "$class" = "traefik" ]

  tls=$(echo "$RENDERED" | yq eval-all '
    select(.kind == "Ingress" and .metadata.name == "healthchecks") | .spec.tls
  ' -)
  [ "$tls" = "null" ]
}
