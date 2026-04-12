#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";

function parseArgs(argv) {
  const options = {
    check: false,
    plugin: null,
    skill: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];

    if (arg === "--check") {
      options.check = true;
      continue;
    }

    if (arg === "--plugin") {
      options.plugin = argv[index + 1] ?? null;
      index += 1;
      continue;
    }

    if (arg === "--skill") {
      options.skill = argv[index + 1] ?? null;
      index += 1;
      continue;
    }

    throw new Error(`未対応の引数です: ${arg}`);
  }

  if (options.skill && !options.plugin) {
    throw new Error("--skill を使う場合は --plugin も指定してください");
  }

  return options;
}

function countIndent(line) {
  let count = 0;
  while (count < line.length && line[count] === " ") {
    count += 1;
  }
  return count;
}

function parseScalar(rawValue) {
  if (
    (rawValue.startsWith("'") && rawValue.endsWith("'")) ||
    (rawValue.startsWith('"') && rawValue.endsWith('"'))
  ) {
    const inner = rawValue.slice(1, -1);
    if (rawValue.startsWith("'")) {
      return inner.replace(/''/g, "'");
    }
    return inner.replace(/\\"/g, '"');
  }

  if (rawValue === "true") {
    return true;
  }

  if (rawValue === "false") {
    return false;
  }

  return rawValue;
}

function findNextContentIndex(lines, start) {
  for (let index = start; index < lines.length; index += 1) {
    const trimmed = lines[index].trim();
    if (trimmed !== "" && !trimmed.startsWith("#")) {
      return index;
    }
  }
  return -1;
}

function parseList(lines, startIndex, indent) {
  const values = [];
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];
    const trimmed = line.trim();

    if (trimmed === "" || trimmed.startsWith("#")) {
      index += 1;
      continue;
    }

    const currentIndent = countIndent(line);
    if (currentIndent < indent) {
      break;
    }

    if (currentIndent !== indent || !trimmed.startsWith("- ")) {
      throw new Error(`配列の解析に失敗しました: ${line}`);
    }

    values.push(parseScalar(trimmed.slice(2).trim()));
    index += 1;
  }

  return { value: values, nextIndex: index };
}

function parseMap(lines, startIndex, indent) {
  const result = {};
  let index = startIndex;

  while (index < lines.length) {
    const line = lines[index];
    const trimmed = line.trim();

    if (trimmed === "" || trimmed.startsWith("#")) {
      index += 1;
      continue;
    }

    const currentIndent = countIndent(line);
    if (currentIndent < indent) {
      break;
    }

    if (currentIndent !== indent) {
      throw new Error(`インデントの解析に失敗しました: ${line}`);
    }

    const separatorIndex = trimmed.indexOf(":");
    if (separatorIndex === -1) {
      throw new Error(`キーの解析に失敗しました: ${line}`);
    }

    const key = trimmed.slice(0, separatorIndex).trim();
    const rest = trimmed.slice(separatorIndex + 1).trim();

    if (rest !== "") {
      result[key] = parseScalar(rest);
      index += 1;
      continue;
    }

    const nestedIndex = findNextContentIndex(lines, index + 1);
    if (nestedIndex === -1) {
      result[key] = {};
      index += 1;
      continue;
    }

    const nestedIndent = countIndent(lines[nestedIndex]);
    if (nestedIndent <= currentIndent) {
      result[key] = {};
      index += 1;
      continue;
    }

    if (lines[nestedIndex].trim().startsWith("- ")) {
      const parsed = parseList(lines, nestedIndex, nestedIndent);
      result[key] = parsed.value;
      index = parsed.nextIndex;
      continue;
    }

    const parsed = parseMap(lines, nestedIndex, nestedIndent);
    result[key] = parsed.value;
    index = parsed.nextIndex;
  }

  return { value: result, nextIndex: index };
}

function parseYamlFile(filePath) {
  const content = fs.readFileSync(filePath, "utf8");
  const parsed = parseMap(content.split(/\r?\n/), 0, 0).value;

  if (!parsed.name || !parsed.description) {
    throw new Error(`name / description が不足しています: ${filePath}`);
  }

  return parsed;
}

function yamlQuote(value) {
  return `'${String(value).replace(/'/g, "''")}'`;
}

function buildFrontmatter(platform, metadata) {
  const lines = ["---"];
  lines.push(`name: ${yamlQuote(metadata.name)}`);
  lines.push(`description: ${yamlQuote(metadata.description)}`);

  if (platform === "claude" && metadata.argument_hint) {
    lines.push(`argument-hint: ${yamlQuote(metadata.argument_hint)}`);
  }

  if (platform === "claude") {
    const allowedTools = metadata.claude?.allowed_tools ?? [];
    if (allowedTools.length > 0) {
      lines.push(`allowed-tools: ${yamlQuote(allowedTools.join(" "))}`);
    }
  }

  lines.push("---");
  return `${lines.join("\n")}\n`;
}

