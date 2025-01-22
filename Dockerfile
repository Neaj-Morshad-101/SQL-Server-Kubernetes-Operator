# Customized SQL Server Image: neajmorshad/sql-server-2022:latest
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

# Import Microsoft's GPG key
RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/microsoft-prod.gpg

# Download and register the SQL Server Ubuntu repository
RUN curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/mssql-server-2022.list | sudo tee /etc/apt/sources.list.d/mssql-server-2022.list

# Download and register the SQL Server Ubuntu repository
RUN echo "deb [signed-by=/usr/share/keyrings/microsoft-prod.gpg] https://packages.microsoft.com/ubuntu/22.04/mssql-server-2022 jammy main" | tee /etc/apt/sources.list.d/mssql-server-2022.list

RUN apt-get update
RUN apt-get install -y mssql-server


# Accept the EULA for msodbcsql18 during installation
RUN echo "msodbcsql18 msodbcsql/ACCEPT_EULA boolean true" | debconf-set-selections

RUN curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/trusted.gpg.d/microsoft.asc.gpg && \
    curl -fsSL https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install -y msodbcsql18 mssql-tools18 && \
    rm -rf /var/lib/apt/lists/*


# Expose required ports for SQL Server and HADR
EXPOSE 1433 5022

# Set default entrypoint
ENTRYPOINT ["/opt/mssql/bin/sqlservr"]