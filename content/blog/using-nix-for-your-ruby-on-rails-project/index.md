---
title: Using Nix for Your Ruby on Rails Project Development Environment
date: "2023-05-14T00:00:00.000Z"
description: Reduce developer friction and gain quick and reproducible CI builds with Nix and GitHub Actions
---

Recently, a new colleague onboarded onto one of our projects.
All of our devs were running Intel-based (`x86`) Macs for their client machines.
Our new colleague was running a new M1-based (`arm`) Mac. 
Because of this, setting up the project on their machine went from an assumed trivial task with `docker` to a week-long process.
Whether you've been the onboarder, the onboardee, or just have too many machines lying around, you've probably experienced a similar situation.

I've been focusing on shoring up my DevOps toolkit lately and wanted to explore using [Nix](https://nixos.org/).
This seemed like a perfect use case to solve a problem for our developer experience and learn something new.

## What is Nix?

There is a lot of technoblather-jargon around Nix since it's a new technology and a rapidly evolving ecosystem.
I will try to speak to it in terms of how it's useful instead of how or why it works.
Note: I am still learning the tool and its ecosystem so allow me thoughts from my brief experience.

Nix is a language, a package manager, and system configuration tool.
We can use the `nix` language to author declarative files that specify configurations for our systems and their environments.
The package manager guarantees installed package versions will not collide, reducing side effects from package upgrades or deprecations.
You can have one or more configurations present on an operating system - a colleague compared it to being like `virtualenv` and `brew` combined in terms of its utility.

So, we can have one project set up with `ruby`, `docker`, `postgres`, and `git` with their exact versions and another with the same tools but different versions.
Changes to the former project (e.g. upgrading `ruby`) will not affect or break the others.
Moreover, when it comes time to deploy this project in a new environment, we can leverage the same tooling to guarantee the exact same environment.
This solves a huge problem: no more stating "it works on my machine" to our colleagues and stakeholders and instead focusing on delivering functionality versus debugging environment differences.


## Great - what does that look like for my Ruby on Rails project?

set it up for your local environment

    call out explicitly installing rspec
    call out explicitly installing foreman + modifying /bin/dev + modifying Procfile.dev

## Going further, how can we leverage this in our CI environment?
set it up on CI


    call out using flakes + ~/nix store
    call out pg-config-path

outro

    nix is cool
    can use to declaratively manage your laptop setup
    can use to manage your dev environments
    can use to manage your servers
    can use to distribute binaries across teams via a binary store (speed up builds)