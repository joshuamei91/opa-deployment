# Open Policy Agent

## Running OPA as server from local installer

Downloaded the installer [here](https://www.openpolicyagent.org/docs/latest/#running-opa). Start the OPA as a server using

```
opa run --server --log-level debug --log-format json-pretty
```

Some useful flags to include:

- --addr: to set the listening address (default: 0.0.0.0:8181)
- --log-level: debug, info (default), error
- --log-format: text, json (default), json-pretty

## Running OPA as server from docker

```
docker run -p 8181:8181 openpolicyagent/opa run --server --log-level debug --log-format json-pretty
```

> You can go to `http://localhost:8181/` in the browser to access a simple interface to make queries and provide input.

## Loading data and policies into OPA

The above commands start the server without loading any data or policies. Let's take a look at how to load data and policies using the REST API. But first we should understand a few concepts about how OPA stores the information.

![document structure](https://d33wubrfki0l68.cloudfront.net/2f22296bc9e7abaa68560a4735f1b3a9aa78b0f4/12234/docs/v0.11.0/images/data-model-logical.svg)

OPA has a built-in root document named `data`. It can contain `base documents` and `virtual documents`.

### [Base documents](https://www.openpolicyagent.org/docs/v0.11.0/how-does-opa-work/#base-documents)

> _So-called base documents contain static, structured data stored in memory and optionally saved to disk for resiliency. Your service will publish and update base documents in order to describe its current state, and your users can do the same to include relevant data about the state of their own deployment context._

An example of a `base document`:

```
{
	"user_roles": {
		"alice": ["group1", "group2"],
		"bob": ["group3"],
		"charlie": ["group1", "group3"],
		"dave": ["group4"]
	}
}
```

To load this into OPA:

```
curl -X PUT -H "Content-Type: application/json" --data-binary @rbac/deploy/user_roles.json http://localhost:8181/v1/data
```

To retrieve the information in the root document `data`:

```
curl http://localhost:8181/v1/data

Output:
{"result":{"user_roles":{"alice":["group1","group2"],"bob":["group3"],"charlie":["group1","group3"],"dave":["group4"]}}}
```

The user_roles document is now stored at `data.user_roles`. You can also choose to load the data into a nested document within `data`. For example, you can to store the data in `data.foo.bar`. Notice the URL path reflects the document structure.

```
curl -X PUT -H "Content-Type: application/json" --data-binary @rbac/deploy/user_roles.json http://localhost:8181/v1/data/foo/bar
```

When you examine `data`, you should get this now. Notice that the document is nested in `data.foo.bar`.

```
{"result":{"foo":{"bar":{"user_roles":{"alice":["group1","group2"],"bob":["group3"],"charlie":["group1","group3"],"dave":["group4"]}}},"user_roles":{"alice":["group1","group2"],"bob":["group3"],"charlie":["group1","group3"],"dave":["group4"]}}}
```

Notice that in the sample `base document`, we included the "user_roles" key at the top level. Let's take a look at a slight variation where I remove the "user_roles" key.

```
{
  "alice": ["group1", "group2"],
  "bob": ["group3"],
  "charlie": ["group1", "group3"],
  "dave": ["group4"]
}
```

Now if you wanted to load the document into `data.user_roles`, run (notice the endpoint URL is different):

```
curl -X PUT -H "Content-Type: application/json" --data-binary @rbac/deploy/user_roles.json http://localhost:8181/v1/data/user_roles
```

The purpose of this example is to show that there is flexibility in structuring the data either within the document itself or through the endpoint URL path to achieve the nested structure.

### [Policies](https://www.openpolicyagent.org/docs/v0.11.0/how-does-opa-work/#policies)

> _Policies are written using OPA’s purpose-built, declarative language Rego. Each Rego file defines a policy module using a collection of rules that describe the expected state of your service. Both your service and its users can publish and update policy modules using OPA’s Policy API._

An example of a `policy` with some rules (`allow`, `belongs_to_group1`, `allow_all_resources_for_group1`):

```
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
```

To load this into OPA:

```
curl -X PUT -H "Content-Type: application/json" --data-binary @rbac/deploy/policies/rbac_policy.rego http://localhost:8181/v1/policies/example-policy
```

> _A policy file must contain a single package declaration, which defines the path to the policy module and its rules (for example, data.rbac.authz.allow). **The policy name itself (in this case, “example-policy”) is only used to identify policies for file management purposes; it is not used otherwise.**_

To retrieve the policy:

```
# To get all policies
curl http://localhost:8181/v1/policies

# To get specific policy
curl http://localhost:8181/v1/policies/example-policy
```

### [Rule and Virtual documents](https://www.openpolicyagent.org/docs/v0.11.0/how-does-opa-work/#rules-and-virtual-documents)

> _In contrast to base documents, virtual documents embody the results of evaluating the rules included in policy modules. Virtual documents are computed when users publish new policy modules, update existing modules, run queries, and when any relevant base document is published or updated. Rules allow policy authors to write questions with yes-no answers (that is, predicates) and to generate structured values from raw data found in base documents as well as from intermediate data found in other virtual documents._

In the previous example, the `allow` rule generated a `virtual document` that is stored in `data.rbac.authz.allow` while the `belongs_to_group1` rule generated a `virtual document` at `data.rbac.authz.belongs_to_group1`

```
# Retrieve `belongs_to_group1` virtual document
curl http://localhost:8181/v1/data/rbac/authz/belongs_to_group1

# Retrieve all data nested in rbac.authz (the data can contain rules, virtual documents and base documents)
curl http://localhost:8181/v1/data/rbac/authz
```

### Understanding rules with parameters
Rules like the below can be confusing.
```
belongs_to_group1[user] {
    roles := user_roles[user]
    roles[_] == "group1"
}
```
> _[Variables](https://www.openpolicyagent.org/docs/v0.11.0/how-do-i-write-policies/#variables) appearing in the head of a rule can be thought of as input and output of the rule. Unlike many programming languages, where a variable is either an input or an output, in Rego a variable is simultaneously an input and an output. If a query supplies a value for a variable, that variable is an input, and if the query does not supply a value for a variable, that variable is an output._

A rule generates a `virtual document` after it is evaluated. In this case, the `belongs_to_group1` (virtual) document will contain the list of `user` values that would cause the rule `belongs_to_group1[user]` to evaluate `true`. You can think of it as looping through different the `user` keys in `user_roles`. For each value `roles`, it will check whether "group1" is in the array. If it is `true`, then the `user` will be added to the `belongs_to_group1` (virtual) document.

The `belongs_to_group1[user]` rule can be called in another rule:
```
allow_all_resources_for_group1 {
    belongs_to_group1[input.user]
}
```
When this rule is evaluated, it will check whether `input.user` is found in the `belongs_to_group1` (virtual) document. If it is found, then the rule will be evaluated to `true`.

> Notice that when you run `curl http://localhost:8181/v1/data/rbac/authz`, you do not see the `allow_all_resource_for_group1` document. That is because the rule is not evaluated when there is no `input`, hence no corresponding virtual document is computed.

## Query

Now that we have the data and policies in OPA, we can run queries against it. For example, to find out if `alice` can perform `read` on `database2`, we construct the following `input`:
```
{
	"input": 
	{
		"user": "alice",
		"action": "read",
		"resource": "database2"
	}
}
```
Evaluate the query:
```
# Evaluate against all rules in rbac.authz
curl -X POST -H "Content-Type: application/json" --data @rbac/query.json http://localhost:8181/v1/data/rbac/authz

Output:
{"result":{"allow":false,"allow_all_resource_for_group1":true,"belongs_to_group1":["alice","charlie"]}}

# Evaluate against a specific rule in rbac.authz
curl -X POST -H "Content-Type: application/json" --data @rbac/query.json http://localhost:8181/v1/data/rbac/authz/allow

Output:
{"result":false}
```
> Note: A POST request to an endpoint is treated as an evaluation and the OPA will try to evaluate the (optional) input against the documents at that endpoint. A PUT request will load the data/document at the same endpoint.

## Loading data and polices on server start

It is also possible to load the data and policies when starting the server.
```
# Running local installer
opa run --server --log-level debug --log-format json-pretty rbac/deploy

# Running in docker
# On Windows
docker run -p 8181:8181 -v path\to\OPA\rbac\deploy:/mountedFolder openpolicyagent/opa run --server --log-level debug --log-format json-pretty /mountedFolder
# On Linux
docker run -p 8181:8181 -v $PWD/rbac/deploy:/mountedFolder openpolicyagent/opa run --server --log-level debug --log-format json-pretty /mountedFolder
```

With the local installer, it takes the files in the `rbac/deploy` folder and tries to load files ending with `yml`, `json` or `rego`. With docker, the `rbac/deploy` folder is mounted into the container volume at `/mountedFolder` and the OPA loads the files in the `mountedFolder`. The data will be loaded into `data.user_roles`, `data.role_permissions` and `data.user_permissions`.

It is also possible to create a nested document structure in OPA by structuring the folders we are loading from. For example, if the below command is run instead. OPA recursively goes through the subfolders and replicates the same structure in the `data` document.
```
# note: we load the data starting from the 'rbac' folder instead of the 'rbac/deploy' folder 
opa run --server --log-level debug --log-format json-pretty rbac
```

The document structure will be `data.deploy.user_roles`, `data.deploy.role_permissions` and `data.deploy.user_permissions` instead.

## Deploy OPA in Kubernetes
Refer to the [deployment guide][deployment] for instructions on how to deploy the OPA docker image on Kubernetes.

```
# To query the OPA deployed on Kube
# -k: ignore self-sign cert error
# use the query from query.json
curl -k -X POST -H "Content-Type: application/json" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.EpM5XBzTJZ4J8AfoJEcJrjth8pfH28LWdjLo90sYb9g" --data @rbac/query.json https://<ipaddress>:<port>/v1/data/rbac/authz

# use query from command line input
curl -k -X POST -H "Content-Type: application/json" -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.EpM5XBzTJZ4J8AfoJEcJrjth8pfH28LWdjLo90sYb9g" -d "{\"input\":{\"user\": \"alice\",\"action\": \"read\",\"resource\": \"database2\"}}" https://<ipaddress>:<port>/v1/data/rbac/authz
```

## Testing policies
To verify correctness of policies, you can write tests (see `test` folder) and allow examine the coverage of your tests. Run the following command in your development environment. 

> Note: you need to include explicitly include the `./deploy` folder otherwise it will not pick up the policy and data files

```
opa test ./rbac/deploy ./rbac/test -v --coverage
```

## Additional points to note

### Considerations on different methods to load data and policies
- We can load the data and policies either via a mounted volume in Kubernetes, a periodic bundle download or REST API
- Considerations: In a Kube deployment with a centralised OPA with multiple replicas for high availability, we would need to download the data and policies peridically via the [bundle API][bundle] to ensure all replicas get the same policies and data. If we are using a distributed architecture ie. OPA as sidecar for each service (without HA), policies and data can be mounted in a volume and subsequently updated via REST API.

### Liveness and readiness probes
- Include `allow` rules in `system.authz` (see [security][security] section) to enable liveness and readiness probes to work after enabling API authorization rules
```
package system.authz

default allow = false           # Reject requests by default.

allow {                         # Allow request if...
  "secret" == input.identity  # Identity is the secret root key.
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
```

## References

https://www.openpolicyagent.org/docs/v0.11.0/how-does-opa-work/
https://www.openpolicyagent.org/docs/v0.11.0/comparison-to-other-systems/
https://www.openpolicyagent.org/docs/v0.11.0/http-api-authorization/
https://www.openpolicyagent.org/docs/v0.11.0/language-cheatsheet/

[deployment]: https://www.openpolicyagent.org/docs/latest/deployments/
[bundle]: https://www.openpolicyagent.org/docs/latest/external-data/#option-3-bundle-api
[security]: https://www.openpolicyagent.org/docs/latest/security/