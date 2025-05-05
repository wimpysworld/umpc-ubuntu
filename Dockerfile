# Use a recent Ubuntu LTS as the base image
FROM ubuntu:22.04

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies required by the respin script
# - xorriso: For ISO creation
# - squashfs-tools: For unsquashfs and mksquashfs
# - rsync: For copying ISO contents
# - gcc & libc6-dev: For compiling umpc-display-rotate.c
# - isolinux: For older ISO boot structure (isohdpfx.bin)
# - cd-boot-images-amd64: For newer ISO boot structure (efi.img, boot_hybrid.img)
# - coreutils, bash: Standard utilities (usually present but good to ensure)
RUN apt-get update && apt-get install -y --no-install-recommends \
    xorriso \
    squashfs-tools \
    rsync \
    gcc \
    libc6-dev \
    isolinux \
    cd-boot-images-amd64 \
    coreutils \
    bash \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory inside the container
WORKDIR /app

# Copy the respin script into the container
COPY umpc-ubuntu-respin.sh .

# Copy the entire data directory (containing configs, scripts, etc.)
COPY data ./data

# Make the script executable
RUN chmod +x umpc-ubuntu-respin.sh

# Set the script as the entrypoint. Arguments to 'docker run' will be passed to the script.
ENTRYPOINT ["./umpc-ubuntu-respin.sh"]

# Define default command (optional, can be overridden)
# CMD ["-h"]
