---
title: Running Ruby on Rails System Tests in Github Actions
date: "2023-03-25T00:00:00.000Z"
description: Learn how to configure Ruby on Rails and Capybara to utilize headless Chrome in your CI pipeline.
---

Any software development project will benefit from automated testing, and running those automated tests from a pipeline ensures new functionality isn't broken or breaking other parts of the system.
For Ruby on Rails applications, system tests provide end-to-end validation of application features by running a browser and programmatically interacting with the application.
In a continuous integration pipeline, we probably don't want to run the interface (as that's slower and nobody can see it) of our browser during automated testing.
Moreover, we want to invoke it via the command line in our CI environment.
So, we can set up [Capybara](https://github.com/teamcapybara/capybara) to use [headless Chrome](https://developer.chrome.com/blog/headless-chrome/) to solve this for us.

## What does that look like?

To do this in Rails 7, register a new Selenium driver and configure it to be the driver for each system test in our CI environment:

```ruby
# spec/support/capybara.rb

Capybara.register_driver :headless_chrome do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: %w[headless no-sandbox disable-gpu disable-dev-shm-usage],
    binary: '/usr/bin/google-chrome'
  )

  Capybara::Selenium::Driver.new(
    app,
    browser: :chrome,
    options:
  )
end

RSpec.configure do |config|
  is_ci = ENV.fetch('IS_CI', false)
  if is_ci
    config.before(:each, type: :system) do
      driven_by :headless_chrome
    end
  end
end
```

Then, `require` it from our `rails_helper.rb`:

```ruby
# spec/rails_helper.rb

require 'capybara/rspec'
require 'support/capybara'

...
```

During Github Actions runs, set `IS_CI` to be true either from your repository environment variables or from your CI pipeline directly, e.g.:

```yaml
- name: Run ruby tests
  env:
    IS_CI: true
    RAILS_ENV: test
    PGHOST: localhost
    POSTGRES_DB: rails_github_actions_test
    POSTGRES_USER: rails_github_actions
    POSTGRES_PASSWORD: postgres
    PGPORT: ${{ job.services.postgres.ports[5432] }}
  run: rspec
```

## A bug I encountered

While trying to invoke `rspec` in my Github Actions environment, the following error occurred for each system test:

```
Selenium::WebDriver::Error::UnknownError:
    unknown error: Chrome failed to start: exited abnormally.
      (unknown error: DevToolsActivePort file doesn't exist)
      (The process started from chrome location /usr/bin/google-chrome is no longer running, so ChromeDriver is assuming that Chrome has crashed.)
```

This was solved by adding the `no-sandbox` argument to `Selenium::WebDriver::Chrome::Options` hash.

A detailed explanation can be found from [this stackoverflow answer](https://stackoverflow.com/questions/50642308/webdriverexception-unknown-error-devtoolsactiveport-file-doesnt-exist-while-t/50642913#50642913)
