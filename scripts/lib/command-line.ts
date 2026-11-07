// What scripts share on the command line: usage errors, which exit 2 and point
// at --help, whole-number options, logging to stderr under the script's name,
// and running a script's main function to its exit code.
//
// Usage: import { logger, positiveInteger, runScript, UsageError } from "./lib/command-line.ts";

/// A mistake in how the script was run, rather than in what it worked on.
export class UsageError extends Error {}

/// A whole number above 0 from an option or environment variable, or the
/// fallback when it is not set.
export function positiveInteger(value: string | undefined, fallback: number, option: string): number {
    if (value === undefined) return fallback;
    const number = Number(value);
    if (!Number.isInteger(number) || number < 1) throw new UsageError(`${option} needs a whole number above 0`);
    return number;
}

/// Writes progress to stderr, prefixed with the script's name, so stdout keeps
/// only the result.
export function logger(script: string): (line: string) => void {
    return (line) => console.error(`${script}: ${line}`);
}

/// Runs `main` on the script's arguments and exits with the code it returns:
/// 2 after a usage error (a UsageError or an option parseArgs refuses), 1
/// after any other error.
export function runScript(script: string, main: (argv: string[]) => number | Promise<number>): void {
    Promise.resolve()
        .then(() => main(process.argv.slice(2)))
        .then(
            (code) => {
                process.exitCode = code;
            },
            (error: unknown) => {
                const usageProblem = error instanceof UsageError || (error as { code?: string }).code?.startsWith("ERR_PARSE_ARGS") === true;
                console.error(`${script}: ${(error as Error).message}`);
                if (usageProblem) console.error(`Run node scripts/${script}.ts --help for usage.`);
                process.exitCode = usageProblem ? 2 : 1;
            },
        );
}
