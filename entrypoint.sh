#!/bin/sh
set -eu

if [ -z "$INPUT_REMOTE_HOST" ]; then
    echo "Input remote_host is required!"
    exit 1
fi

if [ $INPUT_DOCKER_REGISTRY ] && [ $INPUT_DOCKER_USERNAME ] && [ $INPUT_DOCKER_PASSWORD ]; then
    echo $INPUT_DOCKER_PASSWORD | docker login $INPUT_DOCKER_REGISTRY -u $INPUT_DOCKER_USERNAME --password-stdin
fi

# Extra handling for SSH-based connections.
if [ ${INPUT_REMOTE_HOST#"ssh://"} != "$INPUT_REMOTE_HOST" ]; then

    SSH_HOST=${INPUT_REMOTE_HOST#"ssh://"}
    SSH_HOST=${SSH_HOST#*@}

    if [ -z "$INPUT_SSH_PRIVATE_KEY" ]; then
        echo "Input ssh_private_key is required for SSH hosts!"
        exit 1
    fi

    if [ -z "$INPUT_SSH_PUBLIC_KEY" ]; then
        echo "Input ssh_public_key is required for SSH hosts!"
        exit 1
    fi

    echo "Registering SSH keys..."

    # Save private key to a file and register it with the agent.
    mkdir -p "$HOME/.ssh"
    echo "$INPUT_SSH_PRIVATE_KEY" | tr -d '\r' > ~/.ssh/docker
    chmod 600 "$HOME/.ssh/docker"
    eval $(ssh-agent)
    ssh-add "$HOME/.ssh/docker"

    # Add public key to known hosts.
    echo "$INPUT_SSH_PUBLIC_KEY" | tr -d '\r' >> /etc/ssh/ssh_known_hosts
fi

echo "Connecting to $INPUT_REMOTE_HOST..."

# Check if the environment variable is set
if [ -z "$INPUT_ENV" ]; then
    echo "Environment variable $INPUT_ENV is not set."
else
    echo "Environment variable $INPUT_ENV is set. Exporting..."
    # Iterate over each line in the multiline string
    while IFS= read -r line; do
        # Skip comments and empty lines
        if [ -z "$line" ] || [ "${line:0:1}" = "#" ]; then
            continue
        fi
        # Export the variable
        export "$line"
    done <<< "$INPUT_ENV"
    echo "Environment variables exported successfully."
fi

# Check if INPUT_RUN_NUMBER is set and not empty
if [ -z "$INPUT_RUN_NUMBER" ]; then
    echo "ERROR: The environment variable INPUT_RUN_NUMBER is not set."
    exit 1
else
    export GITHUB_RUN_NUMBER="$INPUT_RUN_NUMBER"
    echo "GITHUB_RUN_NUMBER is set to $GITHUB_RUN_NUMBER"
fi

docker --log-level debug --host "$INPUT_REMOTE_HOST" "$@" 2>&1

if [ $INPUT_DOCKER_REGISTRY ]; then
    docker logout $INPUT_DOCKER_REGISTRY
fi
