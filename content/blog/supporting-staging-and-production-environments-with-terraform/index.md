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

I had to make an evaluation between using workspaces versus modules, and between deploying to one account versus multiple accounts.

## Workspaces or modules?

To use workspaces, I'd have to:
- create two new workspaces: `production` and `staging`
- migrate my existing `default` workspace to `production`
- plumb `terraform.workspace == "production" ? something : else` for configuration differences between environments 
- remember what environment I was in while doing development

paragraph with brief overview of workspaces

=> Pro: Could support two environments with one backend; would mean configuration wouldn't have to drastically differ
=> Con: meant differences between the two environments would be a PITA; tf config not composable; what workspace you're in not explicit; one tfstate so discrete access control not possible

Extracting the configuration to a module would result in:
- Refactor the existing configuration into a module
- Creating two new stacks referencing the module (with separate backends)
- Migrate existing state into one of the new modules

paragraph with brief overview of modules

=> Pro: composable between environments; explicit when doing dev what env you're in; access control between state possible (e.g. local devs could be read-only for prod but read/write for staging)
=> Con: remote data src required for references between environments; more work

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


