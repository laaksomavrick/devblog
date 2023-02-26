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

- Workspaces
- Multi account AWS setup
- Modularize + separate stacks 

# Explanation and pro/con of each

# The decision made

# A walkthrough of the implementation

# What does my day-to-day flow look like now?

# Gotchas / things of note / things I learned
## tf modules (relate to classes and objects from programmer pov)
## tf conditionals
## tf validations for variables
## state mv refactoring
## nameserver staging hosted zone
## extracting tfstate into projects / project structure
## tf remote data src


