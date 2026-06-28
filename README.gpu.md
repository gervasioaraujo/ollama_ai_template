# GPU Acceleration (NVIDIA) — Optional Setup

This guide explains how to let the `ollama-service` container use an **NVIDIA GPU** on the host, why you might want to, and the important limitations to be aware of before you do.

GPU acceleration is **entirely optional**. The project runs fine on CPU only — it's just slower. If you don't have an NVIDIA GPU, skip this guide and run the stack normally (`docker-compose up -d`).

---

## 1. Why use the GPU?

Large language models perform huge numbers of parallel matrix multiplications. A **CPU** has a few powerful cores optimized for sequential work, while a **GPU** has thousands of small cores built for exactly this kind of parallel math. As a result, the same model can run many times faster on a suitable GPU than on CPU.

In practice: a model that generates ~37 tokens/second on CPU can be several times faster on a GPU — **provided the whole model fits in the GPU's memory (VRAM).** That last condition is the catch, and it's covered in the limitations section below.

---

## 2. Check whether you have a usable GPU

This setup only helps if your host has an **NVIDIA GPU with the proprietary driver installed**. Check from the host (not inside any container):

```bash
nvidia-smi
```

> `nvidia-smi` itself is **not** Ubuntu-specific — it ships with the NVIDIA driver and works on any OS where the driver is installed (Linux, Windows, WSL). Only the driver-installation hint below is Ubuntu-specific.

* If it prints a table showing your GPU model, driver version, and VRAM — you're good to continue. Note the **VRAM amount** (the `... MiB / ... MiB` memory column); you'll need it to pick a model later.
* If it says `command not found` — you either have no NVIDIA GPU, or the driver isn't installed. On **Ubuntu**, install the driver with `sudo ubuntu-drivers install`, then reboot and re-check (on other distros, install the NVIDIA driver via your package manager). Without a working `nvidia-smi` on the host, nothing below will work.

> **Note on AMD / integrated graphics:** This guide is for NVIDIA GPUs only. AMD GPUs use a different stack (ROCm) and integrated graphics generally aren't useful for this.

---

## 3. Install the NVIDIA Container Toolkit

By default, Docker containers **cannot** see the host GPU. The bridge between them is the **NVIDIA Container Toolkit** — it exposes the host's GPU and driver to containers at runtime. (You do *not* need to install CUDA inside the container; the toolkit passes the host's capabilities through.)

This project includes a helper script that installs and configures it for you.

> ⚠️ **The script is for Ubuntu / Debian only.** It uses `apt-get` and the NVIDIA APT repository. On other distributions (Fedora, Arch, etc.) the steps differ — follow the [official NVIDIA install guide](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html) instead.

> ⚠️ **Docker must be installed via APT, not Snap.** The Snap version of Docker is sandboxed and cannot access the host's `/dev/nvidia*` devices. Check with `which docker` — it should return `/usr/bin/docker`. The script will refuse to run if it detects a Snap-based Docker.

Run the script from the project root:

```bash
chmod +x install-nvidia-container-toolkit-for-ubuntu.sh
./install-nvidia-container-toolkit-for-ubuntu.sh
```

It will ask for your `sudo` password during execution. What it does, step by step:

1. **Pre-flight checks** — confirms Docker isn't Snap-based and that `nvidia-smi` works on the host. Stops with a clear message if either fails. If the toolkit is already installed, it asks whether you want to reinstall.
2. **Adds the repository** — registers the NVIDIA Container Toolkit APT repo and its GPG key.
3. **Installs** the `nvidia-container-toolkit` package.
4. **Configures the Docker runtime** — runs `nvidia-ctk runtime configure --runtime=docker`, which updates `/etc/docker/daemon.json`.
5. **Restarts** the Docker daemon so the change takes effect.

When it finishes, **validate** that a container can see the GPU:

```bash
sudo docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi
```

This spins up a temporary container (`--rm` deletes it immediately afterward) and runs `nvidia-smi` inside it. If you see the same GPU table as on the host, the Docker↔GPU bridge works. You can remove the test image afterward if you like:

```bash
sudo docker rmi nvidia/cuda:12.4.0-base-ubuntu22.04
```

