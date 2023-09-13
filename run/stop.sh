#!/usr/bin/env bash
SCRIPTDIR="$(dirname "$(realpath "$0")")"

# Check that files exist first
FILES=(".env")
for FILE in "${FILES[@]}"; do
    if [ ! -f "${SCRIPTDIR}/${FILE}" ]; then
            echo "File not found: ${FILE}"
            echo "Run create_container.sh first."
            exit 1
    fi
done

# Then start by importing environment file
source "${SCRIPTDIR}"/.env

echo "Stopping the container: ${HOSTNAME}"
docker stop "${HOSTNAME}"
