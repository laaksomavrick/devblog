---
title: Supporting Staging and Production Environments With Terraform 
date: "2023-02-08T00:00:00.000Z"
description: Use modules to DRY up your infrastructure-as-code configuration to support multiple environments.
---

# What I wanted to do

When developing software, it's a good practice to test your changes before releasing them to users.
This can be done locally, but our laptops and our user-serving environments generally differ dramatically.
Further, it's advisable to not impact user-serving environments by validating changes on them.
As such, it's common to require a _staging_ environment to complement a _production_ environment.

Technoblather was initially built as one `terraform` stack serving as its production environment.
Given it's live and user-facing, I wanted to be able to continue to use it as a project for tinkering and learning `aws` and `terraform` without potentially impacting users.
Further, refactoring already-deployed infrastructure served as a good opportunity to learn - this task mimics real-world operational work.
So, I wanted to refactor my infrastructure-as-code configuration to facilitate two stacks for the same configuration: one for production, and one for staging.
You can take a peek at the final result [here](https://www.staging.technoblather.ca).

Two major hurdles presented themselves: I already had a live `terraform` stack with [state](https://developer.hashicorp.com/terraform/language/state), and my `terraform` declarations assumed a single environment.
So, I needed to decide how to support having multiple instances of my infrastructure deployed and managed by `terraform`, and devise a plan to migrate my existing `terraform` stack accordingly.

# What my options were

On having performed research and sleeping on it, a few viable options presented themselves:

- Leveraging `terraform`'s [workspaces](https://developer.hashicorp.com/terraform/language/state/workspaces) and deploying each environment to separate AWS accounts
- Leveraging `terraform`'s workspaces and deploying each environment to the same AWS account
- Modularizing the configuration and deploying each environment to separate AWS accounts 
- Modularizing the configuration and deploying each environment to the same AWS account

I had to make an evaluation between using workspaces or using modules to represent a deployed instance of `technoblather`, and between deploying both environments to one account or separating the environments between accounts. 

## Workspaces or modules?

While evaluating whether to use workspaces or modules, some key points of comparisons emerged: 
* the configurability and composability of the solution
* security
* the developer experience
* the amount of work involved in performing the migration.

### Configuration and composability

Workspaces would allow me to only configure one backend for my `terraform` stacks while still being able to have multiple running instances.
So, in effect, the remote state would be stored in a single file, containing the current state of production and staging.
Configuration between environments would have to be done with a ternary, e.g.: 

```terraform
some_field = terraform.workspace == "production" ? some_value : some_other_value
```

This isn't _awful_ but could get messy if we have to have lots of configuration changes between environments.

Modules would allow me to compose `technoblather` into one or more discrete units of infrastructure.
I could create a `technoblather` module, composed of `technoblather/networking`, `technoblather/monitoring`, and so on.
On a per environment basis, this would let me compose functional differences.
Moreover, since modules allow for inputs and produce output (similar to creating classes), I could tweak the configuration for common components between environments.
For example, if `technoblather` included `ec2`, one environment could run a `t1.micro` whereas another could run a `t2.large`.

### Security

Using workspaces, there is necessarily a single `.tfstate` which stores the state of the infrastructure being managed.
As a result, configuring access control between environments is impossible.
The `iam` policy responsible for pushing changes up to our backend (`s3`) can't distinguish between production and staging since both are contained in one file.

Using modules, I could create two separate `.tfstate` files for the two environments.
This meant access control between the two environments was possible via `iam` policies allowing permissions to read/push to one `tfstate` and not the other.

### Developer experience

With workspaces, what workspace you're in while doing dev work isn't immediately apparent - it's context you have to maintain as a developer.
And so, I knew it was only a matter of time before I'd push a change to production instead of staging while doing dev work.
Particularly if I had stepped away from the project for a matter of months.

With modules, I would have environments separated into folders with their respective `.tfstate`.
So, `cd`ing into the wrong folder was less likely (famous last words).

### Effort involved

Using workspaces meant setting up a new workspace with `terraform` and using the `terraform state mv` command to migrate existing production resources.

Using modules meant refactoring the `terraform` declarations into a module and using `terraform state mv` to migrate existing production resources.

### Decision

I opted to refactor my `terraform` declarations into a module and reference this module in the environments I wanted to create.
Using modules seemed to provide the best learning experience for myself while also solving both my immediate problem and the future problems I'll have while developing technoblather further.

## Multi-account or single-account?

Likewise, while evaluating whether to use a multi-account or single-account set up, some key points of comparisons emerged:
* Security
* Billing
* Developer experience

### Security

Having components operating in separate accounts nigh guarantees that an unwitting `iam` change won't have the side effect of exposing resources that ought not be exposed.
Similarly, applying distinct security controls can be simplified by using multiple accounts.
Further, an administrator can set up [service control policies](https://docs.aws.amazon.com/organizations/latest/userguide/orgs_manage_policies_scps.html) to create guard rails for child accounts in an [AWS Organizations](https://aws.amazon.com/organizations/).

However, single-accounts can still leverage roles, groups, and users via `iam` to restrict or permit permissions to resources.

### Billing

Accounts are the default catch-all "bucket" whereby costs are billed.
Using separate accounts bypasses the common confusion around cloud spend - it's obvious that a particular environment relates to a particular cloud spend.
A single account can emulate this behaviour with a consistent tagging scheme (e.g. `project => technoblather`) _but_ that requires maintenance and vigilance.

### Developer experience

Multi-account setups have a high level of overhead, even after leveraging something like [AWS Organizations](https://aws.amazon.com/organizations/).
Particularly as a solo-dev working on a hobby project, having to manage multiple fake emails (`technoblather+staging@example.com`, ...) since AWS accounts necessarily must have a unique email wasn't ideal.
Moreover, having to swap between accounts to debug or explore was unnecessary friction, particularly since I use two-factor authentication for anything that has a credit card associated with it.

Single-account thus won out here - you sign into the account and that's all there is to it. Swapping between IAM roles in a single account is seamless in comparison.

### Decision

I concede that multi-account is a best practice when real value is on the line (e.g., running a business): it is more secure, it scales better across humans and teams, resources are strongly isolated, and accidental cross-cutting changes are impossible.
However, for the scope of my project (and my sanity as a solo dev), I valued the ergonomics and tighter feedback loop of using a single-account setup. 
A more comprehensive overview of multi-account setups is [provided by AWS](https://docs.aws.amazon.com/whitepapers/latest/organizing-your-aws-environment/benefits-of-using-multiple-aws-accounts.html) if you're curious.

# A brief overview of the end result

## How I supported multiple environments for the same project

Prior to refactoring, my `terraform` declarations all lived in a single folder.
Modularizing the `terraform` declarations allowed me to split up my environments into separate folders.
Full details can be found in [technoblather's github repository](https://github.com/laaksomavrick/devblog).

```
terraform
|-- environments
|   |-- infrastructure
|   |   |-- iam.tf
|   |   |-- main.tf
|   |   |-- outputs.tf
|   |   |-- s3.tf
|   |   `-- variables.tf
|   |-- production
|   |   |-- data.tf
|   |   |-- main.tf
|   |   `-- providers.tf
|   `-- staging
|       |-- data.tf
|       |-- main.tf
|       |-- outputs.tf
|       `-- providers.tf
`-- modules
    `-- blog
        |-- acm.tf
        |-- cloudfront.tf
        |-- cloudwatch.tf
        |-- functions
        |   `-- wwwAddIndex.js
        |-- iam.tf
        |-- main.tf
        |-- outputs.tf
        |-- root_bucket.tf
        |-- route53.tf
        |-- sns.tf
        |-- templates
        |   |-- s3-private-policy.json
        |   `-- s3-public-policy.json
        |-- variables.tf
        `-- www_bucket.tf
```

The `environments` folder contains deployed environments with each subfolder having its own `terraform` state.
The state files are all stored in the same `s3` bucket with a distinct file name, e.g.:

```terraform
# terraform/environments/infrastructure/main.tf

terraform {
  backend "s3" {
    bucket         = "technoblather-terraform-states"
    key            = "infrastructure.tfstate"
    region         = "ca-central-1"
  }
}
```

The `production` and `staging` stacks are self-explanatory, and `infrastructure` provides common `aws` components for usage in both (like a `common` folder in a codebase of subprojects).
For the moment, I only extracted `technoblather` into its own module. 
If need arose, I could extract this further into subcomponents (e.g. `technoblather/networking`, `technoblather/static-site`, etc.)

## How I migrated the existing infrastructure to the new configuration

In my original setup, one `default.tfstate` existed which represented the state for the already deployed infrastructure.
I wanted to migrate this to be the `production.tfstate` and create additional terraform stacks as required.
Since the blog was extracted to a module and would be managed by a new stack, each previously deployed resource would have to be "namespaced" differently in the state file.
For example, `aws.foo` had to become `module.technoblather.aws.foo`

Two mechanisms existed for this: using the [refactoring](https://developer.hashicorp.com/terraform/language/modules/develop/refactoring) capabilities or using the [state mv](https://developer.hashicorp.com/terraform/cli/commands/state/mv) command (similar to [importing](https://developer.hashicorp.com/terraform/cli/import)).
If technoblather were shared amongst an organization, using the `moved` blocks offered by the refactoring utilities would ensure no breaking changes.
However, since I am a solo dev on this project, being able to mutate the state file was viable and meant I wouldn't litter my configuration with several `moved { ... }` blocks.
So, I wrote a small script to iterate over each resource and modify it appropriately:

```shell
RESOURCES="$(terraform state list)"

echo "$RESOURCES" | while read line ; do
   OLD_RESOURCE_STATE=$line
   NEW_RESOURCE_STATE=module.technoblather."$line"
   terraform state mv "$OLD_RESOURCE_STATE" "$NEW_RESOURCE_STATE"
done
```

Then, I renamed and moved the file in `s3` and modified the `backend` configuration for my `production` stack to point towards it.

# What I learned

## Modules are like classes

Coming from a development background, `terraform` modules map well to classes in object oriented programming.
Extracting a module results in an encapsulation of state and data for a particular set of infrastructure components.
We can provide inputs to configure the module and consume outputs which lets us create public APIs for usage in other pieces of our infrastructure.
This lets us build up a set of building blocks of abstractions that can be used across an organization or team.

For example, in the `blog` module that provisions technoblather, the "constructor" allows for configuring the domain name: 

```terraform
# terraform/environments/staging/main.tf

module "technoblather-staging" {
  source = "../../modules/blog"
  domain_name = "staging.technoblather.ca"
}
```

This DRYs up our infrastructure declarations since the behaviours surrounding provisioning DNS are encapsulated in the module.

Further, the `staging` module's output provides a public API to consume the name servers associated with its domain:

```terraform
# terraform/environments/staging/outputs.tf

output "aws_route53_zone_name_servers" {
  description = "Name servers for route53 hosted zone"
  value       = module.technoblather-staging.aws_route53_zone_name_servers
}
```

This allowed referencing components in the infrastructure similar to how a "getter" on a class would allow reading a private property.

## Leveraging simple logic for conditionally provisioning resources

Sometimes we want to provision different resources or configure the same resources differently between environments.
For example, we may not care to monitor our staging environment for uptime or want to provision less expensive resources.
One way of achieving this is composing child modules and allowing their variables to configure these properties.
However, for small changes, that can be a lot of work, particularly for already deployed resources (i.e., having to migrate all the pre-existing state).
An alternative exists that is more "light weight" for smaller differences using the `count` property in `terraform`:

```terraform
# terraform/modules/blog/iam.tf

resource "aws_iam_openid_connect_provider" "github_provider" {
  count = var.common_tags["Environment"] == "production" ? 1 : 0
  url   = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}
```

Here, if the environment is `production`, we conditionally provision a resource. 

## Variable validations

`terraform` offers functionality to validate variables.
Combined with modules, this allows for safe configuration differences via constraining strings to a known set.
For example, I wanted to write conditions for some resources based on the environment - whether the stack was staging or production.
Adding validations granted me certainty that the environment variable will be one of those two values:

```terraform
# terraform/modules/blog/variables.tf

variable "common_tags" {
  description = "Common tags you want applied to all components."
  
  type = object({
    Project     = string
    Environment = string
  })

  validation {
    condition     = var.common_tags["Environment"] == "production" || var.common_tags["Environment"] == "staging"
    error_message = "Environment must be either 'staging' or 'production'"
  }
}
```

## Refactoring existing state

As mentioned, already provisioned resources can be refactoring using `moved` blocks for non-breaking changes and `state mv` for breaking changes.

## Data can be shared across stacks

Outputs can be shared across separate `terraform` stacks via the `data` property declaration.
This meant I was able to share data between separately managed `terraform` stacks.
This facilitated having a "common" set of infrastructure each of my environments could consume for environment agnostic concerns, e.g. `iam` roles.

```terraform
# terraform/environments/production/data.tf
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = "technoblather-terraform-states"
    key    = "infrastructure.tfstate"
    region = "ca-central-1"
  }
}
```

```terraform
# terraform/environments/production/providers.tf
provider "aws" {
  region = "ca-central-1"

  assume_role {
    role_arn = data.terraform_remote_state.infrastructure.outputs.tf_production_role_arn
  }
}
```

## "common" project / nameserver staging hosted zone (DNS should live in a common project in retrospect - future refactor)

leveraging a common stack for shared resources; in retrospect should have stuck dns in there given count and remote data src wankery being kludgy - future refactor 


