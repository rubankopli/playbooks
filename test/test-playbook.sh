#! /usr/bin/env bash

# Script based on the one from https://dev.to/pencillr/test-ansible-playbooks-using-docker-ci0

set -euo pipefail

###

PLAYBOOK_TO_RUN=$@

###

RED=$'\033[38;2;255;0;0m'
YELLOW=$'\033[38;2;255;180;0m'
GREEN=$'\033[38;2;0;255;0m'
RESET_COLOR=$'\033[39m\033[49m'
RESET_ALL=$'\033[0m'

BOLD_ON=$'\033[1m'
BOLD_OFF=$'\033[21m'

function test_var_exists() {
    failed=0
    for var in $@
    do
        if [[ -z $var ]]; then
            printf "${RED}${BOLD_ON}ERROR: (${FUNCNAME[1]})${RESET_COLOR} ${var}${BOLD_OFF} Does not exist!"
            printf "${RESET_ALL}\n"
            failed=1
        fi
    done

    if [[ ${failed} == 1 ]]; then
        exit 1
    fi
}

# Create name for container and path to assets
function create_container_name() {
    identifier="$(< /dev/urandom tr --delete --complement 'a-z0-9' | fold --width=5 | head --lines=1)" ||:
    NAME="${identifier}-test"

    script_dir="$(readlink --canonicalize "$0")"
    base_dir="$(dirname "${script_dir}")"

    export BASE_DIR="${base_dir}"
}

# Create and export the temp dir for our test
function setup_tempdir() {
    test_var_exists "${NAME}"

    TEMP_DIR=$(mktemp --directory "/tmp/${NAME}".XXXXXXXX)

    export TEMP_DIR
}

# Create an ephemeral ssh id to be used with the test container
function create_temporary_ssh_id() {
    test_var_exists "${TEMP_DIR}" "${USER}"

    ssh-keygen -b 2048 -t rsa -C "${USER}@email.com" -f "${TEMP_DIR}/id_rsa" -N ""
    chmod 600 "${TEMP_DIR}/id_rsa"
    chmod 644 "${TEMP_DIR}/id_rsa.pub"
}

function build_container() {
    create_container_name

    test_var_exists "${TEMP_DIR}" "${BASE_DIR}"

    docker build --tag "compute-node-sim" \
        --build-arg USER \
        --file "${BASE_DIR}/dockerfiles/ubuntu/Dockerfile" \
        "${TEMP_DIR}"
}

# Start the container and also grab its ip address
function start_container() {
    test_var_exists "${NAME}"

    docker run --detach --publish-all --name "${NAME}" "compute-node-sim"

    CONTAINER_ADDR=$(docker inspect --format='{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${NAME}")
    printf "${YELLOW}container address is: ${BOLD_ON}%s${BOLD_OFF}${RESET_COLOR}" "${CONTAINER_ADDR}"
    printf "${RESET_ALL}\n"

    if [ "$(docker inspect -f '{{.State.Running}}' "${NAME}")" != "true" ]; then
        printf "${RED}${BOLD_ON}Container exited unexpectedly. ${BOLD_OFF}${RESET_COLOR}\n"
        printf "${RESET_ALL}\n"

        docker logs "${NAME}"

        return 1
    fi

    export CONTAINER_ADDR
}

# Create a temporary ansible configuration file
function setup_test_config() {
    test_var_exists "${TEMP_DIR}"

    TEMP_CONFIG_FILE="${TEMP_DIR}/ansible.cfg"

    cat > "${TEMP_CONFIG_FILE}" << EOL
[defaults]
# Avoid host key checking so we can run without interaction
host_key_checking = False
EOL

    export TEMP_CONFIG_FILE
}

# Create a temporary ansible inventory
function setup_test_inventory() {
    test_var_exists "${TEMP_DIR}" "${CONTAINER_ADDR}"
    printf "%s" "${CONTAINER_ADDR}"

    TEMP_INVENTORY_FILE="${TEMP_DIR}/hosts"

    cat > "${TEMP_INVENTORY_FILE}" << EOL
[test]
${CONTAINER_ADDR}:22

[test:vars]
ansible_ssh_private_key_file=${TEMP_DIR}/id_rsa
ansible_user=${USER}
ansible_become=true
ansible_become_method=sudo
ansible_become_password=
EOL

    export TEMP_INVENTORY_FILE
}

# Run the actual playbook with the remote container as the target!
function run_ansible_playbook() {
    test_var_exists "${TEMP_CONFIG_FILE}" "${TEMP_INVENTORY_FILE}" "${BASE_DIR}"

    export ANSIBLE_CONFIG="${TEMP_CONFIG_FILE}"

    ansible-playbook -i "${TEMP_INVENTORY_FILE}" "${PLAYBOOK_TO_RUN}"
}

# Remove the container and clean out the temp test dir
function cleanup() {
    container_id=$(docker inspect --format="{{.Id}}" "${NAME}" ||:)

    if [[ -n "${container_id}" ]]; then
        printf "${GREEN}Cleaning up container %s${RESET_COLOR}" "${NAME}\n"
        docker rm --force "${container_id}" > /dev/null
    fi

    if [[ -n "${TEMP_DIR:-}" && -d "${TEMP_DIR:-}" ]]; then
        printf "${GREEN}Cleaning up temporary directory %s${RESET_COLOR}" "${TEMP_DIR}"
        rm --recursive --force "${TEMP_DIR}"
    fi
}

setup_tempdir
trap cleanup EXIT
trap cleanup ERR
create_temporary_ssh_id

build_container

start_container
setup_test_inventory
setup_test_config

printf "$\n${YELLOW}Contents of ${TEMP_CONFIG_FILE}${RESET_COLOR}\n"
cat "${TEMP_CONFIG_FILE}"

printf "\n${YELLOW}Contents of ${TEMP_INVENTORY_FILE}${RESET_COLOR}\n"
cat "${TEMP_INVENTORY_FILE}"

run_ansible_playbook
