"""Minimal OpenAI SDK client for CLIProxyAPI. Requires: pip install openai."""
import os

from openai import OpenAI

client = OpenAI(
    base_url=os.environ.get("PROXY_URL", "http://127.0.0.1:8317") + "/v1",
    api_key=os.environ["PROXY_KEY"],
)
model = os.environ.get("PROXY_MODEL") or client.models.list().data[0].id
reply = client.chat.completions.create(
    model=model, messages=[{"role": "user", "content": "Reply with one word: ready"}]
)
print(model, "->", reply.choices[0].message.content)
