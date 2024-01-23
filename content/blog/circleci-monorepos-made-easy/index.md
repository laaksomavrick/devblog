---
title: CircleCI Monorepos Made Easy: Wrangle Your CI/CD Setup with These Tips
date: "2024-01-23T00:00:00.000Z"
description: Monorepos offer many benefits for developer experience but come with their own caveats. Explore a few tips and tricks for setup using CircleCI.
---

## Preamble

Right off the bat, I will admit: CircleCI is not my favorite CI/CD tool.
There has been an explosion of new-generation tooling that _isn't_ all hype in this product space which has presented improved ergonomics, functionality, and pricing for developers compared to CircleCI.

However, sometimes, the correct choice isn't what we want but what we have.
For my current engagement, the client had dozens of repositories successfully validating pull requests and deploying changes into their respective environments.

I was tasked with setting up a new repository and change management processes to support an enterprise-ready data engineering and machine learning platform.
Given the client's longstanding familiarity with CircleCI as a platform and the task at hand, a monorepo seemed a suitable choice for encouraging code sharing and enforcing a consistent set of practices across business units.

And so, dear reader, I have identified and navigated all the foot-guns and false-starts so that you may learn from my begrudging, grumbling hours spent accomplishing this task.

## The project structure

To begin, let's imagine a repository with the following structure:

```shell
$ tree -a myproject
myproject
├── .python-version
├── __init__.py
├── common
│   ├── common
│   │   └── __init__.py
│   ├── poetry.lock
│   └── pyproject.toml
├── poetry.lock
├── poetry.toml
├── pyproject.toml
├── subproject_one
│   ├── Dockerfile
│   ├── poetry.lock
│   ├── pyproject.toml
│   └── subproject_one
│       └── __init__.py
└── subproject_two
    ├── Dockerfile
    ├── poetry.lock
    ├── pyproject.toml
    └── subproject_two
        └── __init__.py
```

Two projects (`subproject_one`, `subproject_two`) are independently deployable services, both of which consume a `common` package of library-level code.
I wanted to orchestrate a CI/CD pipeline such that merging changes to our `main` branch would automatically deploy to staging, and that deploying changes to a `prod` branch would automatically deploy to production.
Further, I had build and validation steps that were common to all three directories _and_ build, validation, and deployment steps that were unique to each directory.
Nothing exotic here - for example, I might run a linter across all files and I might build an image for `subproject_one` to a particular Docker repository that is different from `subproject_two`. 

## Don't fight their APIs

My initial inclination was to create three configuration files. 
One for tasks that might be common across all projects, for example, running the tests across a project or validating that the code is properly formatted.
And two others, each corresponding to our subprojects, where we could place logic specific to those projects.

