const { TelegramClient, Api } = require("telegram");
const { StringSession } = require("telegram/sessions");
const { NewMessage } = require("telegram/events");
const express = require("express");
const bodyParser = require("body-parser");
const fs = require("fs");
const path = require("path");

const app = express();
app.use(bodyParser.json());

const PORT = process.env.TG_PORT || 3003;
const SESSION_FILE = path.join(
  process.env.HOME || ".",
  ".tg_ai_session"
);

let client = null;
let apiId = null;
let apiHash = null;
let phoneNumber = null;
let phoneCodePromise = null; // resolve function for code input
let loggedIn = false;
let messageCallbacks = []; // pending long-poll requests

// 读取保存的session
function loadSession() {
  try {
    if (fs.existsSync(SESSION_FILE)) {
      return fs.readFileSync(SESSION_FILE, "utf-8").trim();
    }
  } catch (_) {}
  return "";
}

function saveSession(session) {
  try {
    fs.writeFileSync(SESSION_FILE, session, "utf-8");
  } catch (_) {}
}

// === API Routes ===

// 健康检查
app.get("/healthz", (req, res) => {
  res.json({ status: loggedIn ? "logged_in" : "not_logged_in" });
});

// 初始化客户端 + 发送验证码
app.post("/auth/request-code", async (req, res) => {
  try {
    apiId = parseInt(req.body.apiId);
    apiHash = req.body.apiHash;
    phoneNumber = req.body.phone;

    if (!apiId || !apiHash || !phoneNumber) {
      return res.status(400).json({ error: "缺少 apiId, apiHash 或 phone" });
    }

    const session = new StringSession(loadSession());
    client = new TelegramClient(session, apiId, apiHash, {
      connectionRetries: 3,
    });

    await client.connect();

    // 检查是否已经登录（session还有效）
    try {
      const me = await client.getMe();
      if (me) {
        loggedIn = true;
        saveSession(client.session.save());
        startMessageListener();
        return res.json({
          success: true,
          alreadyLoggedIn: true,
          user: {
            id: me.id?.toString(),
            firstName: me.firstName,
            lastName: me.lastName,
            username: me.username,
            phone: me.phone,
          },
        });
      }
    } catch (_) {
      // session无效，继续登录流程
    }

    // 发送验证码
    const result = await client.sendCode(
      { apiId, apiHash },
      phoneNumber
    );

    // 保存phoneCodeHash用于验证
    app.locals.phoneCodeHash = result.phoneCodeHash;

    res.json({ success: true, message: "验证码已发送" });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

// 验证码校验
app.post("/auth/verify-code", async (req, res) => {
  try {
    const code = req.body.code;
    if (!code || !client) {
      return res.status(400).json({ error: "缺少验证码或客户端未初始化" });
    }

    try {
      await client.invoke(
        new Api.auth.SignIn({
          phoneNumber: phoneNumber,
          phoneCodeHash: app.locals.phoneCodeHash,
          phoneCode: code,
        })
      );
    } catch (e) {
      // 可能需要2FA密码
      if (e.errorMessage === "SESSION_PASSWORD_NEEDED") {
        return res.status(200).json({
          success: false,
          needPassword: true,
          message: "需要两步验证密码",
        });
      }
      throw e;
    }

    loggedIn = true;
    saveSession(client.session.save());
    startMessageListener();

    const me = await client.getMe();
    res.json({
      success: true,
      user: {
        id: me.id?.toString(),
        firstName: me.firstName,
        lastName: me.lastName,
        username: me.username,
        phone: me.phone,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

// 两步验证密码
app.post("/auth/verify-password", async (req, res) => {
  try {
    const password = req.body.password;
    if (!password || !client) {
      return res.status(400).json({ error: "缺少密码" });
    }

    await client.signInWithPassword(
      { apiId, apiHash },
      { password: () => password }
    );

    loggedIn = true;
    saveSession(client.session.save());
    startMessageListener();

    const me = await client.getMe();
    res.json({
      success: true,
      user: {
        id: me.id?.toString(),
        firstName: me.firstName,
        username: me.username,
      },
    });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

// 发送消息
app.post("/send", async (req, res) => {
  try {
    if (!client || !loggedIn) {
      return res.status(401).json({ error: "未登录" });
    }

    const { peerId, text } = req.body;
    if (!peerId || !text) {
      return res.status(400).json({ error: "缺少 peerId 或 text" });
    }

    await client.sendMessage(peerId, { message: text });
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

// 长轮询获取新消息
app.get("/messages", (req, res) => {
  if (!client || !loggedIn) {
    return res.status(401).json({ error: "未登录" });
  }

  // 如果有缓存的消息直接返回
  if (pendingMessages.length > 0) {
    const msgs = [...pendingMessages];
    pendingMessages = [];
    return res.json({ messages: msgs });
  }

  // 长轮询：等5秒，有消息就返回
  const timeout = setTimeout(() => {
    res.json({ messages: [] });
    const idx = messageCallbacks.indexOf(cb);
    if (idx >= 0) messageCallbacks.splice(idx, 1);
  }, 5000);

  const cb = (msgs) => {
    clearTimeout(timeout);
    res.json({ messages: msgs });
  };
  messageCallbacks.push(cb);
});

// 退出登录
app.post("/logout", async (req, res) => {
  try {
    if (client) {
      await client.disconnect();
    }
    loggedIn = false;
    // 删除session文件
    try { fs.unlinkSync(SESSION_FILE); } catch (_) {}
    res.json({ success: true });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

// === 消息监听 ===
let pendingMessages = [];

function startMessageListener() {
  if (!client) return;

  console.log("Starting message listener...");

  client.addEventHandler(async (event) => {
    const msg = event.message;
    if (!msg) return;

    // 跳过自己发的
    if (msg.out) return;

    console.log(`New message from ${msg.senderId}: ${msg.text}`);

    let sender = null;
    let chat = null;
    try { sender = await msg.getSender(); } catch(_) {}
    try { chat = await msg.getChat(); } catch(_) {}

    const parsed = {
      id: msg.id,
      text: msg.text || "",
      fromId: sender?.id?.toString() || "",
      fromName:
        sender?.firstName ||
        sender?.title ||
        sender?.username ||
        "",
      chatId: chat?.id?.toString() || "",
      chatName:
        chat?.title ||
        chat?.firstName ||
        chat?.username ||
        "",
      isPrivate: msg.isPrivate,
      isMentioned: msg.mentioned || false,
      date: msg.date,
    };

    // 如果有等待中的长轮询请求，直接推送
    if (messageCallbacks.length > 0) {
      const cb = messageCallbacks.shift();
      cb([parsed]);
    } else {
      // 缓存（最多100条）
      pendingMessages.push(parsed);
      if (pendingMessages.length > 100) pendingMessages.shift();
    }
  }, new NewMessage({}));

  console.log("Message listener started.");
}

// === 启动 ===
app.listen(PORT, () => {
  console.log(`Telegram service running on port ${PORT}`);

  // 尝试用保存的session自动登录
  const savedSession = loadSession();
  if (savedSession) {
    (async () => {
      try {
        // 需要apiId和apiHash才能重连，从env或配置读取
        const envApiId = parseInt(process.env.TG_API_ID || "0");
        const envApiHash = process.env.TG_API_HASH || "";
        if (envApiId && envApiHash) {
          apiId = envApiId;
          apiHash = envApiHash;
          const session = new StringSession(savedSession);
          client = new TelegramClient(session, apiId, apiHash, {
            connectionRetries: 3,
          });
          await client.connect();
          const me = await client.getMe();
          if (me) {
            loggedIn = true;
            console.log(`Auto-logged in as ${me.firstName} (@${me.username})`);
            startMessageListener();
          }
        }
      } catch (e) {
        console.log("Auto-login failed, need manual login:", e.message);
      }
    })();
  }
});
