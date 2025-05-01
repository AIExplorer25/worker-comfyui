# Stage 1: Base image with common dependencies cuda:12.4.0-runtime-ubuntu22.04  nvidia/cuda:12.4.0-runtime-ubuntu22.04
FROM pytorch/pytorch:2.4.0-cuda12.4-cudnn9-runtime AS base

# Prevents prompts from packages asking for user input during installation
ENV DEBIAN_FRONTEND=noninteractive
# Prefer binary wheels over source distributions for faster pip installations
ENV PIP_PREFER_BINARY=1
# Ensures output from python is printed immediately to the terminal without buffering
ENV PYTHONUNBUFFERED=1 
# Speed up some cmake builds
ENV CMAKE_BUILD_PARALLEL_LEVEL=8

# Install Python, git and other necessary tools
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    git \
    wget \
    libgl1 \
    libglib2.0-0 \
    && ln -sf /usr/bin/python3.10 /usr/bin/python \
    && ln -sf /usr/bin/pip3 /usr/bin/pip

# Clean up to reduce image size
RUN apt-get autoremove -y && apt-get clean -y && rm -rf /var/lib/apt/lists/*

# Install uv
RUN pip install uv

# Install comfy-cli pip install torch==2.5.1+cu124 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
RUN uv pip install comfy-cli --system
RUN pip install torch==2.5.1+cu124 torchvision torchaudio --index-url https://download.pytorch.org/whl/cu124
# Install ComfyUI
RUN /usr/bin/yes | comfy --workspace /comfyui install --version 0.3.29 --nvidia
ADD src/requirements.txt ./
RUN pip install -r requirements.txt
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/cubiq/ComfyUI_essentials.git && \
    cd ComfyUI_essentials && \
    pip install -r requirements.txt
    
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/city96/ComfyUI-GGUF.git && \
    cd ComfyUI-GGUF && \
    pip install -r requirements.txt

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/yolain/ComfyUI-Easy-Use.git && \
    cd ComfyUI-Easy-Use && \
    pip install -r requirements.txt

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/WASasquatch/was-node-suite-comfyui.git && \
    cd was-node-suite-comfyui && \
    pip install -r requirements.txt
    
RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/kijai/ComfyUI-KJNodes.git && \
    cd ComfyUI-KJNodes && \
    pip install -r requirements.txt


RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git && \
    cd ComfyUI-VideoHelperSuite && \
    pip install -r requirements.txt

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git


RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/pollockjj/ComfyUI-MultiGPU.git
    

RUN cd /comfyui/custom_nodes && \
    git clone https://github.com/Smirnov75/ComfyUI-mxToolkit.git  
    
# Change working directory to ComfyUI
WORKDIR /comfyui

# Support for the network volume
ADD src/extra_model_paths.yaml ./

# Go back to the root
WORKDIR /

# install dependencies
RUN uv pip install runpod requests --system


# Add files
ADD src/start.sh src/restore_snapshot.sh src/rp_handler.py test_input.json ./
RUN chmod +x /start.sh /restore_snapshot.sh

# Optionally copy the snapshot file
#ADD *snapshot*.json /

# Restore the snapshot to install custom nodes
#RUN /restore_snapshot.sh

# Start container
CMD ["/start.sh"]

# Stage 2: Download models
FROM base AS downloader

# ARG HUGGINGFACE_ACCESS_TOKEN
# Set default model type if none is provided
ARG MODEL_TYPE=wan

# Change working directory to ComfyUI
WORKDIR /comfyui

# Create necessary directories upfront
RUN mkdir -p models/checkpoints models/vae models/unet models/clip



# Stage 3: Final image
FROM base AS final

# Copy models from stage 2 to the final image
COPY --from=downloader /comfyui/models /comfyui/models

# Start container
CMD ["/start.sh"]
