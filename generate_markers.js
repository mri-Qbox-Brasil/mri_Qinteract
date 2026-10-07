const fs = require('fs');
const path = require('path');
const sharp = require('sharp');

const yt = {
    target: { svg: '<circle cx="32" cy="32" r="25" fill="none" stroke="white" stroke-width="6"/><circle cx="32" cy="32" r="10" fill="white"/>' },
    dot: { svg: '<circle cx="32" cy="32" r="26" fill="white"/>' },
    ring: { svg: '<circle cx="32" cy="32" r="24" fill="none" stroke="white" stroke-width="8"/>' },
    diamond: { svg: '<path d="M32 4 L60 32 L32 60 L4 32 Z" fill="white"/>' },
    rhombus: { svg: '<path d="M32 8 L56 32 L32 56 L8 32 Z" fill="none" stroke="white" stroke-width="7" stroke-linejoin="round"/>' },
    square: { svg: '<rect x="8" y="8" width="48" height="48" rx="10" fill="white"/>' },
    eye: { svg: '<path d="M5 32 C15 15 49 15 59 32 C49 49 15 49 5 32 Z" fill="none" stroke="white" stroke-width="6" stroke-linejoin="round"/><circle cx="32" cy="32" r="9.5" fill="white"/>' },
    hand: { svg: '<g transform="translate(2 2) scale(2.5)" fill="none" stroke="white" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"><path d="M18 11V6a2 2 0 0 0-4 0"/><path d="M14 10V4a2 2 0 0 0-4 0v2"/><path d="M10 10.5V6a2 2 0 0 0-4 0v8"/><path d="M18 8a2 2 0 1 1 4 0v6a8 8 0 0 1-8 8h-2c-2.8 0-4.5-.86-5.99-2.34l-3.6-3.6a2 2 0 0 1 2.83-2.82L7 15"/></g>' },
    arrow: { svg: '<path d="M12 21 L32 43 L52 21" fill="none" stroke="white" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>' },
    crosshair: { svg: '<path d="M32 5V20M32 44V59M5 32H20M44 32H59" stroke="white" stroke-width="6" stroke-linecap="round"/><circle cx="32" cy="32" r="5" fill="white"/>' }
};

const outputDir = path.join(__dirname, 'web', 'markers');
if (!fs.existsSync(outputDir)) {
    fs.mkdirSync(outputDir, { recursive: true });
}

async function run() {
    for (const [name, data] of Object.entries(yt)) {
        const svgString = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">${data.svg}</svg>`;
        const outPath = path.join(outputDir, `${name}.png`);
        await sharp(Buffer.from(svgString))
            .resize(256, 256)
            .png()
            .toFile(outPath);
        console.log(`Generated ${outPath}`);
    }
}

run().catch(console.error);
