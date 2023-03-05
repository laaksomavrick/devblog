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
Further, refactoring already-deployed infrastructure served as a good opportunity to learn - this task could happen in real-world operational work.
So, I needed to refactor my infrastructure-as-code configuration to facilitate two stacks for the same configuration: one for production, and one for staging.
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

The `environments` folder contains deployed environments, each subfolder having its own `terraform` state.
`production` and `staging` are self-explanatory, and `infrastructure` provides common `aws` components for usage in both (like a `common` folder in a codebase of subprojects).
For the moment, I only extracted `technoblather` into its own module. If need arose, I could extract this further into subcomponents (e.g. `technoblather/networking`, `technoblather/static-site`, etc.)

# Gotchas / things of note / things I learned
## tf modules (relate to classes and objects from programmer pov)
## tf conditionals
## tf validations for variables
## state mv refactoring
## nameserver staging hosted zone (DNS should live in a common project in retrospect - future refactor)
## extracting tfstate into projects / project structure
## tf remote data src


