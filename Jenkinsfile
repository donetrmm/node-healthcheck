pipeline {
    agent any

    environment {
        DEPLOY_SERVER = 'ec2-ubuntu@54.221.226.38'
        SSH_KEY = credentials('ssh-key-ec2')
    }

    stages {
        stage('Clonar Repositorio') {
            steps {
                checkout scm
            }
        }

        stage('Deploy') {
            steps {
                sshagent(['ssh-key-ec2']) {
                    sh """
                    echo "Deploying branch: ${env.BRANCH_NAME}"

                    if [ "${env.BRANCH_NAME}" = "dev" ]; then
                        ssh -o StrictHostKeyChecking=no $DEPLOY_SERVER "bash ~/deploy-dev.sh"
                    elif [ "${env.BRANCH_NAME}" = "qa" ]; then
                        ssh -o StrictHostKeyChecking=no $DEPLOY_SERVER "bash ~/deploy-qa.sh"
                    elif [ "${env.BRANCH_NAME}" = "main" ]; then
                        ssh -o StrictHostKeyChecking=no $DEPLOY_SERVER "bash ~/deploy-main.sh"
                    else
                        echo "No deployment configured for this branch"
                    fi
                    """
                }
            }
        }
    }
}
