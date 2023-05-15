---
title: Using Nix for Your Ruby on Rails Development Environment
date: "2023-05-14T00:00:00.000Z"
description: Reduce developer friction and gain reproducible builds for your Ruby on Rails projects with Nix and GitHub Actions.
---

## A brief anecdote

Developers come and go with client-oriented work, and with that, there is generally a prescribed process for getting projects running on their machines honed with each departure and addition.

Recently, a new colleague was onboarded onto one of our projects.
All of our devs were running Intel-based (`x86`) Macs for their client machines.
Our new colleague was running an M1-based (`arm`) Mac.
Because of this, setting up the project on their machine went from an assumed trivial task with `docker` to a week-long process.
This is frustrating and is not a great use of time nor an enjoyable one when you want to have developers hit the ground running and start producing.

Whether you've been the onboarder, the onboardee, or just have too many machines lying around, you've probably experienced a similar situation.

I've been focusing on shoring up my DevOps toolkit lately and wanted to explore using [Nix](https://nixos.org/) given the surrounding buzz.
This situation seemed like a perfect use case to solve a problem with our developer experience and learn something new.

## What is Nix?

There is a lot of techno-jargon around Nix since it's a new technology and a rapidly evolving ecosystem.
I will try to speak to it in terms of how it's useful instead of how or why it works.
The subsequent Rails project setup documented below provides a practical example of the tool.
However, I am still learning it and its ecosystem so assume an asterisk around my claims - email me if I've gotten something wrong.

Nix is a language, a package manager, and system configuration tool.
We can use the `nix` language to author declarative files (`*.nix`) that specify a configuration for our systems and their environments.
The package management functionality guarantees installed package versions will not collide, reducing side effects from package upgrades or deprecations.
We can have one or more configurations present on an operating system - a colleague compared it to being like `virtualenv` and `brew` combined in terms of its utility.

So, we can have one project set up with `ruby`, `docker`, `postgres`, and `git` with their exact versions and another with the same tools but different versions.
Changes to the former project (e.g., upgrading `ruby`) will not affect or break the others.

Moreover, when it comes time to deploy this project in a new environment, we can leverage the same tooling to guarantee the exact same environment.
This solves a huge problem: no more stating "it works on my machine" (and spending time debugging environment differences) to our colleagues and stakeholders and instead focusing on delivering functionality.

Further, with client work, project hand-offs are simplified for whomever ends up responsible for the work we've done: indicate in a `README` to install Nix and delegate handling project dependency installation and configuration to the tool.

## Great - what does that look like for my Ruby on Rails project?

