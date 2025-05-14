
## 1. Configuración de los servidores de despliegue (Servidores 1, 2 y 3)

### 1.1. Instalación de dependencias (Omitir para esta versión del Jenkinsfile)

Ejecuta estos comandos en cada uno de los tres servidores de despliegue:

```bash
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
```

### 1.2. Crear usuario para despliegue (opcional pero recomendado) (Omitir para esta versión del Jenkinsfile)

Si deseas usar un usuario específico para despliegue:

```bash
# Crear usuario
sudo adduser deployment
sudo usermod -aG sudo deployment

# Cambiar al usuario deployment
su - deployment

# Configurar NVM y Node.js para este usuario
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g pm2
```

Si vas a usar el usuario ubuntu existente en EC2, asegúrate de instalar las dependencias para ese usuario:

```bash
# Como usuario ubuntu
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
source ~/.bashrc
nvm install --lts
npm install -g pm2

# Verificar instalaciones
node --version
npm --version
pm2 --version
```

## 2. Configuración del servidor Jenkins (Servidor 4)

### 2.1. Instalar Java JDK

```bash
sudo apt update
sudo apt install -y openjdk-17-jdk
java -version
```

### 2.2. Instalar Jenkins

```bash
# Añadir repositorio de Jenkins
wget -q -O - https://pkg.jenkins.io/debian/jenkins.io-2023.key | sudo apt-key add -
sudo sh -c 'echo deb http://pkg.jenkins.io/debian-stable binary/ > /etc/apt/sources.list.d/jenkins.list'

# Instalar Jenkins
sudo apt update
sudo apt install -y jenkins

# Iniciar Jenkins
sudo systemctl start jenkins
sudo systemctl enable jenkins

# Verificar estado
sudo systemctl status jenkins
```

### 2.3. Instalar Node.js y Git en servidor Jenkins

```bash
# Instalar NVM 
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
source ~/.bashrc

# Instalar Node.js
nvm install --lts

# Instalar Git
sudo apt install -y git
```

### 2.4. Configuración inicial de Jenkins

1. Obtén la contraseña inicial de Jenkins:
```bash
sudo cat /var/lib/jenkins/secrets/initialAdminPassword
```

2. Accede a Jenkins en tu navegador: `http://IP-SERVIDOR-JENKINS:8080`
3. Introduce la contraseña inicial
4. Instala los plugins recomendados
5. Crea un usuario administrador

### 2.5. Instalar plugins necesarios en Jenkins

1. Ve a "Administrar Jenkins" > "Administrar Plugins"
2. En la pestaña "Disponibles", busca e instala los siguientes plugins:
   - Git Plugin
   - GitHub Integration Plugin
   - Multibranch Scan Webhook Trigger
   - NodeJS Plugin
   - SSH Agent Plugin (muy importante para el sshagent step)
   - Pipeline
   - Publish Over SSH
   - SSH Credentials Plugin
   
3. Después de instalar los plugins, asegúrate de reiniciar Jenkins:
   ```bash
   sudo systemctl restart jenkins
   ```
   
4. Verifica que los plugins se hayan instalado correctamente yendo a "Administrar Jenkins" > "Administrar Plugins" > "Instalados" y buscando cada uno de ellos.

### 2.6. Configurar credenciales en Jenkins

1. Ve a "Administrar Jenkins" > "Manage Credentials"
2. Haz clic en "(global)" y luego "Añadir credenciales"
3. Configura las credenciales SSH para acceder a los servidores de despliegue:
   - Tipo: SSH Username with private key
   - ID: `server-ssh-key`
   - Descripción: "Clave SSH para servidores de despliegue"
   - Usuario: deployment (o el usuario que hayas configurado)
   - Clave privada: Pega aquí tu clave privada SSH
   - **Importante**: Asegúrate de que la ID coincida exactamente con la que se usa en el Jenkinsfile

4. Si tu repositorio es privado, configura también credenciales para GitHub:
   - Tipo: Username with password o SSH Username with private key
   - ID: `github-credentials`
   - Descripción: "Credenciales para GitHub"
   - Usuario: tu usuario de GitHub
   - Contraseña/token o clave privada

### 2.7. Configurar herramientas en Jenkins

