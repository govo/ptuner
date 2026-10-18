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

### ios upload_metadata

```sh
[bundle exec] fastlane ios upload_metadata
```

Upload iOS metadata only (no build, no screenshots)

### ios upload_metadata_macos

```sh
[bundle exec] fastlane ios upload_metadata_macos
```

Upload macOS metadata only (no build, no screenshots)

### ios stage_screenshots

```sh
[bundle exec] fastlane ios stage_screenshots
```

Stage screenshots from a source directory into the fastlane/screenshots layout

### ios stage_app_previews

```sh
[bundle exec] fastlane ios stage_app_previews
```

Stage App Preview videos into the fastlane/app_previews layout

### ios upload_app_previews

```sh
[bundle exec] fastlane ios upload_app_previews
```

Upload iOS App Preview videos (overwrite: true replaces existing preview sets)

### ios upload_screenshots_ios

```sh
[bundle exec] fastlane ios upload_screenshots_ios
```

Upload iOS screenshots only (overwrite: true replaces existing screenshot sets)

### ios upload_screenshots_macos

```sh
[bundle exec] fastlane ios upload_screenshots_macos
```

Upload macOS screenshots only (overwrite: true replaces existing screenshot sets)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload iOS + macOS screenshots (overwrite: true replaces existing screenshot sets)

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

Upload IPA and optionally submit for review (metadata/screenshots are opt-in)

### ios submit_review

```sh
[bundle exec] fastlane ios submit_review
```

Submit the current version for review (platform: ios | osx | both, automatic_release: true|false)

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

Upload build to TestFlight

### ios create_pro_products

```sh
[bundle exec] fastlane ios create_pro_products
```

Create the three PTuner Pro products (lifetime, yearly, weekly) if missing

### ios list_subscriptions

```sh
[bundle exec] fastlane ios list_subscriptions
```

List all subscription groups and subscriptions with their localizations

### ios update_pro_subscription_localizations

```sh
[bundle exec] fastlane ios update_pro_subscription_localizations
```

Update Pro weekly and yearly subscription localizations for supported languages

### ios update_pro_subscription_group_localizations

```sh
[bundle exec] fastlane ios update_pro_subscription_group_localizations
```

Update Pro subscription group localization for supported languages

### ios create_app_store_versions

```sh
[bundle exec] fastlane ios create_app_store_versions
```

Create App Store versions on iOS and macOS (existing versions are kept)

### ios sync_app_store_metadata

```sh
[bundle exec] fastlane ios sync_app_store_metadata
```

Sync release notes, description and promotional text to both platforms

### ios attach_app_store_build

```sh
[bundle exec] fastlane ios attach_app_store_build
```

Attach an uploaded build to the iOS and macOS App Store versions

### ios list_app_store_metadata

```sh
[bundle exec] fastlane ios list_app_store_metadata
```

List version-level metadata state on both platforms

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
