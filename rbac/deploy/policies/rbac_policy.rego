package rbac.authz

import data.user_roles
import data.role_permissions
import data.user_permissions
import input

# logic that implements RBAC.
default allow = false

# Allow roles to access resources
allow {
    # lookup the list of roles for the user
    roles := user_roles[input.user]
    # for each role in that list
    r := roles[_]
    # lookup the actions for the resource for role r
    actions := role_permissions[r][input.resource]
    # for each action
    a := actions[_]
    # check if the action granted to role r matches the user's request
    a == input.action
}

# Allow users to access resources
allow {
    # lookup the actions for the resource for user
    actions := user_permissions[input.user][input.resource]
    # for each action
    a := actions[_]
    # check if the action granted the user matches the user's request
    a == input.action
}

# List of users that belong to group1
belongs_to_group1[user] {
    roles := user_roles[user]
    roles[_] == "group1"
}

# Allow users that belong to group1 to access all resources
allow_all_resources_for_group1 {
    belongs_to_group1[input.user]
}