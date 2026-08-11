import { readFile } from "node:fs/promises";
import { fileURLToPath, URL } from "node:url";
import { defineConfig, type Plugin } from "vite-plus";
import react from "@vitejs/plugin-react";
import tailwindcss from "@tailwindcss/vite";
import { buildDownloadTargetUrl, githubOrigin } from "./src/lib/downloads.ts";

export const agentDetectionRulesFileName = "agent-detection/v1/rules.toml";
export const agentDetectionRulesSourcePath = fileURLToPath(
  new URL("../mac/supaterm/Resources/AgentDetection/rules.toml", import.meta.url),
);

export const loadAgentDetectionRulesAsset = async () => ({
  type: "asset" as const,
  fileName: agentDetectionRulesFileName,
  source: await readFile(agentDetectionRulesSourcePath),
});

const agentDetectionRulesPlugin = (): Plugin => ({
  name: "agent-detection-rules",
  apply: "build",
  async buildStart() {
    this.addWatchFile(agentDetectionRulesSourcePath);
    this.emitFile(await loadAgentDetectionRulesAsset());
  },
});

const rewriteDownloadPath = (path: string) => {
  const targetUrl = buildDownloadTargetUrl(new URL(path, githubOrigin));
  return targetUrl ? `${targetUrl.pathname}${targetUrl.search}` : path;
};

export default defineConfig({
  build: {
    rolldownOptions: {
      output: {
        codeSplitting: {
          groups: [
            {
              name: "analytics",
              test: /node_modules[\\/]posthog-js/,
            },
          ],
        },
      },
    },
  },
  lint: { options: { typeAware: true, typeCheck: true } },
  server: {
    proxy: {
      "/download/latest/": {
        target: githubOrigin,
        changeOrigin: true,
        rewrite: rewriteDownloadPath,
      },
      "/download/tip/": {
        target: githubOrigin,
        changeOrigin: true,
        rewrite: rewriteDownloadPath,
      },
      "/download/v": {
        target: githubOrigin,
        changeOrigin: true,
        rewrite: rewriteDownloadPath,
      },
    },
  },
  resolve: {
    alias: {
      "@": fileURLToPath(new URL("./src", import.meta.url)),
    },
  },
  plugins: [react(), tailwindcss(), agentDetectionRulesPlugin()],
});
