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
        SERVER_STAGING = '54.92.219.132'
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
                                sudo apt update

                                # Instalar NVM (Node Version Manager)
                                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
                                source ~/.bashrc

                                # Instalar Node.js (versión LTS)
                                nvm install --lts

                                # Verificar instalación
                                node --version
                                npm --version

                                # Instalar PM2 globalmente
                                npm install -g pm2

                                # Instalar Git
                                sudo apt install -y git

                                # Como usuario ubuntu
                                curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
                                source ~/.bashrc
                                nvm install --lts
                                npm install -g pm2

                                # Verificar instalaciones
                                node --version
                                npm --version
                                pm2 --version
                                
                                # Cargar NVM y Node.js para asegurar que estén disponibles
                                export NVM_DIR="\$HOME/.nvm"
                                [ -s "\$NVM_DIR/nvm.sh" ] && \\. "\$NVM_DIR/nvm.sh"
                                
                                # Instalar PM2 si no está disponible
                                if ! command -v pm2 &> /dev/null; then
                                    npm install -g pm2
                                fi
                                
                                if [ ! -d ${APP_DIR} ]; then
                                    mkdir -p ${APP_DIR}
                                    cd ${APP_DIR}
                                    git clone https://github.com/donetrmm/node-healthcheck.git .
                                    git checkout ${targetBranch}
                                else
                                    cd ${APP_DIR}
                                    git fetch --all
                                    git checkout ${targetBranch}
                                    git pull origin ${targetBranch}
                                fi
                                
                                # Ejecutar comandos npm asegurándose que Node.js está en el PATH
                                npm ci
                                # Revisar si existe script build antes de ejecutarlo
                                if grep -q '"build"' package.json; then
                                    npm run build
                                else
                                    echo "No hay script de build en package.json, omitiendo este paso"
                                fi
                                
                                # Reiniciar con PM2
                                if pm2 list | grep -q "node-healthcheck"; then
                                    pm2 restart node-healthcheck
                                else
                                    pm2 start npm --name "node-healthcheck" -- start
                                fi
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