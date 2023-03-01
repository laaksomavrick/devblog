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

Technoblather was initially built as one `terraform` stack serving as it's production environment.
Given it's live and user-facing, I wanted to be able to continue use it as a project for tinkering and learning without potentially impacting users on the blog.
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

### Workspaces

Workspaces would allow me to only configure one backend for my `terraform` stacks while still being able to have multiple running instances.
So, in effect, `technoblather` would have one `.tfstate` file with multiple instances in it.
The ergonomics around this were driven via `terraform`'s cli, for example: `terraform workspace list`.

However, configuring differences between the two environments would become tricky (if not impossible).
Workspaces don't facilitate any functionality for composition - the `terraform` code is necessarily identical.
Having differences between environments would require plumbing ternaries into my configurations, for example:

```terraform
some_field = terraform.workspace == "production" ? some_value : some_other_value
```

Further, what workspace you're in while doing dev work isn't immediately apparent - it's context you have to maintain as a developer.
And so, I knew it was only a matter of time before I'd push a change to production instead of staging while doing dev work.
Particularly if I had stepped away from the project for a matter of months.

And finally, since there is necessarily a single `.tfstate` file with workspaces, configuring access control across environments is impossible.
The `iam` policy responsible for pushing changes up to our backend (`s3`) can't distinguish between production and staging.

### Modules

Modules would allow me to compose `technoblather` into one or more discrete units of infrastructure.
I could create a `technoblather` module, composed of `technoblather/networking`, `technoblather/monitoring`, and so on.
On a per environment basis, this would let me compose functional differences.
Moreover, since modules allow for inputs and produce output (similar to creating classes), I could tweak the configuration for common components between environments.
For example, if `technoblather` included `ec2`, one environment could run a `t1.micro` whereas another could run a `t2.large`.

Composing environments with modules also felt more explicit.
Two `tfstate` files were required, one for production, another for staging.
This meant separate folders, and `cd`ing into the wrong folder was less likely (famous last words).
Further, access control between the two environments was solvable via `iam` policies allowing permissions to read/push to one `tfstate` and not the other.

Sharing information between environments was trickier. Later on I'll detail how I solved this.
Modules also meant more work - I had to get into the weeds of refactoring the `terraform` declarations and the live `tfstate` file.

### Decision

=> conclusion, i opted for modules

Given the 

## Multi-account or single-account?

# Explanation and pro/con of each

# The decision made

# A walkthrough of the implementation

# What does my day-to-day flow look like now?

# Gotchas / things of note / things I learned
## tf modules (relate to classes and objects from programmer pov)
## tf conditionals
## tf validations for variables
## state mv refactoring
## nameserver staging hosted zone (DNS should live in a common project in retrospect - future refactor)
## extracting tfstate into projects / project structure
## tf remote data src