---

## 4. Start the stack with GPU support

GPU access is controlled by a **separate compose override file**, `docker-compose.gpu.yml`. This keeps the base `docker-compose.yml` portable: machines without a GPU just ignore the override.

The override simply adds a GPU reservation to the `ollama-service`:

```yaml
services:
  ollama-service:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Start the stack:**

```bash
# WITH GPU — apply both files (base + GPU override):
docker-compose -f docker-compose.yml -f docker-compose.gpu.yml up -d

# Only the Ollama service, with GPU:
docker-compose -f docker-compose.yml -f docker-compose.gpu.yml up -d ollama-service

# WITHOUT GPU — just the base file (CPU only):
docker-compose up -d
```

Think of `docker-compose.gpu.yml` as the GPU "switch": include it to turn the GPU on, omit it for CPU-only.

### Verifying GPU usage with `ollama ps`

This is the command you'll rely on to confirm what's actually happening. `ollama ps` lists the models **currently loaded in memory** and, crucially, where they're running.

First, load a model so there's something to inspect — send it a message in Open WebUI, or run it in the terminal:

```bash
docker exec -it ollama-service ollama run llama3.2:1b
```

Then, **while the model is still loaded** (it stays in memory for a few minutes after the last request), check it from another terminal:

```bash
docker exec -it ollama-service ollama ps
```

Example output:

```
NAME           ID              SIZE      PROCESSOR    CONTEXT    UNTIL
llama3.2:1b    baf6a787fdff    1.5 GB    100% GPU     4096       4 minutes from now
```

The column that matters is **PROCESSOR**:

* `100% GPU` — the whole model is on the GPU. Ideal: fastest and most stable.
* `XX%/YY% CPU/GPU` — the model is **split** between CPU and GPU because it didn't fully fit in VRAM. Partially accelerated, but slower than full GPU. See the warning below.
* `100% CPU` — the model isn't using the GPU at all. Either you started the stack without the override, the model is forced to CPU via `num_gpu 0`, or no GPU is available.

> If `ollama ps` returns an empty table (just the header), no model is loaded right now — Ollama unloads idle models after a few minutes. Send a request first, then re-run it.

The `SIZE` column is also useful: compare it against your VRAM. If `SIZE` is close to or above your GPU's memory, expect a split or a fallback to CPU.

---

## 5. Important limitation: the model must fit in VRAM

This is the single most important thing to understand, and it's easy to get wrong.

A GPU only accelerates a model that **fits entirely in its VRAM**. When a model is larger than the available VRAM, Ollama tries to **split** it — putting some layers on the GPU and the rest on the CPU. This split mode is slower than full-GPU, and with some models it can fail outright.

### Real example from this project

On a **GTX 1650 (4 GB VRAM)**, trying to run the multimodal `gemma4` model (~9.6 GB) with the GPU override produced a hard crash:

```
Error: 500 Internal Server Error: llama-server process has terminated:
GGML_ASSERT(n_inputs < GGML_SCHED_MAX_SPLIT_INPUTS) failed
```

The cause: `gemma4` is far bigger than 4 GB, so it ran in split mode. Multimodal (vision) models generate many input "splits," and the split count exceeded an internal scheduler limit (`GGML_SCHED_MAX_SPLIT_INPUTS`). On CPU-only there's no split, so it never happened before enabling the GPU.

**Takeaway:** enabling the GPU does *not* magically speed up an oversized model. If the model doesn't fit, you either get a slow split or a crash. The fix is to use a model that fits — see the next section.

### Forcing a specific model onto the CPU

If you want to keep using a large model (like `gemma4`) even with the GPU stack running, you can force *that model* to stay 100% on the CPU by adding `num_gpu 0` to its Modelfile. This avoids the split/crash, at the cost of speed:

```Dockerfile
FROM gemma4
PARAMETER num_ctx 20000
PARAMETER num_predict 4096
PARAMETER num_gpu 0
```

This is per-model: the GPU stays available for other, smaller models. (Note: `num_gpu 0` only affects the custom model that declares it, not the base model it's built `FROM`.)

---

## 6. Choosing a model that fits 4 GB of VRAM

To actually benefit from the GPU on a 4 GB card, pick a model that fits in roughly **3–3.5 GB**, leaving headroom for the context (KV cache) **and** for whatever the host already uses (your desktop/X server can occupy a few hundred MB of VRAM). Models in the **1B–4B** parameter range at Q4 quantization are the candidates, but the smaller end is where things actually fit fully — see the tested results below.

> Sizes and tags change over time — always confirm on the [Ollama library](https://ollama.com/library) and run `ollama show <model>` after pulling. The picks below were accurate as of mid-2026.

### Tested results on a GTX 1650 (4 GB)

These are the actual `ollama ps` outcomes measured on the 4 GB card used for this project — useful as a reality check, since "should fit" and "fully fits" aren't always the same:

| Model | Reported SIZE | PROCESSOR result | Notes |
| --- | --- | --- | --- |
| `gemma4` (~9.6 GB) | 9.6 GB | crash in split mode | `GGML_ASSERT` — far too big (see section 5) |
| `gemma3:4b` | 4.3 GB | `60%/40% CPU/GPU` | just over 4 GB → split, no crash, partial speedup |
| `llama3.2:1b` | 1.5 GB | `100% GPU` ✅ | fits comfortably, fully accelerated |

The lesson: on a 4 GB card, a nominal "4B" model is right at the edge and tends to spill into a split. The **1B-class models are the ones that reliably hit 100% GPU** here. If your card has more VRAM (8 GB+), the 4B models become comfortable.

### If you need vision (image understanding)

* **`gemma3:4b`** — native vision, same family as `gemma4`. On this 4 GB card it ran as a **60/40 split** (still works, partial GPU speedup, no crash). On an 8 GB+ card it would run fully on the GPU.
  ```bash
  docker exec -it ollama-service ollama pull gemma3:4b
  docker exec -it ollama-service ollama run gemma3:4b
  ```
* Even smaller vision options exist (e.g. SmolVLM2 ~2.2B, or PaddleOCR-VL ~0.9B for documents specifically). There is no Gemma vision model small enough to run 100% on the GPU within 4 GB, so on this card vision means accepting a split.

### If you only need text

* **`llama3.2:1b`** — *tested, runs 100% on the GPU here.* ~1.5 GB. Great for classification, routing, summarization, and structured extraction (e.g. JSON) with a tight prompt. The most capable model that fully fit the 4 GB card in testing.
  ```bash
  docker exec -it ollama-service ollama pull llama3.2:1b
  docker exec -it ollama-service ollama run llama3.2:1b
  ```
* **`qwen2.5:1.5b`** — similar small size, strong for its class; likely also fits fully.
* **`llama3.2:3b`** / **`qwen2.5:3b`** — ~2–3 GB at Q4. May fit fully or may split depending on context size and free VRAM — check with `ollama ps`. More capable than the 1B if they fit.

### The honest trade-off

Small 1B–4B models are noticeably **less capable** than a 9.6 GB model like `gemma4`. For simple chat and well-specified extraction tasks they're great; for complex prompts they may struggle or need more explicit instructions. Test with your real prompts before committing. The fundamental choice on limited VRAM is:

* **Quality** → run the big model on CPU (`num_gpu 0`): stable but slow.
* **Speed** → run a small model on GPU: fast but less capable.
* **Both at once** → only possible with a model that fully fits your VRAM (so: a bigger GPU).

---

## 7. Quick reference

| Goal | Command |
| --- | --- |
| Install the GPU toolkit (Ubuntu) | `./install-nvidia-container-toolkit-for-ubuntu.sh` |
| Validate GPU in a container | `sudo docker run --rm --gpus all nvidia/cuda:12.4.0-base-ubuntu22.04 nvidia-smi` |
| Start stack **with** GPU | `docker-compose -f docker-compose.yml -f docker-compose.gpu.yml up -d` |
| Start stack **without** GPU | `docker-compose up -d` |
| Check GPU/CPU usage of loaded models | `docker exec -it ollama-service ollama ps` |
| Inspect a model's details | `docker exec -it ollama-service ollama show <model>` |