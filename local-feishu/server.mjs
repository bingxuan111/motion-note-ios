/**
 * Personal, local-only OAuth relay for Motion Note.
 * It deliberately keeps the Feishu App Secret on this Mac and never in the iPhone app.
 */
import crypto from "node:crypto";
import http from "node:http";
import { URL, URLSearchParams } from "node:url";

const port = Number(process.env.PORT || 8787);
const appId = process.env.FEISHU_APP_ID || "cli_aaf6d50ac2f95be2";
const appSecret = process.env.FEISHU_APP_SECRET;
const publicBaseURL = (process.env.PUBLIC_BASE_URL || "").replace(/\/$/, "");
const states = new Map();

if (!appSecret) {
  console.error("Missing FEISHU_APP_SECRET. Start through ./start-local-relay.sh so it is entered privately.");
  process.exit(1);
}
if (!publicBaseURL.startsWith("https://")) {
  console.error("Missing PUBLIC_BASE_URL. It must be the HTTPS address printed by your tunnel.");
  process.exit(1);
}

function html(title, body) {
  return `<!doctype html><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title}</title><main style="max-width:560px;margin:72px auto;padding:24px;font-family:-apple-system,BlinkMacSystemFont,sans-serif"><h1>${title}</h1><p>${body}</p></main>`;
}
function send(res, status, body, type = "text/html; charset=utf-8") {
  res.writeHead(status, { "content-type": type, "cache-control": "no-store" });
  res.end(body);
}
async function exchangeCode(code) {
  const response = await fetch("https://open.feishu.cn/open-apis/authen/v2/oauth/token", {
    method: "POST",
    headers: { "content-type": "application/json; charset=utf-8" },
    body: JSON.stringify({ grant_type: "authorization_code", client_id: appId, client_secret: appSecret, code, redirect_uri: `${publicBaseURL}/feishu/callback` })
  });
  const payload = await response.json();
  if (!response.ok || payload.code) throw new Error(payload.msg || `token request failed (${response.status})`);
  return payload;
}

http.createServer(async (req, res) => {
  const requestURL = new URL(req.url, `http://${req.headers.host}`);
  if (requestURL.pathname === "/health") return send(res, 200, JSON.stringify({ ok: true }), "application/json");
  if (requestURL.pathname === "/feishu/start") {
    const state = crypto.randomBytes(32).toString("base64url");
    states.set(state, Date.now());
    const authorizationURL = new URL("https://accounts.feishu.cn/open-apis/authen/v1/authorize");
    authorizationURL.search = new URLSearchParams({
      client_id: appId,
      redirect_uri: `${publicBaseURL}/feishu/callback`,
      state,
      scope: "offline_access"
    }).toString();
    res.writeHead(302, { location: authorizationURL.toString(), "cache-control": "no-store" });
    return res.end();
  }
  if (requestURL.pathname !== "/feishu/callback") return send(res, 404, html("页面不存在", "请从 Motion Note 中发起飞书连接。"));

  const code = requestURL.searchParams.get("code");
  const state = requestURL.searchParams.get("state");
  if (!code || !state) return send(res, 400, html("授权未完成", "飞书没有返回授权码，请回到 App 再试一次。"));
  const startedAt = states.get(state);
  states.delete(state);
  if (!startedAt || Date.now() - startedAt > 10 * 60 * 1000) return send(res, 400, html("授权已过期", "请回到 Motion Note 再试一次。"));
  try {
    // The resulting token remains only in this running process for the MVP.
    // Persistent encrypted storage is added together with document import.
    await exchangeCode(code);
    res.writeHead(302, { location: "motionnote://feishu-connected?success=1", "cache-control": "no-store" });
    res.end();
  } catch (error) {
    console.error("Feishu OAuth callback failed:", error.message);
    send(res, 500, html("连接没有完成", "请回到 Motion Note 重试；终端中有不含密钥的错误说明。"));
  }
}).listen(port, "127.0.0.1", () => {
  console.log(`Motion Note local Feishu relay listening on http://127.0.0.1:${port}`);
  console.log(`Configured callback: ${publicBaseURL}/feishu/callback`);
});
