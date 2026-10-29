# ThermalForge 0.2.3

Free Apple fan control for Apple Silicon Macs (macOS 14+). Menu-bar app
+ CLI with live temperatures, five fan profiles, and a daemon-enforced
safety override.

## Install

Open the `.dmg`, drag ThermalForge.app to Applications, then run the
app. Verify first, in the download folder:

```sh
shasum -a 256 -c SHA256SUMS
```

Ad-hoc signed, not notarized, so first launch needs right-click Open.

## What's new in this release

- Install the fan-control daemon from the app, with no Terminal: the
  app installs its daemon on first launch with one administrator
  prompt, and the daemon is embedded in the app bundle.
- The in-app updater now points at this fork
  (Salcedoandrew/B-and-T-Pro), so future releases here will surface
  inside the app.

## Notes

- Apple Silicon only, macOS 14+.
- The daemon enforces a safety override: if a critical sensor crosses
  95 °C while a manual hold is keeping fans too low, fans go to
  maximum, even with the menu-bar app closed.
- Fork of ProducerGuy/ThermalForge (MIT), renamed B-and-T-Pro.
