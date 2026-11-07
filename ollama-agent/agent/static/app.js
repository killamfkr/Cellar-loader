let sessionId = null;

const transcript = document.getElementById("transcript");
const promptEl = document.getElementById("prompt");
const modelSelect = document.getElementById("modelSelect");
const healthStatus = document.getElementById("healthStatus");
const sessionLabel = document.getElementById("sessionLabel");
const sendBtn = document.getElementById("sendBtn");

function addBubble(kind, text, html = false) {
  const div = document.createElement("div");
  div.className = `bubble ${kind}`;
  if (html) div.innerHTML = text;
  else div.textContent = text;
  transcript.appendChild(div);
  transcript.scrollTop = transcript.scrollHeight;
  return div;
}

async function loadHealth() {
  try {
    const r = await fetch("/api/health");
    const data = await r.json();
    if (data.ok) {
      healthStatus.textContent = `Ollama connected · ${data.models.length} model(s)`;
      healthStatus.className = "status ok";
    } else {
      healthStatus.textContent = `Ollama unreachable: ${data.error || "unknown"}`;
      healthStatus.className = "status bad";
    }
  } catch (e) {
    healthStatus.textContent = `API error: ${e.message}`;
    healthStatus.className = "status bad";
  }
}

async function loadModels() {
  const r = await fetch("/api/models");
  const data = await r.json();
  const models = data.models || [];
  const current = modelSelect.value;
  modelSelect.innerHTML = "";
  if (!models.length) {
    const opt = document.createElement("option");
    opt.value = "";
    opt.textContent = "(no models — pull one)";
    modelSelect.appendChild(opt);
    return;
  }
  for (const m of models) {
    const opt = document.createElement("option");
    opt.value = m;
    opt.textContent = m;
    modelSelect.appendChild(opt);
  }
  if (current && models.includes(current)) modelSelect.value = current;
}

document.getElementById("refreshModels").addEventListener("click", loadModels);

document.getElementById("pullBtn").addEventListener("click", async () => {
  const name = document.getElementById("pullModel").value.trim();
  if (!name) return;
  const log = document.getElementById("pullLog");
  log.textContent = `Pulling ${name}…\n`;
  const r = await fetch("/api/models/pull", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ model: name }),
  });
  const reader = r.body.getReader();
  const decoder = new TextDecoder();
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    const chunk = decoder.decode(value);
    for (const line of chunk.split("\n")) {
      if (!line.trim()) continue;
      try {
        const j = JSON.parse(line);
        if (j.status) log.textContent += j.status + "\n";
        if (j.error) log.textContent += `Error: ${j.error}\n`;
      } catch (_) {
        log.textContent += line + "\n";
      }
    }
  }
  await loadModels();
  modelSelect.value = name;
});

document.getElementById("composer").addEventListener("submit", async (e) => {
  e.preventDefault();
  const message = promptEl.value.trim();
  if (!message) return;

  sendBtn.disabled = true;
  addBubble("user", message);
  promptEl.value = "";

  const thinking = addBubble("thinking", "Agent is working…");

  const body = {
    message,
    session_id: sessionId,
    model: modelSelect.value || undefined,
  };

  try {
    const r = await fetch("/api/chat/stream", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(body),
    });

    const reader = r.body.getReader();
    const decoder = new TextDecoder();
    let buffer = "";
    let assistantBubble = null;

    while (true) {
      const { done, value } = await reader.read();
      if (done) break;
      buffer += decoder.decode(value, { stream: true });
      const parts = buffer.split("\n\n");
      buffer = parts.pop() || "";
      for (const part of parts) {
        if (!part.startsWith("data: ")) continue;
        const payload = JSON.parse(part.slice(6));
        if (payload.type === "session") {
          sessionId = payload.session_id;
          sessionLabel.textContent = `Session ${sessionId.slice(0, 8)}…`;
        } else if (payload.type === "tool_call") {
          const args = JSON.stringify(payload.data.arguments || {}, null, 2);
          addBubble(
            "tool",
            `▸ ${payload.data.name}\n${args}`,
          );
        } else if (payload.type === "tool_result") {
          addBubble("tool", `✓ ${payload.data.name}\n${payload.data.result}`);
        } else if (payload.type === "assistant_message") {
          thinking.remove();
          assistantBubble = addBubble("assistant", payload.data.content);
        } else if (payload.type === "done") {
          thinking.remove();
        }
      }
    }
    if (!assistantBubble) thinking.remove();
  } catch (err) {
    thinking.remove();
    addBubble("assistant", `Error: ${err.message}`);
  } finally {
    sendBtn.disabled = false;
  }
});

loadHealth();
loadModels();
