FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    postgresql-client \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    libevent-dev \
    libsasl2-dev \
    libldap2-dev \
    libpq-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev \
    zlib1g-dev \
    git \
    curl \
    wget \
    nodejs \
    npm \
    wkhtmltopdf \
    && rm -rf /var/lib/apt/lists/*

# Create odoo user
RUN useradd -m -d /opt/odoo -U -r -s /bin/bash odoo

# Set work directory
WORKDIR /opt/odoo

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy Odoo source code
COPY . .

# Create necessary directories
RUN mkdir -p /var/lib/odoo \
    && mkdir -p /var/log/odoo \
    && mkdir -p /mnt/extra-addons \
    && mkdir -p /mnt/custom-addons

# Set permissions
RUN chown -R odoo:odoo /opt/odoo \
    && chown -R odoo:odoo /var/lib/odoo \
    && chown -R odoo:odoo /var/log/odoo \
    && chown -R odoo:odoo /mnt/extra-addons \
    && chown -R odoo:odoo /mnt/custom-addons

# Switch to odoo user
USER odoo

# Expose port
EXPOSE 8069

# Add entrypoint
COPY deployment/docker/entrypoint.sh /entrypoint.sh
USER root
RUN chmod +x /entrypoint.sh
USER odoo

ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]