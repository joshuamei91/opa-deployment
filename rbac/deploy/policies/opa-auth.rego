package system.authz

default allow = false
allow {
  # "my-secret" == input.identity
  hs256_token := input.identity
  secret_key := "my-secret"
  io.jwt.verify_hs256(hs256_token, secret_key)
}

# enable liveness probe to work
allow {
  1 == count(input.path)
  "" == input.path[0]
}

# enable readiness probe to work
allow {
  1 == count(input.path)
  "health" == input.path[0]
}
