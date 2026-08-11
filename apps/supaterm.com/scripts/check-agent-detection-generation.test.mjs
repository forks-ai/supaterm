import { describe, expect, it } from "vite-plus/test";
import {
  agentDetectionGeneration,
  requireIncreasedAgentDetectionGeneration,
} from "./check-agent-detection-generation.mjs";

const rules = (generation, marker = "ready") => `
format_version = 1
generation = ${generation}
minimum_engine_version = 1
marker = "${marker}"
`;

describe("agent detection generation policy", () => {
  it("allows unchanged rules", () => {
    const document = rules(7n);

    expect(() => requireIncreasedAgentDetectionGeneration(document, document)).not.toThrow();
  });

  it("requires changed rules to increase generation", () => {
    expect(() =>
      requireIncreasedAgentDetectionGeneration(rules(7n), rules(8n, "changed")),
    ).not.toThrow();
    expect(() => requireIncreasedAgentDetectionGeneration(rules(7n), rules(7n, "changed"))).toThrow(
      "generation must increase from 7 when rules change",
    );
    expect(() => requireIncreasedAgentDetectionGeneration(rules(7n), rules(6n, "changed"))).toThrow(
      "generation must increase from 7 when rules change",
    );
  });

  it("requires one generation field", () => {
    expect(agentDetectionGeneration(rules(42n))).toBe(42n);
    expect(() => agentDetectionGeneration("format_version = 1\n")).toThrow(
      "rules must contain one generation",
    );
    expect(() => agentDetectionGeneration(`${rules(1n)}generation = 2\n`)).toThrow(
      "rules must contain one generation",
    );
  });
});
