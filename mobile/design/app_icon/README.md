# EuroTrex app icon

`eurotrex_app_icon_source.jpg` is the original logo supplied for the iOS/Android app and the website's Notify dialog. Keep this source unchanged; generated assets are resized copies, not redesigned variants.

From the repository root, with Node.js and Sharp available:

```sh
node scripts/generate-app-icons.mjs
```

If Sharp is installed outside this project, pass the absolute path to its module as the first argument. The generator updates the iOS asset catalogue, Android legacy and adaptive launcher icons, the 1024px design masters, and `www/public/eurotrex-app-icon-e4.webp`.

The iOS PNGs are opaque. Android's adaptive foreground has transparent padding to keep the complete artwork inside launcher masks. The website uses a 256px WebP.

Launch Flutter from `mobile/` with `--dart-define-from-file=env.local.json`; never copy or commit that configuration file.
