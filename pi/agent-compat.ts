/**
 * Compatibility resource bridge for users migrating from Claude Code/Codex.
 *
 * Pi already loads project AGENTS.md/CLAUDE.md context files. This extension adds
 * common skill and prompt-template directories from other agent harnesses,
 * including project-local .claude directories discovered from cwd ancestors.
 */

import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join } from "node:path";

function isDirectory(path: string): boolean {
  try {
    return existsSync(path) && statSync(path).isDirectory();
  } catch {
    return false;
  }
}

function pushDir(paths: string[], path: string): void {
  if (isDirectory(path) && !paths.includes(path)) paths.push(path);
}

function ancestorDirs(start: string): string[] {
  const dirs: string[] = [];
  let current = start;

  while (true) {
    dirs.push(current);
    const parent = dirname(current);
    if (parent === current) break;
    current = parent;
  }

  return dirs;
}

function pushClaudePluginResources(root: string, skillPaths: string[], promptPaths: string[]): void {
  pushDir(skillPaths, join(root, "skills"));
  pushDir(promptPaths, join(root, "commands"));

  // Claude Code "agents" are markdown files with frontmatter. Pi does not have
  // a subagent API, so expose them as prompt templates/slash commands instead.
  pushDir(promptPaths, join(root, "agents"));
}

function installedClaudePluginRoots(home: string): string[] {
  const installedFile = join(home, ".claude", "plugins", "installed_plugins.json");
  if (!existsSync(installedFile)) return [];

  try {
    const installed = JSON.parse(readFileSync(installedFile, "utf8"));
    const roots: string[] = [];

    for (const installs of Object.values(installed.plugins ?? {})) {
      if (!Array.isArray(installs)) continue;
      for (const install of installs) {
        if (typeof install?.installPath === "string" && isDirectory(install.installPath)) {
          pushDir(roots, install.installPath);
        }
      }
    }

    return roots;
  } catch {
    return [];
  }
}

function cachedClaudePluginRoots(home: string): string[] {
  const cacheRoot = join(home, ".claude", "plugins", "cache");
  const roots: string[] = [];
  if (!isDirectory(cacheRoot)) return roots;

  try {
    for (const marketplace of readdirSync(cacheRoot)) {
      const marketplaceRoot = join(cacheRoot, marketplace);
      if (!isDirectory(marketplaceRoot)) continue;

      for (const plugin of readdirSync(marketplaceRoot)) {
        const pluginRoot = join(marketplaceRoot, plugin);
        if (!isDirectory(pluginRoot)) continue;

        for (const version of readdirSync(pluginRoot)) {
          const versionRoot = join(pluginRoot, version);
          if (!isDirectory(versionRoot)) continue;
          if (
            isDirectory(join(versionRoot, "skills")) ||
            isDirectory(join(versionRoot, "commands")) ||
            isDirectory(join(versionRoot, "agents"))
          ) {
            pushDir(roots, versionRoot);
          }
        }
      }
    }
  } catch {
    return roots;
  }

  return roots;
}

export default function (pi) {
  pi.on("resources_discover", async (event) => {
    const home = homedir();
    const skillPaths: string[] = [];
    const promptPaths: string[] = [];

    // Global user resources from other agents.
    pushDir(skillPaths, join(home, ".claude", "skills"));
    pushDir(skillPaths, join(home, ".codex", "skills"));
    pushDir(promptPaths, join(home, ".claude", "commands"));
    pushDir(promptPaths, join(home, ".claude", "agents"));
    pushDir(promptPaths, join(home, ".codex", "prompts"));

    // Claude Code plugin resources. Prefer the installed plugin registry, then
    // fall back to cache discovery for older or partially migrated installs.
    const pluginRoots = installedClaudePluginRoots(home);
    const roots = pluginRoots.length > 0 ? pluginRoots : cachedClaudePluginRoots(home);
    for (const root of roots) {
      pushClaudePluginResources(root, skillPaths, promptPaths);
    }

    // Project-local resources from cwd ancestors. This mirrors how pi discovers
    // project context files, but for Claude/Codex skills and slash commands.
    for (const dir of ancestorDirs(event.cwd)) {
      pushDir(skillPaths, join(dir, ".claude", "skills"));
      pushDir(skillPaths, join(dir, ".codex", "skills"));
      pushDir(promptPaths, join(dir, ".claude", "commands"));
      pushDir(promptPaths, join(dir, ".claude", "agents"));
      pushDir(promptPaths, join(dir, ".codex", "prompts"));
    }

    return { skillPaths, promptPaths };
  });
}
