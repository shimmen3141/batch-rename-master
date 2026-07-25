#!/usr/bin/env node
// secrets/ の本物の値から secrets.example/ のダミーを作り直す(自己完結・依存なし)。
//
// これは ai-sandbox-setup が配置した生成物。ドリフト対応で使う:
//   secrets/ に env を足した・値を変えたら、ホストのプロジェクトルートで:
//     node scripts/refresh-secrets.mjs
//   本物の値には触れずに(このスクリプト内でだけ変換)、secrets.example/ が再生成される。
//   secrets.example/ を手で書かないこと(本物を開いてコンテキストや履歴に載せる事故を防ぐ)。
//
// 更新するのは secrets.example/ だけ。Dockerfile / compose.ai.yml には触れない。
// 新しい「種類」のファイルを初めて足した場合(これまで無い .env.local 等)は、コンテナへ
// ダミーを渡すため compose.ai.yml の env_file 登録も要る。その一度きりの反映は scaffold 側で行う
// (docs/development/ai-sandbox.md の §6 参照)。既存ファイルの値変更・同一ファイル内のキー追加はこれで足りる。
//
// 実行はホスト側で(コンテナ内では secrets/ がダミーなので、ダミーからダミーを作るだけで無害)。
import fs from "node:fs";
import path from "node:path";

const target = path.resolve(process.argv[2] || ".");
const secretsDir = path.join(target, "secrets");
const exampleDir = path.join(target, "secrets.example");
if (!fs.existsSync(secretsDir)) {
  console.error(`ERROR: ${secretsDir} が無い。プロジェクトルートで実行するか、引数でパスを渡す。`);
  process.exit(1);
}

const marker = "AI_SANDBOX_DUMMY_MARKER v1";

function dummyEnvValue(v) {
  const t = v.trim();
  if (/^postgres(ql)?:\/\//i.test(t)) return "postgresql://dummy_user:dummy_pass@dummy.invalid:5432/dummy_db";
  if (/^mysql:\/\//i.test(t)) return "mysql://dummy_user:dummy_pass@dummy.invalid:3306/dummy_db";
  if (/^https?:\/\//i.test(t)) return "https://dummy.invalid";
  if (/^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+/.test(t)) // JWT
    return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.DUMMY_PAYLOAD.DUMMY_SIGNATURE";
  const p = t.match(/^([A-Za-z]{2,8}_(?:test_|live_|)?)/); // sk_test_ / ghp_ / pk_live_ ...
  if (p) return p[1] + "DUMMY000000000000000000";
  return "dummy0000000000000000000000000";
}

// 自己検査用: 本物の scalar 値を「置換の意図に関係なく」すべて集め、最後に残存が無いことを保証する(安全網)。
const allOriginals = [];
const rec = (v) => { const s = String(v); if (s.length >= 5) allOriginals.push(s); };

function dummyEnvFile(src) {
  const out = [];
  for (const line of src.split(/\r?\n/)) {
    if (line.trim() === "") { out.push(line); continue; } // 空行は残す
    if (line.trimStart().startsWith("#")) continue;        // コメントは落とす(値・接続先が書かれている恐れ)
    const m = line.match(/^(\s*(?:export\s+)?[A-Za-z_][A-Za-z0-9_]*\s*=)(.*)$/);
    if (!m) throw new Error("non-structural-line"); // 複数行値(非 quote の PEM 断片等)の疑い → fail-closed
    const t = m[2].trim();
    const q = t[0];
    if ((q === '"' || q === "'") && !(t.length >= 2 && t[t.length - 1] === q))
      throw new Error("multiline-quoted-value"); // 複数行 quoted 値(PEM 等)→ fail-closed
    rec(t);
    rec(t.replace(/^(["'])([\s\S]*)\1$/, "$2")); // クオートを外した実値も照合対象に
    out.push(m[1] + dummyEnvValue(m[2]));
  }
  return out.join("\n");
}

function dummyJsonString(t) {
  if (/^https?:\/\//i.test(t)) return "https://dummy.invalid";
  if (/BEGIN [A-Z ]*PRIVATE KEY/.test(t)) return "-----BEGIN PRIVATE KEY-----\nDUMMY\n-----END PRIVATE KEY-----\n";
  if (/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(t)) return "dummy@dummy.invalid";
  return "dummy";
}
function dummyJson(src) {
  const obj = JSON.parse(src); // 失敗時は呼び出し側で fail-closed(原文はコピーしない)
  const walk = (o) => {
    if (Array.isArray(o)) return o.map(walk);
    if (o && typeof o === "object") { const r = {}; for (const [k, v] of Object.entries(o)) r[k] = walk(v); return r; }
    if (typeof o === "string") { rec(o); return dummyJsonString(o.trim()); } // 配列要素・ネストも含め全 string をダミー化
    if (typeof o === "number") { rec(String(o)); return 0; } // 数値 secret(口座番号・PIN 等)も潰す
    return o; // bool / null は構造として保持
  };
  return JSON.stringify(walk(obj), null, 2) + "\n";
}

fs.mkdirSync(exampleDir, { recursive: true });
fs.writeFileSync(path.join(exampleDir, ".dummy-marker"), marker + "\n");

const secretFiles = () => fs.readdirSync(secretsDir);
let count = 0;
for (const f of secretFiles()) {
  if (f === ".gitkeep" || f === ".dummy-marker" || f === "ai.env") continue; // ai.env は方式Bのトークン(アプリ秘密でない)
  const abs = path.join(secretsDir, f);
  if (!fs.statSync(abs).isFile()) continue;
  const src = fs.readFileSync(abs, "utf8");
  let out;
  try {
    out = f.endsWith(".json") ? dummyJson(src) : dummyEnvFile(src);
  } catch {
    console.error(`FAIL: secrets/${f} を安全にダミー化できません(JSON 解析不能 or 複数行/非構造行)。**原文はコピーしません**。手動で secrets.example/${f} を用意してください。`);
    process.exit(2);
  }
  fs.writeFileSync(path.join(exampleDir, f), out); // ダミーの影は常に上書き(古い/漏れた内容を残さない)
  count++;
}

// 自己検査: 本物の値が secrets.example/ に1つも残っていないこと(値は出力しない)。
const exFiles = fs.readdirSync(exampleDir).filter((f) => fs.statSync(path.join(exampleDir, f)).isFile());
const uniq = [...new Set(allOriginals)];
let leaks = 0;
for (const f of exFiles) {
  const content = fs.readFileSync(path.join(exampleDir, f), "utf8");
  for (const v of uniq) if (content.includes(v)) { console.error(`LEAK: 本物の値が secrets.example/${f} に残っています`); leaks++; break; }
}
if (leaks) { console.error("secrets.example を破棄して修正が必要です。"); process.exit(2); }
console.log(`refresh-secrets: OK — ${count} 個のダミーを再生成、${uniq.length} 個の値を照合し残存なし`);

// 余剰(orphan)検出: 現在の secrets/ に対応しない古い secrets.example は過去の漏れを含みうる。
const expected = new Set([".dummy-marker", "links.json"]);
for (const f of secretFiles())
  if (f !== ".gitkeep" && f !== ".dummy-marker" && f !== "ai.env" && fs.statSync(path.join(secretsDir, f)).isFile())
    expected.add(f);
const orphans = exFiles.filter((f) => !expected.has(f));
if (orphans.length) {
  console.warn(`⚠️ secrets.example に現在の secrets/ と対応しない余剰ファイル: ${orphans.join(", ")}`);
  console.warn("   古い/漏れの恐れがある。内容を確認し、不要なら削除してください。");
}
