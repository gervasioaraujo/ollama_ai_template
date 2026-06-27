# AI Local Project with Ollama and LangChain

This project provides a local environment using Docker to run LLMs via **Ollama** and integrate them into Python applications using **LangChain**.

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

## 3. Python Application (Coming Soon)

In this section, you will learn how to build and run the Python application that connects to the Ollama service to perform various AI tasks.

* **Chatbot with Memory:** Implementation of conversation history.
* **RAG Pipeline:** Connecting local documents to the LLM.
* **Autonomous Agents:** Task automation with tools.
* **Data Extraction:** Structured JSON responses.
* **Workflows (Chains):** Multi-step processing.

*Stay tuned for the full setup instructions!*

---

## 4. General Commands

* **Start all services:** `docker-compose up -d --build`
* **Stop all services:** `docker-compose down`
* **Clean containers & network (Local data inside `./data` remains completely safe):** `docker-compose down -v --remove-orphans`
* **View logs:** `docker-compose logs -f`
* **List downloaded models and their sizes:** `docker exec -it ollama-service ollama list`
* **Show technical details/manifest of a specific model:** `docker exec -it ollama-service ollama show <model_name>`
