# Customized SQL Server Image: neajmorshad/sql22ubuntu22:latest
# Includes SQL Server, sqlcmd tools, and utilities like sudo and nano.

# References:
# https://github.com/Microsoft/mssql-docker
# https://raw.githubusercontent.com/microsoft/mssql-docker/master/linux/preview/examples/mssql-server-linux-non-root/Dockerfile
# https://github.com/microsoft/mssql-docker/blob/master/windows/mssql-server-windows-developer/dockerfile
# https://github.com/microsoft/mssql-docker/blob/master/linux/preview/examples/mssql-agent-fts-ha-tools/Dockerfile

# Use Ubuntu 22.04 as the base image
FROM ubuntu:22.04

# Set non-interactive frontend to avoid prompts during installation
ARG DEBIAN_FRONTEND=noninteractive

# Update package list and install essential tools and dependencies
RUN apt-get update && \
    apt-get install -y apt-utils sudo nano wget curl gnupg gnupg1 gnupg2 \
    software-properties-common systemd vim

# Add Microsoft's signing key for package verification
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | sudo apt-key add -

# Add the Microsoft SQL Server repository and install SQL Server
RUN add-apt-repository "$(wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/mssql-server-2022.list)"
RUN apt-get update
RUN apt-get install -y mssql-server


# Accept the EULA for msodbcsql18 during installation
RUN echo "msodbcsql18 msodbcsql/ACCEPT_EULA boolean true" | debconf-set-selections

RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft.asc.gpg && \
    mv microsoft.asc.gpg /etc/apt/trusted.gpg.d/ && \
    wget -qO- https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1433 5022

ENTRYPOINT /opt/mssql/bin/sqlservr