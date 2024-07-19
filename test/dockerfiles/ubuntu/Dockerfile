FROM ubuntu:latest

ARG USER=${USER}
ARG SSH_DIR=/home/${USER}/.ssh

# Add sudo and openssh-server
ENV DEBIAN_FRONTEND=noninteractive
RUN apt update && apt install openssh-server sudo -y

# Set up user on the container and add them to the sudoers group. Enable passowrd-less ssh login
RUN useradd --create-home ${USER} && \
    adduser ${USER} sudo && \
    echo "${USER} ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/${USER}

# Set up ssh directory for user
RUN mkdir --parents ${SSH_DIR} && \
    chmod 700 ${SSH_DIR} && \
    chown ${USER}:${USER} ${SSH_DIR}

# Set up ssh identity for user
COPY --chown=${USER}:${USER} id_rsa.pub ${SSH_DIR}/id_rsa.pub
RUN  cat ${SSH_DIR}/id_rsa.pub >> ${SSH_DIR}/authorized_keys && \
    chmod 644 ${SSH_DIR}/id_rsa.pub && \
    chmod 644 ${SSH_DIR}/authorized_keys && \
    chown ${USER}:${USER} ${SSH_DIR}/authorized_keys && \
    mkdir -p /run/sshd

# Expose ssh port
EXPOSE 22

# Start SSH service
CMD ["/usr/sbin/sshd", "-D"]
