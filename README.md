# AI Local Project with Ollama and LangChain

This project provides a local environment using Docker to run LLMs via **Ollama** and integrate them into Python applications using **LangChain**.

---

## Requirements

Before running the project, make sure you have the following installed on your host machine:

* **Docker** — the container runtime. [Install guide](https://docs.docker.com/engine/install/).
* **Docker Compose** — used to orchestrate the services in this project. Recent Docker installs include it as the `docker compose` plugin; this project's commands use the standalone `docker-compose` (v1) syntax, so adjust if yours differs.
* **NVIDIA Container Toolkit** — **only required if you want GPU acceleration on an NVIDIA GPU.** It lets the Ollama container access your host GPU. Setup is fully documented in [README.gpu.md](./README.gpu.md). The project runs fine on CPU without it — just slower.

> **Note on GPU vendors:** This project's GPU instructions assume an **NVIDIA** GPU (the most common for local AI, via CUDA). AMD (via ROCm) and Apple Silicon (via Metal) are also supported by Ollama, but they require a different setup that is **not covered here** — see the [Ollama GPU docs](https://github.com/ollama/ollama/blob/main/docs/gpu.md) for those.

---

## 1. Running the Ollama Chat via Terminal

If you want to interact with the models directly through your terminal without running the entire application, follow these steps:

1. **Start only the Ollama container:**
   ```bash
   docker-compose up -d ollama-service
   ```

2. **Access the container and run the model:**
   ```bash
   docker exec -it ollama-service ollama run gemma4
   ```

   > **Note:** The first time you run a model, Ollama needs to download it before the chat starts. This can take several minutes depending on the model size and your connection. Subsequent runs load instantly from cache.

   > **Which variant does `gemma4` pull?** Running `ollama run gemma4` (or `ollama pull gemma4`) without a tag downloads `gemma4:latest`, which is the **E4B** variant (~4.5B effective parameters). If you see `gemma4:latest` in `ollama list`, that is the E4B. To use a specific size, always pass an explicit tag (e.g. `gemma4:e2b`). See the variants table below.
   >
   > **Download size vs VRAM:** these are two different numbers. The **download** is the size of the model file on disk (the E4B is roughly 9–10 GB). The **VRAM** figure in the table below (~4.5 GB for E4B) is how much GPU memory the weights occupy at runtime in Q4_0 quantization. Don't confuse the two — and remember the running footprint grows further once the context window is added.

   By default, Gemma 4 runs in **thinking mode**, displaying a visible `Thinking...` reasoning block before the final answer. This is useful for complex logic, math, and coding, but verbose for everyday chat.

   * **To disable reasoning (direct answers):** start the model with thinking turned off:
     ```bash
     docker exec -it ollama-service ollama run gemma4 --think=false
     ```
     Or, while already inside a chat session, toggle it off with:
     ```
     /set nothink
     ```
     (Use `/set think` to turn it back on.)

   > **Tip:** Thinking-mode control requires a recent Ollama version. Check yours with `docker exec -it ollama-service ollama --version` and update if the flag isn't recognized. To confirm the exact model tag you pulled, run `docker exec -it ollama-service ollama list`.

   **Gemma 4 variants by target device.** The Gemma 4 family ships in **five** sizes for different hardware. Pick the one that matches your RAM/VRAM. VRAM figures below are the official approximate values for loading the model weights at **Q4_0 (4-bit)** quantization — actual usage is higher once you add the context window (KV cache) and runtime overhead.

   | Variant | VRAM (Q4_0) | Target device | Multimodality | Context |
   | --- | --- | --- | --- | --- |
   | **E2B** | ~2.9 GB | Ultra-mobile / edge / browser (e.g. Pixel, Chrome) | Text + image + audio | 128K |
   | **E4B** (`latest`) | ~4.5 GB | Edge / laptop | Text + image + audio | 128K |
   | **12B** | ~6.7 GB | Local desktop (mid-range GPU) | Text + image + audio | 256K |
   | **26B-A4B** | ~14.4 GB | Desktop (RTX 3090/4090, 32 GB Apple Silicon) | Text + image + video | 256K |
   | **31B** | ~17.5 GB | Workstation / server / cloud | Text + image + video | 256K |

   > The `E` prefix means *Efficient* (edge-optimized); E2B and E4B report "effective" parameter counts (~2B and ~4B) but use Per-Layer Embeddings (PLE), so their real memory footprint is larger than the effective parameter count suggests. `26B-A4B` is a Mixture-of-Experts model: 26B total parameters but only ~4B active per token — note all 26B must still be loaded into memory. The `12B` is a unified dense model that handles multimodal tasks via direct linear projections instead of separate vision/audio encoders.
   >
   > VRAM numbers reflect model weights only (with ~20% loading overhead) and exclude the context window — larger `num_ctx` values consume significantly more. Pull a specific variant with its tag, e.g. `ollama run gemma4:e2b` or `ollama run gemma4:26b-a4b`. Figures are from Google's official [Gemma 4 overview](https://ai.google.dev/gemma/docs/core) and may change with tooling — confirm on the [Ollama library](https://ollama.com/library) and with `ollama show <model>`.

   **Other popular open-source models** you can swap in (replace `gemma4` in the command above):

   | Model | Pull command | Best for |
   | --- | --- | --- |
   | **Gemma 4** (Google) | `ollama run gemma4:e4b` | Multimodal (text + image), tool calling, general use |
   | **Qwen3** (Alibaba) | `ollama run qwen3:30b` | Strong all-rounder: chat, reasoning, coding, tool use |
   | **Llama 4 Scout** (Meta) | `ollama run llama4:scout` | Long context, large multimodal (needs lots of VRAM) |
   | **DeepSeek-R1** (DeepSeek) | `ollama run deepseek-r1` | Reasoning / chain-of-thought tasks |
   | **Qwen2.5 Coder** (Alibaba) | `ollama run qwen2.5-coder:32b` | Coding (high HumanEval score) |
   | **gpt-oss** (OpenAI) | `ollama run gpt-oss:20b` | Reasoning on smaller hardware (~16 GB), adjustable reasoning |
   | **Llama 3.2** (Meta) | `ollama run llama3.2:3b` | Lightweight, runs on modest hardware; most-downloaded model |

   > Pick the model that fits your hardware (RAM/VRAM) and task. Larger models are not always better for quick local tasks — start small and scale up only if needed. Always confirm the current tag on the [Ollama library](https://ollama.com/library), since tags change over time.

   > **Official documentation:** for authoritative details on the Gemma 4 family — architectures, memory requirements, quantization, and capabilities — see Google's [Gemma 4 model overview](https://ai.google.dev/gemma/docs/core) and the [Ollama integration guide](https://ai.google.dev/gemma/docs/integrations/ollama).

3. **Interaction:**
   After the initial download of your chosen variant, the chat interface will appear directly in your terminal. You can type your prompts and receive responses in real-time.
   
   **To exit the chat conversation** and return to your terminal, type `/exit` and press `Enter` (or press `Ctrl + D`).

4. **Stopping the service:**
   To stop the container, use:
   ```bash
   docker-compose stop ollama-service
   ```

---

## 2. Optional: Running via Open WebUI (Graphical Interface)

As an alternative to the terminal chat, you can choose to spin up **Open WebUI**. This provides a full ChatGPT-like web interface that connects directly to your local Ollama backend.

### What Open WebUI adds to your workflow:
* **Persistent History:** Automatically saves all your chats, allowing you to resume any conversation later.
* **Topic Organization:** Categorizes and splits your chats into different topics and history sidebars just like commercial web AI tools.
* **Document Uploads (RAG UI):** Allows you to drag and drop PDFs, text files, or URLs to chat with your private data natively through the browser.
* **User Management:** Multiple local accounts can be created, all securely stored offline on your machine.

### How to use it:

1. **Start the Open WebUI container:**
   ```bash
   docker-compose up -d open-webui
   ```

2. **Access the interface:**
   Open your web browser and navigate to **`http://localhost:3000`**.

3. **First-time Setup:**
   Click to sign up and create a local administrator account (Name, Email, and Password). This setup is **100% offline** and your credentials never leave your machine.

4. **Chatting:**
   Select your desired model (e.g., `gemma4`) from the dropdown list at the top of the interface and start typing your prompts.

5. **Stopping the interface:**
   To stop the web interface service, use:
   ```bash
   docker-compose stop open-webui
   ```

---

## 3. Optional: Creating a Custom Model

Sometimes the default model parameters aren't ideal for your use case. For example, the default context window may be too small for very large prompts, causing Ollama to **truncate** your input (cutting off part of the prompt before the model even sees it). You can create a custom model based on any existing one, with your own baked-in parameters.

This example creates `custom-gemma4-e4b`, based on `gemma4:e4b`, with a larger context window and response limit — useful for long prompts (e.g. extracting a structured JSON list from a big document).

1. **Make sure the base model is already downloaded.** The custom model builds on top of it (`FROM gemma4:e4b`), so the base must exist locally first.
   If you've already pulled or run `gemma4:e4b` before, it's cached — **skip this step**. Otherwise, download it:
   ```bash
   docker exec -it ollama-service ollama pull gemma4:e4b
   ```
 
   > **Tip:** Running this when the model is already present does no harm — Ollama just verifies it's up to date and exits quickly, without re-downloading. You can check what's already available with `docker exec -it ollama-service ollama list`.

2. **Create a `Modelfile`.** This project keeps them organized inside the `custom_models/` folder, which is mounted into the container via `docker-compose.yml`. For example, `custom_models/custom-gemma4-e4b.Modelfile`:
   ```Dockerfile
   FROM gemma4:e4b
   PARAMETER num_ctx 20000
   PARAMETER num_predict 4096
   PARAMETER num_gpu 15
   ```

   * `num_ctx` — total context size (prompt **plus** response). Raise this if large prompts are being truncated. It must comfortably exceed your prompt size, with room left over for the answer.
   * `num_predict` — maximum number of tokens the model may generate in its response.
   * `num_gpu` — how many model layers to offload to the GPU. This is **optional and hardware-specific**: it only matters when running with GPU acceleration. On a small 4 GB card, a large model like E4B does not fit in VRAM, and letting Ollama auto-split can crash with a `GGML_ASSERT` error; capping `num_gpu` (e.g. `15`) avoids the crash and runs a partial GPU/CPU split. Remove this line or set it higher on bigger GPUs. See [README.gpu.md](./README.gpu.md) for the full explanation.

   > **Note:** A larger `num_ctx` consumes more RAM and, on CPU-only setups, makes processing noticeably slower. Increase it only as much as your prompts actually need.

3. **Build the custom model.** The `custom_models/` folder is mounted at `/custom_models` inside the container:
   ```bash
   docker exec -it ollama-service ollama create custom-gemma4-e4b -f /custom_models/custom-gemma4-e4b.Modelfile
   ```

4. **Confirm it was created:**
   ```bash
   docker exec -it ollama-service ollama list
   ```
   You should see `custom-gemma4-e4b` listed alongside the base `gemma4:e4b`.

5. **Use it.** In the terminal:
   ```bash
   docker exec -it ollama-service ollama run custom-gemma4-e4b
   ```
   Or select `custom-gemma4-e4b` from the model dropdown in Open WebUI.

   > **Order matters:** `custom-gemma4-e4b` is a **local** model — it does not exist in any remote registry. Running `ollama run custom-gemma4-e4b` *before* creating it will fail, since Ollama won't find it to download. Always run the `create` command (step 3) first.

The custom model is stored in your `./data/ollama` volume, so it **persists** across container restarts. You only need to recreate it if you change the `Modelfile`. To add more custom models (based on Llama, Qwen, etc.), drop another `.Modelfile` into `custom_models/` and repeat step 3 with a new name.

---

## 4. Python Application (Coming Soon)

In this section, you will learn how to build and run the Python application that connects to the Ollama service to perform various AI tasks.

* **Chatbot with Memory:** Implementation of conversation history.
* **RAG Pipeline:** Connecting local documents to the LLM.
* **Autonomous Agents:** Task automation with tools.
* **Data Extraction:** Structured JSON responses.
* **Workflows (Chains):** Multi-step processing.

*Stay tuned for the full setup instructions!*

---

## 5. General Commands

* **Start all services:** `docker-compose up -d --build`
* **Stop all services:** `docker-compose down`
* **Clean containers & network (Local data inside `./data` remains completely safe):** `docker-compose down -v --remove-orphans`
* **View logs:** `docker-compose logs -f`
* **List downloaded models and their sizes:** `docker exec -it ollama-service ollama list`
* **Show technical details/manifest of a specific model:** `docker exec -it ollama-service ollama show <model_name>`
