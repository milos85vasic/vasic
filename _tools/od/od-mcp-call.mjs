#!/usr/bin/env node
// Minimal MCP stdio client for the open-design-mcp server.
// Usage: node od-mcp-call.mjs <toolName> '<argsJSON>'
// Env: OD_DAEMON_URL (required for most tools); BYOK_* for od_generate_design.
// Keys are expected to already be in the environment (source ~/api_keys.sh first).
import { spawn } from 'node:child_process';

const [, , toolName, argsJson] = process.argv;
if (!toolName) { console.error('usage: od-mcp-call.mjs <tool> <argsJSON>'); process.exit(64); }
const SERVER = process.env.OD_MCP_SERVER || '/opt/homebrew/lib/node_modules/open-design-mcp/dist/src/server.js';
let args = {};
try { args = argsJson ? JSON.parse(argsJson) : {}; } catch (e) { console.error('bad argsJSON:', e.message); process.exit(64); }

const child = spawn(process.execPath, [SERVER], { stdio: ['pipe', 'pipe', 'inherit'], env: process.env });
let buf = '';
const pending = new Map();
let nextId = 1;
const send = (m) => child.stdin.write(JSON.stringify(m) + '\n');
const request = (method, params) => new Promise((res, rej) => { const id = nextId++; pending.set(id, { res, rej }); send({ jsonrpc: '2.0', id, method, params }); });

child.stdout.on('data', (d) => {
  buf += d;
  let i;
  while ((i = buf.indexOf('\n')) >= 0) {
    const line = buf.slice(0, i); buf = buf.slice(i + 1);
    if (!line.trim()) continue;
    let m; try { m = JSON.parse(line); } catch { continue; }
    if (m.id !== undefined && pending.has(m.id)) {
      const p = pending.get(m.id); pending.delete(m.id);
      m.error ? p.rej(new Error(JSON.stringify(m.error))) : p.res(m.result);
    }
  }
});

const TIMEOUT = Number(process.env.OD_TIMEOUT_MS || 600000);
const to = setTimeout(() => { console.error('TIMEOUT after', TIMEOUT, 'ms'); child.kill('SIGKILL'); process.exit(2); }, TIMEOUT);

try {
  await request('initialize', { protocolVersion: '2024-11-05', capabilities: {}, clientInfo: { name: 'od-cli', version: '0.0.1' } });
  send({ jsonrpc: '2.0', method: 'notifications/initialized' });
  const result = await request('tools/call', { name: toolName, arguments: args });
  clearTimeout(to);
  const txt = (result?.content || []).map((c) => c.text || '').join('\n');
  process.stdout.write(txt || JSON.stringify(result));
  process.stdout.write('\n');
  child.kill('SIGKILL');
  process.exit(result?.isError ? 1 : 0);
} catch (e) {
  clearTimeout(to);
  console.error('ERROR:', e.message);
  child.kill('SIGKILL');
  process.exit(1);
}
