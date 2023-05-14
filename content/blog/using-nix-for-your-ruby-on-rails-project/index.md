---
title: Using Nix for Your Ruby on Rails Project Development Environment
date: "2023-05-14T00:00:00.000Z"
description: Reduce developer friction and gain quick and reproducible CI builds with Nix and GitHub Actions
---

preamble around local env setup (works on my machine)

what is nix

set it up for your local environment

    call out explicitly installing rspec
    call out explicitly installing foreman + modifying /bin/dev + modifying Procfile.dev

set it up on CI

    call out using flakes + ~/nix store
    call out pg-config-path