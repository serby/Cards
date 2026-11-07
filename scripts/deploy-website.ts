// Deploys the built website in Website/dist to Cloudflare Pages, as the
// card-barcodes project, with wrangler. Build it first with
// node scripts/build-website.ts, which .github/workflows/website.yml runs just
// before this. Needs CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID in the
// environment; the workflow sets them from secrets.
//
// Usage: node scripts/deploy-website.ts

import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { join } from "node:path";

const site = join(import.meta.dirname, "..", "Website", "dist");
const projectName = "card-barcodes";

if (!process.env.CLOUDFLARE_API_TOKEN || !process.env.CLOUDFLARE_ACCOUNT_ID) {
    console.error("Error: CLOUDFLARE_API_TOKEN and CLOUDFLARE_ACCOUNT_ID must be set");
    process.exit(1);
}
if (!existsSync(join(site, "index.html"))) {
    console.error("Error: Website/dist has no site in it; run node scripts/build-website.ts first");
    process.exit(1);
}

console.log("Deploying to Cloudflare Pages...");
try {
    execFileSync("npx", ["wrangler", "pages", "deploy", site, `--project-name=${projectName}`], { stdio: "inherit" });
} catch (error) {
    // wrangler has already printed why it failed.
    const status = (error as { status?: number | null }).status;
    process.exit(typeof status === "number" && status !== 0 ? status : 1);
}
console.log("Deploy complete!");
