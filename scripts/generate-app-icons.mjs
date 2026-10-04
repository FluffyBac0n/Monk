import { createRequire } from 'node:module';
import { readFile } from 'node:fs/promises';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

// Run with a Sharp installation: node scripts/generate-app-icons.mjs [sharp-module-path]
const require = createRequire(import.meta.url);
const sharp = require(process.argv[2] || 'sharp');
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const source = resolve(root, 'mobile/design/app_icon/eurotrex_app_icon_source.jpg');
const png = (size, target) => sharp(source).resize(size, size).png().toFile(resolve(root, target));

await png(1024, 'mobile/design/app_icon/eurotrex_app_icon_1024.png');
await png(1024, 'mobile/design/app_icon/eurotrex_app_icon_foreground_1024.png');

const catalog = 'mobile/ios/Runner/Assets.xcassets/AppIcon.appiconset';
const { images } = JSON.parse(await readFile(resolve(root, catalog, 'Contents.json'), 'utf8'));
const sizes = new Map(images.filter(image => image.filename).map(image => [
  image.filename, Math.round(parseFloat(image.size) * parseFloat(image.scale)),
]));
for (const [filename, size] of sizes) await png(size, `${catalog}/${filename}`);

const resources = 'mobile/android/app/src/main/res';
for (const [density, size] of Object.entries({ mdpi: 48, hdpi: 72, xhdpi: 96, xxhdpi: 144, xxxhdpi: 192 })) {
  await png(size, `${resources}/mipmap-${density}/ic_launcher.png`);
  await png(size, `${resources}/mipmap-${density}/ic_launcher_round.png`);
}

// Adaptive launchers apply their own mask. Keep the complete artwork in the
// central safe zone so stars and lettering survive circle and squircle masks.
const foreground = await sharp(source).resize(624, 624).png().toBuffer();
for (const filename of ['ic_launcher_foreground.png', 'ic_launcher_foreground_android.png']) {
  await sharp({ create: { width: 1024, height: 1024, channels: 4, background: '#00000000' } })
    .composite([{ input: foreground, left: 200, top: 200 }])
    .png().toFile(resolve(root, `${resources}/drawable-nodpi/${filename}`));
}

await sharp(source).resize(256, 256).webp({ quality: 90 })
  .toFile(resolve(root, 'www/public/eurotrex-app-icon-e4.webp'));
console.log(`Generated ${sizes.size} iOS icons, Android legacy/adaptive icons, and the website icon.`);
