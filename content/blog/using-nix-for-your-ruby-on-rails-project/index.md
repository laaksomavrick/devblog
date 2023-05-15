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

To begin, you'll need to get Nix installed on your machine, enable [flakes](https://nixos.wiki/wiki/Flakes), and install `direnv`.

See [this blog post from a colleague](https://blog.testdouble.com/posts/2023-05-02-frictionless-developer-environments/) for a good explanation of the steps and their reasoning.

If you're feeling lazy, the commands to run are:
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

Now, let's create our first `flake` and configure `direnv` to automatically use it.
All code referenced can be found in [a hobby project](https://github.com/laaksomavrick/ownyourday.ca) I am currently working on if you'd like to explore.

Create a file called `.envrc` in the project root and add this line:

```sh
# .envrc

use flake
```

This integrates `direnv` to install and use our Nix packages in a shell when we enter this directory automatically.

Next, create a file called `flake.nix` in the project root and configure it appropriately.
In my Rails project, I am using `postgres` for the database, `node` for running the JavaScript toolchain, `pnpm` for the JavaScript toolchain package manager, and `ruby3.1.0` for the `ruby` version.
Further, I specify `docker`, `git`, and `make` given all are involved in the operation of the developer environment for the project.

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

Observe that entering our project now installs all the specified packages and generates a `flake.lock` file.
To verify we're using the Nix binaries, run `which ruby` and observe:

```
/nix/store/6m71ianr78w8lgbrgzq04wfp7w67hc50-ruby-3.1.2/bin/ruby
```

Great! If we push this up to version control, we can be certain our teammates will be using the same dependencies as us.
Moreover, if we are working on multiple projects at a time, we can be sure changes in one project's dependencies won't affect the other (such as upgrading a globally installed `gem`).

### Errors I encountered

#### Rspec

I was seeing gem incompatibility errors when trying to run tests locally.
My Rails project uses `rspec`, so I assumed something was up between `rbenv` and `nix`.
Sure enough:

```sh
~/code/personal/ownyourday main $ which rspec
/Users/mav/.rbenv/shims/rspec
```

This was solved by explicitly adding `rspec` to the project's `Gemfile` so that calling `rspec` didn't delegate to globally installed gems.

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

Similarly, my project uses `tailwindcss` which sets up a `watch` using `foreman` to rebuild `css` on file changes.
When trying to serve my application via `/bin/dev`, I encountered the following error:

```sh
bundler: failed to load command: foreman (/Users/mav/.gem/ruby/3.1.0/bin/foreman)
/Users/mav/.gem/ruby/3.1.0/gems/bundler-2.3.7/lib/bundler/rubygems_integration.rb:319:in `block in replace_bin_path': can't find executable foreman for gem foreman. foreman is not currently included in the bundle, perhaps you meant to add it to your Gemfile? (Gem::Exception)
```

Solving it required explictly installing `foreman` and changing the `/bin/dev` and `Procfile.dev` commands to use locally installed packages:

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

Since a major advantage of using Nix is its reproducibility, we should use it for our CI environment as well.
In my project, I am using GitHub Actions, so I will detail how my continuous integration pipeline is set up using Nix.

```yml
# .github/workflows/ci.yml

name: CI

on:
  pull_request:
    branches: [ main ]

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
          # By default this should be /nix/store, but we can't restore to /nix/store due to permissions in GH actions
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

Let's explain this pipeline.

In the happy path, the Ruby on Rails application is being built with its dependencies and a set of verifications are being run on the code.
We are making sure no secrets are present in the code, the code is well formatted, the code is linted, and all of our tests are passing.

Installing the system dependencies is delegated to Nix. 
This is identical to our local environment.
So, as an example, we know that both our local environment and CI environment have the same version of `ruby`. 

As it pertains to our dependencies, we cache them to speed up subsequent CI runs.
A hash of the respective lockfiles for Nix, Ruby, and JavaScript are used as the cache key - if a lockfile is changed, a dependency has changed, so we should break the cache. 

### Errors I encountered

#### Permissions and the /nix/store

Nix stores its binary store at `/nix/store` by default.
When trying to restore this in CI, I observed permissions errors on trying to restore the nix cache to that location.
The GitHub actions runner has its own user that does not have permissions to restore to that path.
There [is a workaround](https://github.com/actions/cache/issues/749#issuecomment-1465302692) which you can observe from the CI declaration.
Storing the nix binary storage in a path the GitHub actions user can modify (e.g. `~/nix/store`) circumvents this problem.

#### The pg gem and its implied dependencies 

The `pg` gem required by Rails to connect to postgres assumes dependencies on the local system:

```shell
# from a ci run

Run nix-shell --run 'bundler exec rails assets:clean assets:precompile'
rails aborted!
LoadError: libssl.so.3: cannot open shared object file: No such file or directory - /home/runner/.local/share/gem/ruby/3.1.0/gems/pg-1.4.6/lib/pg_ext.so
```

While debugging what was going on, I noticed that `which pg_config` was pointing towards `/usr/bin/pg_config`.
We can configure `bundle` to use the correct Nix managed `pg_config` to resolve this via `bundle config build.pg`:

```shell
#.bundle/config

---
BUNDLE_BUILD__PG: "--with-pg-config=/nix/store/c4j1gfn0m9i3540ni3az2a9jjnlgyg81-postgresql-11.18/bin/pg_config"
```

Pointing `pg` at the correct `pg_config` resolved the issue. 

## In sum

Nix may seem daunting at the beginning.
It's new tech and part of a rapidly evolving ecosystem.
To grok it effectively, I found it helpful to focus on its instrumentality instead of its theory - hence this blogpost.
I've only scratched the surface of its capabilities so feel free to explore.
There are things that could still be improved in this local environment and pipeline - docker is managing postgres still as an example.
In the future, I would be interested in using Nix to manage my project environments and expand beyond that to other use cases (for example, managing my development environment tooling such as `git`, `tmux`, and so on).
I'm hoping you found takeaways from me writing about my experience using it for a Ruby on Rails project.