First, all code referenced in this blog post can be found in [my hobby project ownyourday](https://github.com/laaksomavrick/ownyourday.ca).

To begin, you'll need to get Nix installed and configured on your machine.
See [this blog post from a colleague](https://blog.testdouble.com/posts/2023-05-02-frictionless-developer-environments/) for a good explanation of the steps and their reasoning.

If you're feeling lazy, the commands to run (from aforementioned blog post) are:

```shell
# enable nix flakes
mkdir -p "$HOME/.config/nix"
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

# install nix
sh <(curl -L https://nixos.org/nix/install)

# install direnv
nix profile install nixpkgs#direnv
echo 'eval "$(direnv hook zsh)"' >> "$HOME/.zshrc"

# then restart your shell and cd into your ruby-on-rails project directory
direnv allow
```

Now, let's create our first [flake](https://nixos.wiki/wiki/Flakes) and configure [direnv](https://direnv.net/) to automatically use it.

Create a file called `.envrc` in the project root and add this line:

```sh
# .envrc

use flake
```

This integrates `direnv` to install and use our Nix packages in a shell when we enter this directory via the `flake` we're about to write.

Next, create a file called `flake.nix` in the project root and configure it appropriately.
In my Rails project, I am using `postgres` for the database, `node` for running the JavaScript toolchain, `pnpm` for the JavaScript toolchain package manager, and `ruby3.1.0` for the `ruby` version.
Further, I specify `docker`, `git`, and `make` given all are involved in the operation of the developer environment for the project.
To find additional packages, visit [this resource](https://search.nixos.org/packages?channel=22.11&from=0&size=50&sort=relevance&type=packages).

```nix
# flake.nix

{
  description = "Developer environment shell for ownyourday";

  inputs = {
    nixpkgs = {
      owner = "NixOS";
      repo = "nixpkgs";
      # 22.11
      rev = "e6d5772f3515b8518d50122471381feae7cbae36";
      type = "github";
    };
  };

  outputs = { self, nixpkgs }:
    let
      # Helper to provide system-specific attributes
      forAllSupportedSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });

      supportedSystems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-darwin"
        "x86_64-linux"
      ];
    in

    {
      devShells = forAllSupportedSystems ({ pkgs }: {
        default = pkgs.mkShell {
          packages = [
            pkgs.docker
            pkgs.git
            pkgs.gnumake
            pkgs.nixpkgs-fmt
            pkgs.nodejs
            pkgs.nodePackages.pnpm
            pkgs.postgresql_11
            pkgs.ruby_3_1
          ];
        };
      });
    };
}

```

Observe that `cd`ing to the project directory now installs all the specified packages and generates a `flake.lock` file.
To verify we're using the Nix binaries run `which ruby` and observe:

```sh
~/code/personal/ownyourday main $ which ruby
/nix/store/6m71ianr78w8lgbrgzq04wfp7w67hc50-ruby-3.1.2/bin/ruby
```

Great! If we push this up to version control, we could be certain our teammates would be using the same dependencies as us.
Moreover, if we are working on multiple projects at a time, we can be certain changes in one project's dependencies won't affect the other (e.g., upgrading a globally installed `gem` like `rails`).

### Some hiccups along the way

#### Rspec

When running tests locally, I observed `gem` incompatibility errors (the exact errors are long-lost in my terminal history).
The Rails project uses `rspec` as its test runner, so I assumed something was up between `rbenv` and `nix`.

Sure enough:

```sh
~/code/personal/ownyourday main $ which rspec
/Users/mav/.rbenv/shims/rspec
```

This was solved by explicitly adding `rspec` to the Rails project's `Gemfile` such that invoking `rspec` wouldn't delegate to globals:

```ruby
# Gemfile

...

group :development, :test do
  ...
  gem 'rspec', '~> 3.12.0'
  ...
end

...

```

#### Tailwind

Similarly, the Rails project uses `tailwindcss-rails` which sets up a watch-and-rebuild cycle using `foreman` on file changes that affect styling.
When trying to serve the application via `/bin/dev` (or `make serve` in my case), I encountered the following error:

```sh
~/code/personal/ownyourday main $ make serve
bundler: failed to load command: foreman (/Users/mav/.gem/ruby/3.1.0/bin/foreman)
/Users/mav/.gem/ruby/3.1.0/gems/bundler-2.3.7/lib/bundler/rubygems_integration.rb:319:in `block in replace_bin_path': can't find executable foreman for gem foreman. foreman is not currently included in the bundle, perhaps you meant to add it to your Gemfile? (Gem::Exception)
```

Solving it required explicitly installing `foreman` in the `Gemfile` alongside modifying the out-of-the-box `/bin/dev` and `Procfile.dev` commands to use locally installed packages:

```ruby
# Gemfile

...

group :development do
  ...
  gem 'foreman'
  ...
end
...

```

```sh
# bin/dev

#!/usr/bin/env sh
bundler exec foreman start -f Procfile.dev "$@"
```

```sh
# Procfile.dev

web: bundler exec rails server -p 3000
css: bundler exec rails tailwindcss:watch
```

## Going further, how can we leverage this in our CI environment?

Since a major advantage of using Nix is its build-reproducibility, we should use it for our continuous integration environment as well.
In the Rails project, GitHub Actions is used.
So, lets take a look at how the CI pipeline is set up with Nix:

```yml
# .github/workflows/ci.yml

name: CI

on:
  pull_request:
    branches: [main]

env:
  IS_CI: true
  NIX_STORE_PATH: ~/nix
  PGHOST: localhost
  POSTGRES_DB: rails_github_actions_test
  POSTGRES_PASSWORD: postgres
  POSTGRES_USER: rails_github_actions
  RAILS_ENV: test

jobs:
  verify:
    name: Verify pull request
    runs-on: ubuntu-latest

    services:
      postgres:
        env:
          POSTGRES_USER: ${{ env.POSTGRES_USER }}
          POSTGRES_DB: ${{ env.POSTGRES_DB }}
          POSTGRES_PASSWORD: ${{ env.POSTGRES_PASSWORD }}
        image: postgres:11
        ports: ["5432:5432"]
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v1

      - name: Install Nix
        uses: cachix/install-nix-action@v19

      - name: Cache Nix
        id: cache-nix
        uses: actions/cache@v3
        env:
          cache-name: cache-nix-store
        with:
          # By default, this should be /nix/store, but we can't restore to /nix/store due to permissions in GH actions
          # So, set this to somewhere else (e.g. ~/nix) that the runner user can write
          # And specify this location in subsequent nix commands
          # See https://github.com/actions/cache/issues/749#issuecomment-1465302692
          path: ${{ env.NIX_STORE_PATH }}
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('flake.lock') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-

      - name: Cache Ruby gems
        id: cache-ruby
        uses: actions/cache@v3
        env:
          cache-name: cache-ruby-store
        with:
          path: ./vendor/bundle
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('Gemfile.lock') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-

      - name: Cache JavaScript packages
        id: cache-js
        uses: actions/cache@v3
        env:
          cache-name: cache-js-store
        with:
          path: ~/.local/share/pnpm/store
          key: ${{ runner.os }}-build-${{ env.cache-name }}-${{ hashFiles('pnpm-lock.yaml') }}
          restore-keys: |
            ${{ runner.os }}-build-${{ env.cache-name }}-

      - name: Install Nix binaries
        run: nix --store ${{ env.NIX_STORE_PATH }} develop .

      # Required for pg gem dependencies - we don't want to use /usr/bin/pg_config but the nix binary instead
      # For the next step (Install Ruby dependencies)
      - name: Set pg_config path for installing pg gem
        id: pg-config-path
        run: echo "PG_CONFIG_PATH=$(nix --store ${{ env.NIX_STORE_PATH }} develop . --command which pg_config)" >> $GITHUB_OUTPUT

      - name: Install Ruby dependencies
        run: |
          nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle config build.pg --with-pg-config=${{ steps.pg-config-path.outputs.PG_CONFIG_PATH }} && \
          nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle config path vendor/bundle && \
          nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle install --jobs 4 --retry 3

      - name: Install JavaScript dependencies
        run: |
          nix --store ${{ env.NIX_STORE_PATH }} develop . --command pnpm install --frozen-lockfile --strict-peer-dependencies

      - name: Setup assets
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundler exec rails assets:clean assets:precompile

      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Check Ruby formatting
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundler exec rubocop --fail-level=warning

      - name: Check JavaScript formatting
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command pnpm run format:check

      - name: Check JavaScript lint
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command pnpm run lint

      - name: Run JavaScript tests
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command pnpm run test

      - name: Setup test database
        run: |
          cp config/database.ci.yml config/database.yml
          nix --store ${{ env.NIX_STORE_PATH }} develop . --command rake db:create db:schema:load

      - name: Run Ruby tests
        run: nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundler exec rspec
```

In the happy path, the Ruby on Rails application is being built with its dependencies and a set of verifications are being run on the code.
We are making sure the project can build, no secrets are present in the code, the code is well formatted, the code is linted, and all the tests are passing.

Installing the system dependencies is delegated to Nix.
This is identical to the local environment set up previously because of the `flake.nix` configuration.
So, as an example, we know that both the local environment and CI environment have the same version of `ruby`.

The pipeline also caches installed dependencies to speed up subsequent CI runs.
A hash of the respective lockfiles for Nix, Ruby, and JavaScript are used as the cache key - if a lockfile is changed, a dependency has changed, so the cache should be broken.
Otherwise, don't bother re-downloading and reinstalling the dependencies - back them up from the GitHub actions cache instead.

### Some more hiccups along the way

#### Permissions and the /nix/store

Nix stores binaries in `/nix/store` by default.
When cached binaries were present for the lockfile hash, the CI user would try to restore binaries to that path.
Makes sense.

However, this was triggering permissions errors.
The GitHub actions runner has its own user that does not have permissions to restore to that path.
There [is a workaround](https://github.com/actions/cache/issues/749#issuecomment-1465302692) which can be observed from the CI declaration.
Storing the nix binary storage in a path the GitHub actions user can modify (e.g. `~/nix/store`) circumvents this problem.

However, this meant I had to use `flakes` instead of `nix-shell` and that the Nix CI steps are littered with a `--store` argument.

#### The pg gem and its implied dependencies

The `pg` gem required by Rails to connect to postgres assumes dependencies on the local system:

```shell
# from a ci run

Run nix-shell --run 'bundler exec rails assets:clean assets:precompile'
rails aborted!
LoadError: libssl.so.3: cannot open shared object file: No such file or directory - /home/runner/.local/share/gem/ruby/3.1.0/gems/pg-1.4.6/lib/pg_ext.so
```

While debugging what was going on, I noticed that `which pg_config` was pointing towards `/usr/bin/pg_config`.
Given all the commands were running in a Nix configured shell, `/usr/bin/pg_config` was empty, since postgres was installed via Nix.
So, configuring `bundle` to use the correct Nix managed `pg_config` resolved this.

This creates a local file that looks like:

```shell
#.bundle/config

---
BUNDLE_BUILD__PG: "--with-pg-config=/nix/store/c4j1gfn0m9i3540ni3az2a9jjnlgyg81-postgresql-11.18/bin/pg_config"
```

Given this, observe the following pipeline steps:

```yml
# Required for pg gem dependencies - we don't want to use /usr/bin/pg_config but the nix binary instead
# For the next step (Install Ruby dependencies)
- name: Set pg_config path for installing pg gem
  id: pg-config-path
  run: echo "PG_CONFIG_PATH=$(nix --store ${{ env.NIX_STORE_PATH }} develop . --command which pg_config)" >> $GITHUB_OUTPUT

- name: Install Ruby dependencies
  run: |
    nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle config build.pg --with-pg-config=${{ steps.pg-config-path.outputs.PG_CONFIG_PATH }} && \
    nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle config path vendor/bundle && \
    nix --store ${{ env.NIX_STORE_PATH }} develop . --command bundle install --jobs 4 --retry 3
```

Pointing `pg` at the correct `pg_config` resolved the issue.

## In sum

Nix may seem daunting at the beginning - and it is.
It's a new technology and accordingly part of a rapidly evolving ecosystem.
To grok it effectively, I found it helpful to focus on its instrumentality instead of its theory - hence this blogpost.

Going forward, I am optimistic about its adoption and its capabilities to improve the reliability of features we ship and the developer experience for new and existing projects.

I hope you've been able to learn something by following along with my journey to use it to improve the developer experience of a Ruby on Rails project.
If you have any feedback, feel free to email me via the "contact him here" at the bottom of the page.
