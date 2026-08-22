// Does the Nomad app container reach the GPU Ollama over the compose network?
fetch("http://ollama:11434/api/tags")
  .then((r) => r.json())
  .then((d) => {
    console.log("REACHABLE - models:", d.models.map((m) => m.name).join(", "));
  })
  .catch((e) => console.log("UNREACHABLE:", e.message));
