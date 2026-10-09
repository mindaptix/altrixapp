import http from 'node:http';
import { readFileSync } from 'node:fs';

// Local development only: loopback binding, no provider key in Flutter.
try {
  for (const line of readFileSync(new URL('.env', import.meta.url), 'utf8').split('\n')) {
    const match = line.match(/^([A-Z_]+)=(.*)$/);
    if (match && !process.env[match[1]]) process.env[match[1]] = match[2].trim();
  }
} catch (error) {
  if (error.code !== 'ENOENT') throw error;
}

const systemPrompt = `You are Altrixs Help, a concise and friendly app assistant.
The app has Home, Schedule, Messages and Me tabs. Help with appointments,
video visits, messaging and profile settings. You cannot access patient records,
change appointments, send messages or contact a care team. Never claim you did.
Do not invent clinic contact details or provide diagnoses or medication changes.
For medical questions, suggest contacting the clinician. If someone is in
immediate danger, encourage local emergency services. Do not request sensitive
patient information. Answer only based on the conversation and these facts.`;

export function createChatbotServer({ apiKey, fetchImpl = fetch, model = 'openai/gpt-oss-20b' } = {}) {
  return http.createServer(async (req, res) => {
    const send = (status, data) => {
      res.writeHead(status, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(data));
    };
    if (req.method !== 'POST' || req.url !== '/api/patient/chatbot') {
      return send(404, { error: 'Not found' });
    }
    if (!apiKey) return send(503, { error: 'Assistant is not configured' });
    let body = '';
    try {
      for await (const chunk of req) {
        body += chunk;
        if (Buffer.byteLength(body) > 20000) return send(413, { error: 'Message too large' });
      }
      const { messages } = JSON.parse(body);
      if (!Array.isArray(messages) || messages.length < 1 || messages.length > 12 ||
          messages.some(m => !m || !['user', 'assistant'].includes(m.role) ||
            typeof m.content !== 'string' || !m.content.trim() || m.content.length > 1000) ||
          messages.at(-1).role !== 'user') {
        return send(400, { error: 'Invalid conversation' });
      }
      const upstream = await fetchImpl('https://api.groq.com/openai/v1/chat/completions', {
        method: 'POST',
        headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
        body: JSON.stringify({
          model, messages: [{ role: 'system', content: systemPrompt }, ...messages],
          temperature: 0.4, max_completion_tokens: 500,
        }),
        signal: AbortSignal.timeout(35000),
      });
      if (!upstream.ok) return send(upstream.status === 429 ? 429 : 503, { error: 'Assistant unavailable' });
      const data = await upstream.json();
      const reply = data.choices?.[0]?.message?.content;
      if (typeof reply !== 'string' || !reply.trim()) return send(503, { error: 'Empty assistant reply' });
      return send(200, { data: { reply } });
    } catch (error) {
      return send(error instanceof SyntaxError ? 400 : 503, { error: 'Unable to process message' });
    }
  });
}

if (process.argv[1] && import.meta.url === new URL(process.argv[1], 'file:').href) {
  createChatbotServer({ apiKey: process.env.GROQ_API_KEY, model: process.env.GROQ_MODEL })
    .listen(8787, '127.0.0.1', () => console.log('Chatbot development proxy: http://127.0.0.1:8787'));
}
