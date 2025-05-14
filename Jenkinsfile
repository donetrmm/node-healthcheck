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
        DEPLOY_USER = 'deployment'    // Usuario para SSH
        APP_DIR = '/home/deployment/node-healthcheck'
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
                    } else {
                        echo "No se desplegará la rama: ${targetBranch}"
                        return
                    }
                    
                    // Desplegar en el servidor correspondiente
                    sshagent(['server-ssh-key']) {
                        // Verificar si el directorio existe, si no, crearlo y clonar
                        sh """
                            ssh -o StrictHostKeyChecking=no ${DEPLOY_USER}@${targetServer} '
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
                                
                                npm ci
                                npm run build
                                
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