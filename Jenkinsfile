pipeline {
    agent any

    environment {
        IMAGE_NAME = "pipeline-demo"
        IMAGE_TAG  = "${BUILD_NUMBER}"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Image') {
            steps {
                sh 'docker build -t ${IMAGE_NAME}:${IMAGE_TAG} .'
            }
        }

        stage('Scan Image (Trivy)') {
            steps {
                sh '''
                    if ! command -v trivy &> /dev/null; then
                        echo "Trivy not installed, skipping scan (install with: brew install trivy)"
                    else
                        trivy image --exit-code 0 --severity HIGH,CRITICAL ${IMAGE_NAME}:${IMAGE_TAG}
                    fi
                '''
            }
        }

        stage('Load into kind cluster') {
            steps {
                sh 'kind load docker-image ${IMAGE_NAME}:${IMAGE_TAG} --name training'
            }
        }

        stage('Deploy to kind') {
            steps {
                sh '''
                    sed "s/IMAGE_TAG_PLACEHOLDER/${IMAGE_TAG}/g" deployment.yaml > deployment-rendered.yaml
                    kubectl apply -f deployment-rendered.yaml
                    kubectl apply -f service.yaml
                    kubectl rollout status deployment/pipeline-demo --timeout=60s
                '''
            }
        }
    }

    post {
        success { echo "Pipeline succeeded — image ${IMAGE_NAME}:${IMAGE_TAG} deployed." }
        failure { echo "Pipeline failed — check the stage logs above." }
    }
}