#!/bin/bash
cd /home/ubuntu/node-healthcheck

# Detener proceso anterior
pm2 stop all

# Descargar última versión
git pull origin main

# Instalar dependencias
/home/ubuntu/.nvm/versions/node/v22.15.0/bin/npm install

# Reiniciar app
pm2 start server.js --name "node-healthcheck"