function buildGeneratedNotice(relativeSourcePath) {
  return [
    "<!--",
    "このファイルは scripts/sync-skills.mjs により自動生成されています。",
    `編集は \`${relativeSourcePath}\` を更新してください。`,
    "-->",
    "",
  ].join("\n");
}

function buildPlatformNote(platform, metadata) {
  const notes = [];

  if (platform === "codex" && metadata.argument_hint) {
    notes.push(`想定引数: \`${metadata.argument_hint}\``);
  }

  if (platform === "codex" && Array.isArray(metadata.shared_tools) && metadata.shared_tools.length > 0) {
    notes.push(`推奨ツール: \`${metadata.shared_tools.join("`, `")}\``);
  }

  if (notes.length === 0) {
    return "";
  }

  return `${notes.map((entry) => `> ${entry}`).join("\n")}\n\n`;
}

function buildSkillMarkdown(platform, metadata, body, relativeSourcePath) {
  const frontmatter = buildFrontmatter(platform, metadata);
  const notice = buildGeneratedNotice(relativeSourcePath);
  const platformNote = buildPlatformNote(platform, metadata);
  return `${frontmatter}\n${notice}${platformNote}${body.trimEnd()}\n`;
}

function ensureDirectory(directoryPath) {
  fs.mkdirSync(directoryPath, { recursive: true });
}

function writeIfChanged(filePath, nextContent, checkMode, changes) {
  const currentContent = fs.existsSync(filePath) ? fs.readFileSync(filePath, "utf8") : null;

  if (currentContent === nextContent) {
    return;
  }

  changes.push(path.relative(process.cwd(), filePath));

  if (checkMode) {
    return;
  }

  ensureDirectory(path.dirname(filePath));
  fs.writeFileSync(filePath, nextContent);
}

function collectPlugins(pluginsRoot, targetPlugin) {
  if (targetPlugin) {
    const pluginPath = path.join(pluginsRoot, targetPlugin);
    if (!fs.existsSync(pluginPath) || !fs.statSync(pluginPath).isDirectory()) {
      throw new Error(`plugin が見つかりません: ${targetPlugin}`);
    }
    return [targetPlugin];
  }

  return fs
    .readdirSync(pluginsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function collectSharedSkills(sharedRoot, targetSkill) {
  if (!fs.existsSync(sharedRoot)) {
    if (targetSkill) {
      throw new Error(`shared-skills が見つかりません: ${sharedRoot}`);
    }
    return [];
  }

  const skillNames = fs
    .readdirSync(sharedRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();

  if (!targetSkill) {
    return skillNames;
  }

  if (!skillNames.includes(targetSkill)) {
    throw new Error(`skill が見つかりません: ${targetSkill}`);
  }

  return [targetSkill];
}

function syncPlugin(repoRoot, pluginName, targetSkill, checkMode, changes) {
  const pluginRoot = path.join(repoRoot, "plugins", pluginName);
  const sharedRoot = path.join(pluginRoot, "shared-skills");
  const skillNames = collectSharedSkills(sharedRoot, targetSkill);

  for (const skillName of skillNames) {
    const skillRoot = path.join(sharedRoot, skillName);
    const metadata = parseYamlFile(path.join(skillRoot, "skill.yaml"));
    const bodyPath = path.join(skillRoot, "body.md");
    const body = fs.readFileSync(bodyPath, "utf8");
    const relativeSourcePath = path.relative(repoRoot, skillRoot);

    const claudePath = path.join(pluginRoot, "skills", skillName, "SKILL.md");
    const codexPath = path.join(pluginRoot, "codex-skills", skillName, "SKILL.md");

    writeIfChanged(
      claudePath,
      buildSkillMarkdown("claude", metadata, body, relativeSourcePath),
      checkMode,
      changes,
    );

    writeIfChanged(
      codexPath,
      buildSkillMarkdown("codex", metadata, body, relativeSourcePath),
      checkMode,
      changes,
    );
  }
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const repoRoot = process.cwd();
  const pluginsRoot = path.join(repoRoot, "plugins");
  const changes = [];

  if (!fs.existsSync(pluginsRoot)) {
    throw new Error(`plugins ディレクトリが見つかりません: ${pluginsRoot}`);
  }

  for (const pluginName of collectPlugins(pluginsRoot, options.plugin)) {
    syncPlugin(repoRoot, pluginName, options.skill, options.check, changes);
  }

  if (options.check) {
    if (changes.length > 0) {
      console.error("未同期の生成物があります:");
      for (const change of changes) {
        console.error(`- ${change}`);
      }
      process.exitCode = 1;
      return;
    }

    console.log("生成物は同期されています。");
    return;
  }

  if (changes.length === 0) {
    console.log("変更はありません。");
    return;
  }

  console.log("生成物を更新しました:");
  for (const change of changes) {
    console.log(`- ${change}`);
  }
}

main();
