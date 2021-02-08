package system.authz

# tests for opa_auth

test_no_jwt_denied {
  not allow with input as {"identity":"", "method": "POST", "path": ["v1", "data", "rbac", "authz"]}
}

test_wrong_jwt_denied {
  not allow with input as {"identity":"wrong-jwt", "method": "POST", "path": ["v1", "data", "rbac", "authz"]}
}

test_correct_jwt_allowed {
  allow with input as {"identity":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.EpM5XBzTJZ4J8AfoJEcJrjth8pfH28LWdjLo90sYb9g", "method": "POST", "path": ["v1", "data", "rbac", "authz"]}
}

test_get_liveness_allowed {
  allow with input as {"identity":"", "method": "GET", "path": [""]}
}

test_get_health_allowed {
  allow with input as {"identity":"", "method": "GET", "path": ["health"]}
}