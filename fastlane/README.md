fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios precheck_metadata

```sh
[bundle exec] fastlane ios precheck_metadata
```

Validate metadata without uploading anything

### ios upload_aso

```sh
[bundle exec] fastlane ios upload_aso
```

Upload ONLY name/subtitle/keywords for all locales (no build, no screenshots, no IAP, no precheck)

### ios upload_description

```sh
[bundle exec] fastlane ios upload_description
```

Upload ONLY description for all locales (no build, no screenshots, no other metadata, no IAP, no precheck)

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload metadata and screenshots only (no build)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots only

### ios download_metadata

```sh
[bundle exec] fastlane ios download_metadata
```

Download current metadata from App Store Connect

### ios download_screenshots

```sh
[bundle exec] fastlane ios download_screenshots
```

Download current screenshots from App Store Connect

### ios init_from_app_store

```sh
[bundle exec] fastlane ios init_from_app_store
```

Initialize project by downloading existing metadata and screenshots

### ios upload_build

```sh
[bundle exec] fastlane ios upload_build
```

Upload a new IPA build

### ios release

```sh
[bundle exec] fastlane ios release
```

Upload IPA + metadata + screenshots and optionally submit for review

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Submit the current version for review

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Upload build to TestFlight

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