1. Ve a "Administrar Jenkins" > "Global Tool Configuration"
2. Configura Git:
   - Nombre: "Default Git"
   - Path to Git executable: `git` (normalmente es suficiente)

3. Configura Node.js:
   - Añade NodeJS
   - Nombre: "NodeJS LTS"
   - Instalar automáticamente: Marca esta opción
   - Selecciona la versión LTS más reciente

## 3. Configuración del trabajo Multibranch Pipeline en Jenkins

### 3.1. Crear un nuevo trabajo

1. En la página principal de Jenkins, haz clic en "Nueva Tarea" o "New Item"
2. Ingresa un nombre para el trabajo (ej. "node-healthcheck-pipeline")
3. Selecciona "Multibranch Pipeline" y haz clic en "OK"

### 3.2. Configurar el origen del código fuente

1. En la sección "Branch Sources", haz clic en "Add source" y selecciona "Git"
2. En "Project Repository", ingresa: `https://github.com/donetrmm/node-healthcheck.git`
3. Si es un repositorio privado, en "Credentials", selecciona las credenciales de GitHub que configuraste
4. En "Behaviours", deja "Discover branches" seleccionado

### 3.3. Configurar el escaneo de ramas

1. En "Scan Multibranch Pipeline Triggers", marca "Periodically if not otherwise run"
2. Establece un intervalo (por ejemplo, "1 hour")
3. En "Additional Behaviours", puedes añadir "Filter by name (with wildcards)" y especificar solo las ramas que te interesan: `*/main, */dev, */qa`

### 3.4. Haz clic en "Save" para guardar la configuración

## 4. Crear el Jenkinsfile

Necesitas crear un archivo llamado `Jenkinsfile` en la raíz de tu repositorio. Este archivo definirá el pipeline para cada rama.

```groovy
pipeline {
    agent any
    
    tools {
        nodejs 'NodeJS LTS'
    }
    
    environment {
        // Configurar variables de entorno para cada rama
        SERVER_DEV = '192.168.1.101'  // IP del servidor 1
        SERVER_QA = '192.168.1.102'   // IP del servidor 2
        SERVER_PROD = '192.168.1.103' // IP del servidor 3
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
                    } else {
                        echo "No se desplegará la rama: ${targetBranch}"
                        return
                    }
                    
                    // Desplegar en el servidor correspondiente
                    withCredentials([sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY')]) {
                        // Verificar si el directorio existe, si no, crearlo y clonar
                        sh """
                            ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no ${DEPLOY_USER}@${targetServer} '
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
```

## 5. Configuración adicional en los servidores de despliegue

### 5.1. Configurar archivo .env (si es necesario)

En cada servidor de despliegue, crea un archivo `.env` adecuado para cada entorno:

```bash
# Conectarse al servidor
ssh deployment@IP-DEL-SERVIDOR

# Crear archivo .env
cat > /home/deployment/node-healthcheck/.env << EOL
PORT=3000
NODE_ENV=development  # O "production" / "qa" según corresponda
# Otras variables de entorno específicas
EOL
```

### 5.2. Configurar servicio systemd o Nginx (opcional pero recomendado)

Si deseas más robustez que PM2 o necesitas un proxy inverso:

#### Configuración de Nginx (instalar en cada servidor de despliegue)

```bash
# Instalar Nginx
sudo apt install -y nginx

# Crear configuración
sudo nano /etc/nginx/sites-available/node-healthcheck

# Añadir configuración
```

Añade este contenido:

```nginx
server {
    listen 80;
    server_name tu-dominio.com;  # O la IP del servidor

    location / {
        proxy_pass http://localhost:3000;  # Puerto donde se ejecuta tu app Node.js
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

```bash
# Activar sitio
sudo ln -s /etc/nginx/sites-available/node-healthcheck /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

## 6. Verificación del despliegue

Una vez completada la configuración, Jenkins detectará automáticamente las ramas del repositorio y ejecutará el pipeline para cada una de ellas, desplegando cada rama en el servidor correspondiente.

Para verificar el despliegue:

1. En cada servidor, comprobar que la aplicación se está ejecutando:
```bash
pm2 status
curl http://localhost:3000/health  # O cualquier endpoint disponible
```

