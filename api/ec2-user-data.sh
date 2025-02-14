#!/bin/bash

# Update system and clean cache
yum update -y
yum clean all
rm -rf /var/cache/yum

# Install Docker and Git
yum install -y docker git
yum clean all

# Clean up docker system
systemctl start docker
docker system prune -af

# Install docker-compose
sudo curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Add ec2-user to docker group
usermod -aG docker ec2-user

# Start Docker service
systemctl enable docker

# Set up project directory
cd /home/ec2-user
git clone --depth 1 https://github.com/theRealThomasDavidson/tiptok.git
mv tiptok/api tiptok-api
rm -rf tiptok

# Set up logging
mkdir -p tiptok-api/logs
mkdir -p tiptok-api/credentials
touch tiptok-api/logs/api.log

# Set correct ownership
chown -R ec2-user:ec2-user /home/ec2-user/tiptok-api

# Remove unnecessary dependencies from requirements.txt
cd tiptok-api
sed -i '/scikit-learn/d' requirements.txt
sed -i '/sentence-transformers/d' requirements.txt
sed -i '/nltk/d' requirements.txt

# Copy credentials and environment files (these should be securely transferred separately)
# cp /path/to/secure/firebase-credentials.json tiptok-api/credentials/
# cp /path/to/secure/.env tiptok-api/

# Update docker-compose.yml to use port 80
sed -i 's/"8080:8080"/"80:80"/g' docker-compose.yml
sed -i 's/--port=8080/--port=80/g' docker-compose.yml

# Clean up before building
docker system prune -af
docker builder prune -af

# Build and run the container with no cache
docker-compose build --no-cache
docker-compose up -d && docker-compose logs -f 