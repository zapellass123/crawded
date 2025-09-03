// luarmor_loader.mjs
import fetch from "node-fetch";
import { writeFileSync } from "fs";

export async function loadLuarmorLibrary(scriptId) {
  // 1. Download library.lua dari Luarmor
  const url = "https://sdkapi-public.luarmor.net/library.lua";
  const res = await fetch(url);
  console.log(`Fetching from ${url}...`);
  if (!res.ok) throw new Error(`Failed to fetch ${url}: ${res.status}`);
  const luaSource = await res.text();

  // 2. Simpan source ke file
  writeFileSync("library.lua", luaSource, "utf8");
  console.log("✅ library.lua berhasil disimpan.");

  // 3. Return data
  return {
    scriptId,
    source: luaSource,
  };
}

// === Example run ===
// if (import.meta.url === `file://${process.argv[1]}`) {
(async () => {
  // const scriptId = process.argv[2] || "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
  const scriptId = "5ef4906f230aa87d747191682bd77c38";
  const result = await loadLuarmorLibrary(scriptId);
  console.log("Script ID:", result.scriptId);
  console.log("Source (first 200 chars):\n", result.source.slice(0, 200));
})();
// }
