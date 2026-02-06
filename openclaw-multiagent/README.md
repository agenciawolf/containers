# 🤖 OpenClaw Multi-Agent Container (RunPod Edition)

> **The Ultimate Autonomous Solver for Cloud GPUs**

This project is an **all-in-one** container designed to deploy swarms of **OpenClaw** agents running 100% locally via **Ollama**, specifically optimized for the **RunPod Community Cloud** infrastructure.

### 🎯 Project Goal
To allow developers and researchers to run **multiple simultaneous autonomous agents** (up to 10+) on a single powerful GPU (such as RTX 3090/4090 or A6000), sharing resources intelligently and efficiently.

### ✨ Key Features
- **🧠 Multiple Brains, One GPU:** Runs N isolated OpenClaw instances, sharing the same Ollama backend.
- **⚡ Optimized for RunPod:** Zero-touch configuration with automatic IP and port recognition.
- **📦 Complete Stack:** Includes OpenClaw (Frontend/Backend) + Ollama Server + Pre-configured Models (GLM-4 / Qwen).
- **💾 Smart Persistence:** Model cache and long-term memories survive Pod restarts.
- **🔧 Configurable via ENV:** Full control over agent behavior, model parameters, and VRAM consumption without touching config files.

---

## 🚀 Quick Start

```bash
# RunPod - Use the image directly
blacktech/openclaw-multiagent:latest

# MANDATORY Variable
OPENCLAW_WEB_PASSWORD=your_strong_password

# MANDATORY HTTP Ports (expose in RunPod)
# 18790 - Agent 1 (always)
# 18791 - Agent 2 (if NUM_AGENTS >= 2)
# 18792 - Agent 3 (if NUM_AGENTS >= 3)
# ... up to 18799 (max 10 agents)
```

**Default Port:** `18790` (first agent)

### 🔓 How to Access (First Time)

After the container starts (it may take ~30s to load models):

1. Go to the RunPod dashboard and click **Connect** > **Expose Port (18790)** or copy the Proxy URL.
2. The URL will look like: `https://{POD_ID}-18790.proxy.runpod.net/overview`
3. You will see a login screen.
4. **Input:** `Password (not stored)`
5. **Password:** Use the same password defined in the `OPENCLAW_WEB_PASSWORD` ENV.

> 💡 **Tip:** OpenClaw uses this password only to authenticate the local session in the browser.

---

## 📋 Table of Contents

