// Declarative pipeline for Problem 15: build and test every commit automatically.
pipeline {
    // The controller only schedules; this label sends the work to the agent.
    agent { label 'python' }

    // Trigger: poll Git every minute; a new commit starts a build.
    // (With a public Jenkins URL, a GitHub webhook can replace this.)
    triggers {
        pollSCM('* * * * *')
    }

    options {
        skipDefaultCheckout(true)   // the Checkout stage below does it once
        timestamps()
        timeout(time: 15, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '20'))
        disableConcurrentBuilds()
    }

    environment {
        // Secret text stored in Jenkins > Credentials (id: app-api-token).
        // Jenkins masks its value as **** in the console output.
        APP_API_TOKEN = credentials('app-api-token')
        VENV = '.venv'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'git log -1 --pretty=format:"Commit %h by %an: %s"'
            }
        }

        stage('Setup') {
            steps {
                sh '''
                    python3 -m venv "$VENV"
                    . "$VENV/bin/activate"
                    pip install --quiet --upgrade pip
                    pip install --quiet -r requirements.txt
                '''
            }
        }

        stage('Build') {
            steps {
                sh '''
                    . "$VENV/bin/activate"
                    python -m compileall -q app
                    echo "Build OK on agent: $NODE_NAME"
                '''
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . "$VENV/bin/activate"
                    mkdir -p reports
                    python -m pytest -v --junitxml=reports/junit.xml
                '''
            }
        }

        stage('Verify credentials') {
            steps {
                // Single quotes: the shell reads the variable, Groovy never prints it.
                sh 'test -n "$APP_API_TOKEN" && echo "API token loaded from the credentials store (value hidden)"'
            }
        }
    }

    post {
        always {
            junit allowEmptyResults: true, testResults: 'reports/junit.xml'
            archiveArtifacts artifacts: 'reports/*.xml', allowEmptyArchive: true
        }
        success {
            echo "SUCCESS: build #${env.BUILD_NUMBER} passed all stages."
        }
        failure {
            echo "FAILED: build #${env.BUILD_NUMBER}. Open the Test stage log or the Test Result page for the failing test."
        }
    }
}
