package rbac.authz

# tests for rbac_policy

test_role_allowed {
  allow with input as {"user": "bob", "action": "read", "resource": "database1"}
}

test_role_not_allowed {
  not allow with input as {"user": "bob", "action": "read", "resource": "server2"}
}

test_role_not_allowed_but_user_allowed {
  allow with input as {"user": "bob", "action": "read", "resource": "service2"}
}

test_user_not_allowed {
  not allow with input as {"user": "bob", "action": "write", "resource": "database2"}
}

test_group1_all_not_allowed {
  not allow with input as {"user": "alice", "action": "read", "resource": "service2"}
}

test_allow_all_resources_group1 {
  allow_all_resources_for_group1 with input as {"user": "alice", "action": "read", "resource": "service2"}
}
