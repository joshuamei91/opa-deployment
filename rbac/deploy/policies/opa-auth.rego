package system.authz

default allow = false
allow {
  "my-secret" == input.identity
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
