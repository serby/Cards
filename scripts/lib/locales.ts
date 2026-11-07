// The App Store listing's locales and the app's languages, for the scripts that
// generate, check, capture or upload anything per locale. The store locales are
// the folders in metadata/ (en-GB, en-US, es-MX, ja and so on), so a listing is
// added by adding its folder. The app's languages are the project's
// knownRegions less en and Base (scripts/add-language.ts adds them), read as
// scripts/lib/string-catalogues.ts reads them.
//
// Usage: import { storeLocales, languageOf, regionOf, appLanguages } from "./lib/locales.ts";

import { readdirSync } from "node:fs";
import { join } from "node:path";
import { languagesOf, projectAt } from "./string-catalogues.ts";

const root = join(import.meta.dirname, "..", "..");

/// The listing's locales: the folders in metadata/, sorted.
export function storeLocales(rootDir: string = root): string[] {
    return readdirSync(join(rootDir, "metadata"), { withFileTypes: true })
        .filter((entry) => entry.isDirectory() && !entry.name.startsWith("."))
        .map((entry) => entry.name)
        .sort();
}

/// A locale's language as the app and iOS name it: its language subtag, with
/// its script when it names one, so es-MX is es and zh-Hant stays zh-Hant.
export function languageOf(code: string): string {
    const locale = new Intl.Locale(code);
    return locale.script ? `${locale.language}-${locale.script}` : locale.language;
}

/// A locale's region, or the language's most likely one when it names none, so
/// es-MX is MX and ja is JP.
export function regionOf(code: string): string {
    const region = new Intl.Locale(code).maximize().region;
    if (!region) throw new Error(`${code} has no likely region`);
    return region;
}

/// The app's languages: the project's knownRegions less en and Base.
export function appLanguages(rootDir: string = root): string[] {
    return languagesOf(projectAt(rootDir));
}
