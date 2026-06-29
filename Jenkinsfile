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

        stage('Database Backup') {
            steps {
                sh '''
                    chmod +x scripts/mysql_backup.sh
                    ./scripts/mysql_backup.sh
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