2. Verificar logs si hay problemas:
```bash
pm2 logs node-healthcheck
```

## 7. Mantenimiento y solución de problemas

### 7.1. Solución al error "No such DSL method 'sshagent' found"

Si encuentras este error:
```
java.lang.NoSuchMethodError: No such DSL method 'sshagent' found among steps
```

Hay dos soluciones posibles:

1. **Instalar el plugin SSH Agent correctamente**:
   - Asegúrate de que el plugin "SSH Agent Plugin" esté instalado y activo
   - Reinicia Jenkins después de instalar el plugin

2. **Alternativa: usar withCredentials en lugar de sshagent**:
   - Modifica el Jenkinsfile para usar el método `withCredentials` en lugar de `sshagent`
   - Ejemplo:
   ```groovy
   withCredentials([sshUserPrivateKey(credentialsId: 'server-ssh-key', keyFileVariable: 'SSH_KEY')]) {
       sh "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no user@server 'comando'"
   }
   ```

### 7.2. Reiniciar aplicación manualmente

```bash
ssh deployment@IP-DEL-SERVIDOR
cd /home/deployment/node-healthcheck
pm2 restart node-healthcheck
```

### 7.2. Verificar logs de Jenkins

En caso de fallos en el pipeline, revisar los logs de Jenkins:
1. Accede a Jenkins en el navegador
2. Navega hasta el trabajo multibranch
3. Selecciona la rama que falló
4. Haz clic en el número de build que falló
5. Haz clic en "Console Output" para ver los logs detallados

### 7.5. Error "command not found" durante el despliegue

Si encuentras errores como:
```
bash: line 14: npm: command not found
bash: line 18: pm2: command not found
```

Esto ocurre porque las herramientas no están disponibles en el PATH cuando Jenkins ejecuta comandos SSH. Hay varias soluciones:

1. **Cargar NVM en el script SSH**:
   - Modifica el Jenkinsfile para cargar NVM antes de ejecutar los comandos:
   ```bash
   export NVM_DIR="$HOME/.nvm"
   [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
   ```

2. **Instalar Node.js globalmente** (alternativa a NVM):
   ```bash
   sudo apt update
   sudo apt install -y nodejs npm
   sudo npm install -g pm2
   ```

3. **Usar rutas absolutas**:
   - Encuentra las rutas absolutas a los binarios y úsalas en el script:
   ```bash
   which node  # Encuentra la ruta a node
   which npm   # Encuentra la ruta a npm
   which pm2   # Encuentra la ruta a pm2
   ```
   - Luego usa estas rutas en el Jenkinsfile:
   ```bash
   /ruta/completa/a/npm ci
   /ruta/completa/a/pm2 restart node-healthcheck
   ```

4. **Verificar instalación de herramientas**:
   - Asegúrate de que Node.js, npm y PM2 estén instalados en el usuario correcto en cada servidor.
   - Para el usuario ubuntu en EC2, ejecuta:
   ```bash
   curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh | bash
   source ~/.bashrc
   nvm install --lts
   npm install -g pm2
   ```

   ### 7.6. Problemas comunes y soluciones

- **Error de conexión SSH**: Verifica que las claves SSH estén correctamente configuradas y que el usuario tenga permisos adecuados.
- **Error en dependencias de Node.js**: Asegúrate de que la versión de Node.js sea compatible con tu proyecto.
- **Aplicación no inicia**: Verifica los logs de PM2 y asegúrate de que todas las variables de entorno necesarias estén configuradas.
- **Error de permisos**: Asegúrate de que el usuario de despliegue tenga permisos de escritura en el directorio de la aplicación.
- **Error de plugin en Jenkins**: Si encuentras un error de tipo "No such DSL method", normalmente significa que falta instalar un plugin o que no está activado correctamente. Revisa la sección 7.1 para solucionar estos casos.
- **Error de compilación Node.js**: Verifica si existen scripts específicos en package.json y ajusta el Jenkinsfile según sea necesario.
- **Error con script build**: Si el proyecto no tiene un script de build en package.json, modifica el Jenkinsfile para omitir ese paso.# Guía de Despliegue Multibranch con Jenkins
