import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { pathToFileURL } from "node:url";

const generationPattern = /^generation\s*=\s*(\d+)\s*$/gm;

export const agentDetectionGeneration = (rules) => {
  const matches = [...rules.matchAll(generationPattern)];
  if (matches.length !== 1 || matches[0]?.[1] === undefined) {
    throw new Error("rules must contain one generation");
  }
  return BigInt(matches[0][1]);
};

export const requireIncreasedAgentDetectionGeneration = (previousRules, currentRules) => {
  if (previousRules === currentRules) {
    return;
  }
  const previousGeneration = agentDetectionGeneration(previousRules);
  const currentGeneration = agentDetectionGeneration(currentRules);
  if (currentGeneration <= previousGeneration) {
    throw new Error(`generation must increase from ${previousGeneration} when rules change`);
  }
};

const previousRules = (base, path) => {
  try {
    execFileSync("git", ["cat-file", "-e", `${base}^{commit}`], { stdio: "ignore" });
  } catch {
    throw new Error(`base commit does not exist: ${base}`);
  }
  try {
    return execFileSync("git", ["show", `${base}:${path}`], {
      encoding: "utf8",
      stdio: ["ignore", "pipe", "ignore"],
    });
  } catch {
    return undefined;
  }
};

const run = (base, path) => {
  if (base === undefined || path === undefined) {
    throw new Error("usage: check-agent-detection-generation <base> <rules>");
  }
  if (base.length === 0 || /^0+$/.test(base)) {
    return;
  }
  const previous = previousRules(base, path);
  if (previous === undefined) {
    return;
  }
  requireIncreasedAgentDetectionGeneration(previous, readFileSync(path, "utf8"));
};

if (import.meta.url === pathToFileURL(process.argv[1] ?? "").href) {
  try {
    run(process.argv[2], process.argv[3]);
  } catch (error) {
    process.stderr.write(`error: ${error instanceof Error ? error.message : String(error)}\n`);
    process.exitCode = 1;
  }
}
