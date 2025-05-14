pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS LTS'
    }
    
    environment {
        // Configurar variables de entorno para cada rama
        SERVER_DEV = '54.86.104.168'  // IP del servidor 1
        SERVER_QA = '54.235.214.15'   // IP del servidor 2
        SERVER_PROD = '54.221.226.38' // IP del servidor 3
        SERVER_STAGING = '52.23.234.197'
        DEPLOY_USER = 'ubuntu'    // Usuario para SSH
        APP_DIR = '/home/ubuntu/node-healthcheck'
    }
    
    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }
        
        stage('Install Dependencies') {
            steps {
                sh 'npm ci'
            }
        }
             
        stage('Deploy') {
            steps {
                script {
                    def targetServer = ''
                    def targetBranch = env.BRANCH_NAME
                    
                    // Determinar el servidor según la rama
                    if (targetBranch == 'dev') {
                        targetServer = env.SERVER_DEV
                    } else if (targetBranch == 'qa') {
                        targetServer = env.SERVER_QA
                    } else if (targetBranch == 'main') {
                        targetServer = env.SERVER_PROD
                    } else if (targetBranch == "staging") {
                        targetServer = env.SERVER_STAGING
                    } else {
                        echo "No se desplegará la rama: ${targetBranch}"
                        return
                    }
                    
                    // Desplegar en el servidor correspondiente
                    withCredentials([sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        sh """
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${DEPLOY_USER}@${targetServer} '
                                # Actualizar repositorios
                                sudo apt update && sudo apt upgrade -y

                                # Instalación de NVM y Node
                                export NVM_DIR="\$HOME/.nvm"
                                
                                # Instalar NVM si no existe
                                if [ ! -d "\$NVM_DIR" ]; then
                                    echo "Instalando NVM..."
                                    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
                                fi
                                
                                # Cargar NVM
                                [ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
                                [ -s "\$NVM_DIR/bash_completion" ] && \\. "\$NVM_DIR/bash_completion"
                                
                                # Instalar Node LTS
                                echo "Instalando Node.js LTS..."
                                nvm install --lts
                                nvm use --lts
                                
                                # Verificar versiones
                                echo "Versión de Node.js:"
                                node --version
                                echo "Versión de NPM:"
                                npm --version
                                
                                # Instalar PM2 globalmente
                                echo "Instalando PM2..."
                                npm install -g pm2
                                echo "Versión de PM2:"
                                pm2 --version
                                
                                # Instalar Git si no está presente
                                if ! command -v git &> /dev/null; then
                                    sudo apt install -y git
                                fi

                                # Clonar o actualizar repositorio
                                if [ ! -d ${APP_DIR} ]; then
                                    echo "Clonando repositorio..."
                                    mkdir -p ${APP_DIR}
                                    cd ${APP_DIR}
                                    git clone https://github.com/donetrmm/node-healthcheck.git .
                                    git checkout ${targetBranch}
                                else
                                    echo "Actualizando repositorio..."
                                    cd ${APP_DIR}
                                    git fetch --all
                                    git checkout ${targetBranch}
                                    git pull origin ${targetBranch}
                                fi
                                
                                # Asegurar que NVM está cargado para cada comando
                                export NVM_DIR="\$HOME/.nvm"
                                [ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
                                nvm use --lts
                                
                                echo "Instalando dependencias..."
                                npm ci
                                
                                # Revisar si existe script build antes de ejecutarlo
                                if grep -q "\\\"build\\\"" package.json; then
                                    echo "Ejecutando build..."
                                    npm run build
                                else
                                    echo "No hay script de build en package.json, omitiendo este paso"
                                fi
                                
                                # Reiniciar con PM2
                                echo "Configurando PM2..."
                                if pm2 list | grep -q "node-healthcheck"; then
                                    echo "Reiniciando aplicación con PM2..."
                                    pm2 restart node-healthcheck
                                else
                                    echo "Iniciando aplicación con PM2 por primera vez..."
                                    pm2 start npm --name "node-healthcheck" -- start
                                fi
                                
                                # Guardar configuración de PM2
                                echo "Guardando configuración de PM2..."
                                pm2 save
                            '
                        """
                    }
                }
            }
        }
    }
    
    post {
        success {
            echo "Pipeline ejecutado con éxito!"
        }
        failure {
            echo "El pipeline ha fallado."
        }
    }
}