I recognized that this [was not the official recommendation](https://circleci.com/docs/using-dynamic-configuration/) but attempted this (for a time) anyway.
Orbs (CircleCI's word for packages) bundle functionality to 1) filter based on paths and 2) invoke a "continuation" of a pipeline in order to run another file.
These _can_ be stitched together to [create separate files for each project](https://github.com/laaksomavrick/path-filtering-custom-config/tree/main), and I did this for a time.
However, I would not recommend it, and I migrated away from this approach.
It was finicky, error-prone, and a maintenance nightmare.

CircleCI's [dynamic configuration](https://circleci.com/docs/dynamic-config/) prescribes creating two files: a `config.yml`, where we can author jobs common to all projects and invoke our project-based workflows, and a `continuation_config.yml`, where we can author our project-based jobs and workflows.
You may be wondering: but won't that become a huge mess of a file?
Particularly if many subprojects are present in our monorepo, one file containing many mixed concerns would make most software engineers eager to refactor.

It _could_ become a huge mess of a file, but there are a few techniques we can use to keep it modular, DRY (don't-repeat-yourself), and maintainable.

## So where does that leave us?

First, we need a directory for our CircleCI configuration files and have to note a few particularities. 

```shell
├── .circleci
│   ├── config.yml
│   └── continue_config.yml
```

Your `config.yml` file must include a `setup: true` block alongside some [CircleCI-specific configuration](https://circleci.com/docs/dynamic-config/).
From there, I found a few tools in CircleCI's toolbox to accomplish our task.

## Use the path-filtering orb, Luke

CircleCI's [path filtering orb](https://circleci.com/developer/orbs/orb/circleci/path-filtering) provides functionality for continuing a pipeline based on the paths of changed files.
Using the `mapping` parameter, we can pass values to variables in our continuation configuration for usage in workflow `when` clauses, providing a mechanism for triggering particular workflows.
In practice, this will look like:

```yaml
version: 2.1

setup: true

orbs:
  path-filtering: circleci/path-filtering@1.0.0

jobs:
  validate-source-code:
    steps:
      ...

workflows:
  always-run:
    jobs:
      - validate-source-code
      - path-filtering/filter:
          name: check-updated-files
          mapping: |
            common/.* run-common-workflow true
            subproject_one/.* run-subproject-one-workflow true
            subproject_two/.* run-subproject-two-workflow true
          base-revision: main
          config-path: .circleci/continue_config.yml
```

```yaml
parameters:
  run-common-workflow:
    type: boolean
    default: false
  run-subproject-one-workflow:
    type: boolean
    default: false
  run-subproject-two-workflow:
    type: boolean
    default: false

...

workflows:
  subproject-one:
    when:
      or:
        - equal: [true, << pipeline.parameters.run-subproject-one-workflow >>]
        - equal: [true, << pipeline.parameters.run-common-workflow >>]
    jobs:
      ...
  subproject-two:
    when:
      or:
        - equal: [ true, << pipeline.parameters.run-subproject-two-workflow >> ]
        - equal: [true, << pipeline.parameters.run-common-workflow >>]
    jobs:
      ...
```

Notably, this provided the flexibility to run all workflows when a change occurred in `common` and only run a particular workflow when changes occurred in its subdirectory. 

## Keep things DRY with the tooling available

YAML isn't a programming language, but it is a declarative configuration language with not-often explored advanced features.
Some of my favorite features to use are _anchors_, _aliases_, and [merge keys](https://yaml.org/type/merge.html).
Combined, they allow us to author re-usable snippets in our CircleCI template (and most `yaml` documents in general):

```yaml
common_settings: &common_settings
  executor:
    name: python/default
    tag: 3.10.8

subproject_one_common_settings: &subproject_one_common_settings
  working_directory: ~/myproject/subproject_one
  <<: *common_settings
  
...

jobs:
  subproject-one-validate:
    <<: *subproject_one_common_settings
    steps:
      - myproject-checkout
      - install-acme-cli
      - validate

```

So, if you have repeated snippets of orchestration (and you likely do, given you're working in a monorepo), creating a common block of configuration,
anchoring it, and then using that anchoring via aliases and merge keys allow us to write it once and run it everywhere, DRYing up your configuration file. 

## Use filters for branch-based logic

I am more familiar with the GitHub Actions style [workflow triggers](https://docs.github.com/en/actions/using-workflows/events-that-trigger-workflows) to invoke particular workflows
based on branch conditions. 
CircleCI offers similar functionality via [filters](https://circleci.com/docs/configuration-reference/#filters).
For our example project, I wanted to create three different workflows based on branching.
First, for every pull request and merge, I wanted to run some common tasks (e.g., validate the change has no syntax errors).
Second, when a change was merged to `main`, and had no git tag, I wanted to deploy it to a staging environment.
Third, when a change was merged to `prod` and had a tag of the form `v$.$.$`, e.g. `v1.0.0`, I wanted to deploy it to the production environment.

In practice, this looks like:

```yaml
stg-filters: &stg-filters
  filters:
    branches:
      only: main
    tags:
      ignore: /.*/

prod-filters: &prod-filters
  filters:
    branches:
      only: prod
    tags:
      only: /^v.*/

...

workflows:
  subproject-one:
    jobs:
      - subproject-one-validate
      - subproject-one-deploy-stg:
          requires:
            - subproject-one-validate
          <<: *stg-filters
      - subproject-one-deploy-prod:
          requires:
            - subproject-one-validate
          <<: *prod-filters
```

Combined with the aforementioned anchoring, aliasing, and merge keys, we can compose a common set of branch-based rules to use in our workflows for each subproject included in our monorepo.

## Don't be afraid to offload complex logic into scripts

If you're struggling to fit a complicated step into your job or workflow declarations, offload that logic into a script.
This can be authored with bash, or even your favorite programming language, for example:

```shell
#!/usr/bin/env python
import os

NAME = os.environ["NAME"]

print(f"Hello, {NAME}!")
```

```yaml
jobs:
  - run:
      name: Invoke your complicated logic
      command: ~/myproject/.circleci/my_script.sh
      environment:
        NAME: Bob
```

For my purposes, this was helpful to orchestrate a sequence of steps that required the usage of an API client given my target did not have a CircleCI orb available.
I know I would rather debug a python script than a hobbling of bash in a CI configuration file when it inevitably breaks.

## RTFM!

This sounds naive, but consulting the [official documentation](https://circleci.com/docs/configuration-reference/) for a CircleCI configuration file proved to be the best source of information while exploring the tools available.
Further, it informed me of what options were available to me and provided brief examples for their implementation.
Googling for answers tended to lead to outdated community answers.
And using ChatGPT for CircleCI was often flat-out wrong.
So, in this instance, doing things the old-fashioned way paid the most dividends.