1. [Environment Variables](#-environment-variables)
   - [Agent Configuration](#agent-configuration)
   - [Model Parameters](#model-parameters-api-request)
   - [Thinking/Behavior](#thinkingbehavior)
   - [Context & Memory](#context--memory)
   - [Ollama Server](#ollama-server---gpu--performance)
2. [VRAM Consumption](#-vram-consumption-glm-47-flash)
3. [GPU Presets](#-gpu-ready-presets)
4. [Ports & Access](#-ports--access)
5. [Persistence](#-data-persistence-runpod-volume)
6. [Security](#-security--isolation-architecture)
7. [Troubleshooting](#-troubleshooting)

# =============================================================================
# Architecture: Who Controls What?
# =============================================================================

```
┌─────────────────────────────────────────────────────────────┐
│                     OLLAMA SERVER                            │
│  ENV VARS control the SERVER:                                │
│  • OLLAMA_NUM_PARALLEL (simultaneous requests)               │
│  • OLLAMA_MAX_LOADED_MODELS (models in memory)               │
│  • OLLAMA_KV_CACHE_TYPE (cache type)                         │
│  • OLLAMA_FLASH_ATTENTION (GPU optimization)                 │
│  • OLLAMA_CONTEXT_LENGTH (default if not specified)          │
│  • OLLAMA_NUM_GPU (layers on GPU)                            │
│  • OLLAMA_MAX_QUEUE (request queue)                          │
│  • OLLAMA_DEBUG (log level)                                  │
└─────────────────────────────────────────────────────────────┘
                            ▲
                            │ API Request with params
                            │
┌─────────────────────────────────────────────────────────────┐
│                      OPENCLAW                                │
│  PARAMS are sent in the REQUEST:                             │
│  • temperature (creativity)                                  │
│  • top_p (nucleus sampling)                                  │
│  • repeat_penalty (repetition)                               │
│  • num_ctx (context window of this request)                  │
│  • think: true/false (reasoning mode)                        │
└─────────────────────────────────────────────────────────────┘
```

---

## ⚙️ Environment Variables

### Agent Configuration

| Variable | Default | Description |
|----------|---------|-----------|
| `OPENCLAW_WEB_PASSWORD` | **MANDATORY** | 🔐 Access password for dashboards |
| `OPENCLAW_NUM_AGENTS` | `3` | Number of agents (1-10) |
| `OPENCLAW_AGENT_PREFIX` | `agent` | Name prefix (e.g., `agent_1`) |
| `OPENCLAW_BASE_PORT` | `18790` | Port of the first agent |
| `OPENCLAW_MODEL` | `glm-4.7-flash:latest` | Ollama model to use |
| `OPENCLAW_MODEL_AUTO_PULL` | `true` | Automatically pull model |
| `OPENCLAW_WARMUP_ENABLED` | `true` | Preload model into VRAM |

---

### Model Parameters (API Request)

> ⚠️ **Important:** These parameters are sent by OpenClaw in each request to Ollama.

| Variable | Default | Description |
|----------|---------|-----------|
| `OPENCLAW_TEMPERATURE` | `0.7` | Creativity (0.0 = deterministic, 2.0 = very creative) |
| `OPENCLAW_TOP_P` | `0.95` | Nucleus sampling (0.0-1.0) |
| `OPENCLAW_REPEAT_PENALTY` | `1.0` | ⚠️ **CRITICAL:** Keep at `1.0` for GLM-4.7! |
| `OPENCLAW_NUM_CTX` | `131072` | 📏 Context window (tokens). **Adjust according to your GPU!** |
| `OPENCLAW_MAX_TOKENS` | `32768` | Max tokens in response |

> 💡 **Tip:** `OPENCLAW_NUM_CTX` is the most important parameter to adjust based on your GPU. See the [VRAM table](#-vram-consumption-glm-47-flash).

---

### Thinking/Behavior

| Variable | Default | Options | Description |
|----------|---------|--------|-----------|
| `OPENCLAW_THINKING_DEFAULT` | `on` | `on` / `off` | 🧠 Enable reasoning |
| `OPENCLAW_VERBOSE_DEFAULT` | `off` | `on` / `off` | Verbose mode |
| `OPENCLAW_ELEVATED_DEFAULT` | `on` | `on` / `off` | Elevated permissions |

---

### Context & Memory

| Variable | Default | Description |
|----------|---------|-----------|
| `OPENCLAW_CONTEXT_TOKENS` | `131072` | Conversation context token limit |
| `OPENCLAW_TIMEOUT_SECONDS` | `600` | Timeout per request (10 min) |
| `OPENCLAW_MAX_CONCURRENT` | `3` | Simultaneous requests per agent |

---

### Context Pruning (Advanced)

> 🧹 Automatic memory management when context gets too large.

| Variable | Default | Description |
|----------|---------|-----------|
| `OPENCLAW_PRUNING_MODE` | `adaptive` | `adaptive` / `aggressive` / `off` |
| `OPENCLAW_KEEP_LAST_ASSISTANTS` | `3` | How many recent responses to keep |
| `OPENCLAW_SOFT_TRIM_RATIO` | `0.3` | Soft trim ratio (30%) |
| `OPENCLAW_HARD_CLEAR_RATIO` | `0.5` | Hard clear ratio (50%) |

---

### Ollama Server - GPU & Performance

> 🖥️ **These variables control the Ollama server**, not request parameters.

| Variable | Default | Description |
|----------|---------|-----------|
| `OLLAMA_NUM_PARALLEL` | `4` | Simultaneous parallel requests |
| `OLLAMA_KV_CACHE_TYPE` | `q8_0` | Cache type: `q8_0` (saves ~40% VRAM), `f16` (max quality) |
| `OLLAMA_NUM_GPU` | `999` | Layers on GPU (999 = all) |
| `OLLAMA_KEEP_ALIVE` | `-1` | Time model stays in VRAM (-1 = always) |
| `OLLAMA_FLASH_ATTENTION` | `1` | Flash Attention (+30-50% speed) |
| `OLLAMA_MAX_LOADED_MODELS` | `1` | Simultaneous loaded models |
| `OLLAMA_CONTEXT_LENGTH` | `131072` | Server default context length |
| `OLLAMA_MAX_QUEUE` | `512` | Request queue before rejection |

---

### Ollama Server - Network & Logs

| Variable | Default | Description |
|----------|---------|-----------|
| `OLLAMA_HOST` | `0.0.0.0` | Network interface |
| `OLLAMA_PORT` | `11434` | Ollama server port |
| `OLLAMA_DEBUG` | `false` | `false` / `1` (debug) / `2` (trace) |
| `LOG_LEVEL` | `info` | General log level |

---

## 📊 VRAM Consumption (GLM-4.7-Flash)

> 📈 **The GLM-4.7-Flash model** uses ~17GB base + extra memory per context length.

| Context Length | Total VRAM | Recommended GPU |
|----------------|------------|-----------------|
| **4K tokens** | ~17 GB | RTX 3090 |
| **8K tokens** | ~18 GB | RTX 3090/4090 |
| **16K tokens** | ~19 GB | RTX 3090/4090 |
| **32K tokens** | ~20 GB | RTX 3090/4090/A5000 |
| **65K tokens** | ~23 GB | RTX 4090/A5000 |
| **86K tokens** | ~25 GB | RTX 6000 Ada |
| **131K tokens** | ~30 GB | A6000/RTX 6000 Ada |
| **200K tokens** | ~48 GB | A6000/H100/H200 |

> 💡 **MLA (Multi-Latent Attention)** of GLM-4.7 saves ~73% VRAM on KV cache compared to traditional models!

---

## 🎯 GPU Ready Presets

### RTX 3090 / RTX 4090 (24GB)

```env
OPENCLAW_NUM_CTX=65536
OPENCLAW_CONTEXT_TOKENS=65536
OLLAMA_CONTEXT_LENGTH=65536
OLLAMA_NUM_PARALLEL=2
```

### RTX A5000 (24GB)

```env
OPENCLAW_NUM_CTX=65536
OPENCLAW_CONTEXT_TOKENS=65536
OLLAMA_CONTEXT_LENGTH=65536
OLLAMA_NUM_PARALLEL=3
```

### RTX A6000 / RTX 6000 Ada (48GB)

```env
OPENCLAW_NUM_CTX=131072
OPENCLAW_CONTEXT_TOKENS=131072
OLLAMA_CONTEXT_LENGTH=131072
OLLAMA_NUM_PARALLEL=4
```

### H100 / H200 (80GB)

```env
OPENCLAW_NUM_CTX=200000
OPENCLAW_CONTEXT_TOKENS=200000
OLLAMA_CONTEXT_LENGTH=200000
OLLAMA_KV_CACHE_TYPE=f16
OLLAMA_NUM_PARALLEL=6
```

---

## 🌐 Ports & Access

| Port | Service | Public Expose? | Description |
|-------|---------|----------------|-----------|
| `18790` | Agent 1 | **YES (Mandatory)** | Agent 1 Web Dashboard |
| `18791` | Agent 2 | **YES (Mandatory)** | If `NUM_AGENTS >= 2` |
| `18792` | Agent 3 | **YES (Mandatory)** | If `NUM_AGENTS >= 3` |
| `11434` | Ollama API | **NO (Optional)** | Use only if you need direct API access (debug). OpenClaw uses this port internally via `localhost`. |

### Example with 5 Agents

```env
OPENCLAW_NUM_AGENTS=5
OPENCLAW_WEB_PASSWORD=my_secure_password
```

Result:
- `agent_1` → port **18790** (Expose TCP Port)
- `agent_2` → port **18791** (Expose TCP Port)
- ...
- `agent_5` → port **18794** (Expose TCP Port)

---

## 💾 Data Persistence (RunPod Volume)

To properly save your memories, conversations, and downloaded models when restarting the pod, you **MUST** configure the Volume Path correctly.

1. In the RunPod Template, configure **Volume Mount Path**: `/workspace`
2. Ensure your Container Disk Size is sufficient (minimum 50GB recommended).

**What is saved in `/workspace`:**
```
/workspace/
├── .ollama/models/      # Downloaded LLM models (avoids re-downloading every restart)
├── agents/              # 🧠 AGENT BRAINS (Memories, sessions, configs)
│   └── agent_1/
│       ├── .openclaw/   # Local agent configurations
│       └── workspace/   # Agent generated files
├── logs/                # Log history for debugging
└── .cache/              # System caches (npm, pip, cuda)
```

> ⚠️ **Warning:** If you do not mount the volume at `/workspace`, all data will be lost when the Pod is turned off!

### 💡 Pro Tip: RunPod Network Volumes (NFS)
If you use **Secure Cloud**, we strongly recommend using a **Network Volume**.
1. Create a Network Volume in your region.
2. Mount it at `/workspace` in your template.
3. **Benefit:** You can destroy the Pod, create another (even with a different GPU), and **all your memories, agents, and history will be there intact**. This is the ultimate form of persistence.

---

## 🔒 Security & Isolation Architecture

To ensure one agent does not interfere with another's memories or files, we implemented a rigorous isolation architecture:

### 1. 🧠 Isolated Memories and Vector DB
Each agent has its own vector database (LanceDB/Chroma) located in its private directory.
- **Benefit:** `Agent 1` (e.g., Coder) will never mix knowledge with `Agent 2` (e.g., Writer).
- **Path:** `/workspace/agents/agent_{N}/.openclaw/memory`

### 2. 📂 Separate Workspaces
Each agent operates in an exclusive working directory (`CWD`).
- **Benefit:** Created files, generated code, and downloads are segregated.
- **Structure:**
  ```text
  /workspace/agents/
  ├── agent_1/ (Port 18790) 🔒 Private
  ├── agent_2/ (Port 18791) 🔒 Private
  └── ...
  ```

### 3. 🔑 Unique Auth Tokens
The system automatically generates a unique **Service Token** for each agent at startup.
- This prevents malicious scripts in one agent from controlling another agent via API.
- Tokens saved in: `/workspace/agents/agent_{N}/.openclaw/token`

---

## 🧱 Security Features

- ✅ **Mandatory Password** - No insecure fallback
- ✅ **Unique Tokens** - Each agent has its own token
- ✅ **Masked Logs** - Passwords do not appear in logs
- ✅ **Trusted Proxies** - Configured for internal networks
- ✅ **Automatic CORS** - Accepts RunPod Proxy connections
- ✅ **RunPod Auto-detection** - Displays correct access URLs

---

## 🐛 Troubleshooting

### Error: "Out of memory"

Reduce context:
```env
OPENCLAW_NUM_CTX=65536
OLLAMA_CONTEXT_LENGTH=65536
```

### Error: "1008 origin not allowed"

Already fixed automatically! If it persists, verify you are using the latest image.

### Model does not load

```env
OPENCLAW_MODEL_AUTO_PULL=true
OPENCLAW_WARMUP_ENABLED=true
```

### Slow performance

```env
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KV_CACHE_TYPE=q8_0
OLLAMA_NUM_PARALLEL=2
```

---

## 📝 Logs

```bash
# Agent 1 Logs
tail -f /workspace/logs/agent_1.log

# Ollama Logs
tail -f /workspace/logs/ollama.log

# Via supervisorctl
supervisorctl tail -f openclaw-agent_1
```

---

## 📜 License

MIT License - OpenClaw © 2024-2026

---

## 🔗 Useful Links

- [OpenClaw Documentation](https://docs.openclaw.ai)
- [Ollama Documentation](https://ollama.com)
- [RunPod Templates](https://runpod.io/console/templates)
