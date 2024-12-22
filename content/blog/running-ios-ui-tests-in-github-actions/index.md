---
title: Running iOS UI Tests in GitHub Actions
date: "2024-12-22T00:00:00.000Z"
description: The iOS toolchain is notoriously annoying - here's how to actually get it working for you in CI.
---

While futzing around during my holiday break, I wanted to tinker with an iOS application.
As of the time of writing, getting UI tests to work in CI (via GitHub Actions) isn't a simple, out-of-the-box experience, even for a barebones project.
So, to help anyone else frantically googling as I did, allow me to explain an issue I encountered and how I solved the problem.

## The error

While I could get tests working on my local machine, this error repeatedly occurred in CI for my given project:

```
Run xcodebuild test \
Command line invocation:
    /Applications/Xcode_16.1.app/Contents/Developer/usr/bin/xcodebuild test -scheme Hugelifts -destination "platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.2"

User defaults from command line:
    IDEPackageSupportUseBuiltinSCM = YES

2024-12-22 14:00:08.612 xcodebuild[2695:16313] Writing error result bundle to /var/folders/95/0ydz4d79163427j3k5crp3fh0000gn/T/ResultBundle_2024-22-12_14-00-0008.xcresult
xcodebuild: error: Unable to find a device matching the provided destination specifier:
		{ platform:iOS Simulator, OS:18.2, name:iPhone SE (3rd generation) }

	The requested device could not be found because no available devices matched the request.

	Available destinations for the "Hugelifts" scheme:
		{ platform:iOS, id:dvtdevice-DVTiPhonePlaceholder-iphoneos:placeholder, name:Any iOS Device }
		{ platform:iOS Simulator, id:dvtdevice-DVTiOSDeviceSimulatorPlaceholder-iphonesimulator:placeholder, name:Any iOS Simulator Device }
```

It wasn't immediately obvious to me why the installed xcode toolchain in my GitHub Actions environment seemed different than what I had installed locally. The problem is always dependencies, isn't it?

## Xcode project tweaks

All of the research online neglected mentioning this, and it ended up being part of the problem for me.
Ensure that your project's deployment target and target's minimum deployments are 1) within the same range of allowed versions and 2) a supported version in GitHub Actions installed version of Xcode.

For example, in your `project.pbxproj`, you should see `IPHONEOS_DEPLOYMENT_TARGET = 18.1` repeated for each of your targets and your project.

My deployment target and minimum deployment were set to `18.2` via Xcode, so changing this was required. Why? Well...

## GitHub Actions tweaks

Make sure the simulator exists in the CI environment with the appropriate version of iOS.
This command is useful for introspecting what is available:

```yml
- name: List available simulators (debug)
  run: xcrun simctl list devices
```

As can be observed, only versions up to `18.1` were supported at the time of writing:

```
...
-- iOS 18.1 --
    iPhone SE (3rd generation) (526DB88C-88B8-40F9-882C-A8D2862491B4) (Shutdown)
...
```

So, putting this together, I realized I had to specify `18.1` in my project and in GitHub Actions job:

```yml
name: CI

on:
  push:
    branches:
      - main
  pull_request:
    branches:
      - main

jobs:
  test:
    name: Run Tests
    runs-on: macos-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Xcode
        uses: maxim-lobanov/setup-xcode@v1

      - name: List available simulators (debug)
        run: xcrun simctl list devices

      - name: Run Tests
        run: |
          xcodebuild test \
            -scheme 'Hugelifts' \
            -destination 'platform=iOS Simulator,name=iPhone SE (3rd generation),OS=18.1'
```

This [ended up being successful](https://github.com/laaksomavrick/hugelifts/actions/runs/12455016699/job/34766944220).
What a pain.
