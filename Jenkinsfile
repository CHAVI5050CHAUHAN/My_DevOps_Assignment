pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        COMPOSE_FILE = 'docker-compose.yml'
        PROJECT_NAME = 'om-stack'
    }

    stages {
        stage('Pull Latest Code') {
            steps {
                checkout scm
            }
        }

        stage('Build Images') {
            steps {
                sh 'docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" build --pull'
            }
        }

        stage('Deploy Containers') {
            steps {
                sh 'docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" up -d --remove-orphans'
            }
        }

        stage('Verify Deployment') {
            steps {
                sh 'docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps'
            }
        }

        stage('Run IP Script') {
            steps {
                sh '''
                    chmod +x scripts/ip_script.sh
                    ./scripts/ip_script.sh
                '''
            }
        }

        stage('Database Backup') {
            steps {
                sh '''
                    chmod +x scripts/mysql_backup_to_s3.sh
                    ./scripts/mysql_backup_to_s3.sh
                '''
            }
        }
    }

    post {
        always {
            sh 'docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" logs --no-color --tail=200 > docker-compose.log || true'
            archiveArtifacts artifacts: 'docker-compose.log', fingerprint: true, allowEmptyArchive: true
        }
        failure {
            sh 'docker compose -p "$PROJECT_NAME" -f "$COMPOSE_FILE" ps || true'
        }
    }
}
