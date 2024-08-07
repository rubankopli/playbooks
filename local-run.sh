#!/bin/bash
script_dir="$(dirname "${BASH_SOURCE[0]}")"
playbook="${script_dir}/common/install-packages.playbook.ansible.yaml"

if [[ ! -f "$playbook" ]]; then
        echo "ERROR: Playbook not found at ${playbook}"
        exit 1
fi

ansible-playbook -i localhost, -c local --ask-become-pass "${playbook}"

