pipeline{
    agent none
    options{
        skipDefaultCheckout()
    }
    environment{
        REPO="karimfathi1"
        IMG="spring-petclinic"
        TAG="${BUILD_NUMBER}"
        CONTAINER_NAME="spring-petclinc"
        APP_PORT="8080"
    }
    stages{
        stage('Stage 1 - Shallow Clonning The App'){
            agent any
            steps{
                sh "echo  Shallow Clonning: Start Clonning the Last Commit Only..."
                checkout scmGit(branches: [[name: 'main']],
                    extensions: [cloneOption(depth: 1,
                        noTags: false,
                        reference: '',
                        shallow: true)],
                    userRemoteConfigs: [[credentialsId: 'github-token',
                        url: 'https://github.com/k-fathi/spring-petclinic-devsecops.git']])
            }
        }
        stage('Stage 2 - Testing & Scanning The Code Base & Dockerfile'){
            parallel{
                stage('SCA - pom.xml Scanning'){
                    agent{
                        docker{
                            image 'aquasec/trivy'
                            args '--entrypoint=""'
                        }
                    }
                    steps{
                        sh "echo  Trivy Generates the SBOM report sbom.json now..."
                        sh "trivy fs --format cyclonedx --output sbom.json ."

                        sh "echo  Trivy Scans the Dependinces now..."
                        sh "trivy fs --scanners vuln --severity CRITICAL,HIGH --exit-code 1 ."
                    }
                }
                stage('IaC Dockerfile Scanning'){
                    agent{
                        docker{
                            image 'aquasec/trivy'
                            args '--entrypoint=""'
                        }
                    }
                    steps{
                        sh "echo  Trivy Scans the Dockerfile now..."
                        sh "trivy conf --severity CRITICAL,HIGH --exit-code 1 ./Dockerfile"
                    }
                }
            }
        }
        stage('Stage 3 - Testing The App - Unit & Integration Tests'){
            agent{
                docker {
                    image 'maven:eclipse-temurin:17-jdk'
                    args '-v /var/jenkins_home/.m2:/root/.m2 --entrypoint=""'
                }
            }
            steps{
                sh "echo  maven Starts Unit Tests, Integration Tests and Builds the Artifact now..."
                sh "mvn clean package"
            }
        }
        stage('Stage 4 - Building & Scanning The App'){
            agent {
                docker {
                    image 'maven:eclipse-temurin:17-jdk'
                    args '-v /var/jenkins_home/.m2:/root/.m2 --entrypoint=""'
                }
            }
            steps{
                withSonarQubeEnv('sonarqube-server') {
                    sh "echo  Sonar Clinet Plugin Collects the source code file + Unit, integration tests report and Sending them to SonarQube Server now..."
                    sh '''
                    mvn sonar:sonar \
                    -Dsonar.projectKey=spring-petclinic \
                    -Dsonar.projectName=Spring Petclinic \
                    -Dsonar.host.url=http://sonarqube:9000 \
                    '''
                    waitForQualityGate(abortPipeline: true)
                }
            }
        }
        stage('Stage 5 - Building & Testing The Docker Image'){
            steps{
                withCredentials([usernamePassword(credentialsId: 'dockerhub', passwordVariable: 'DOCKERHUB_PWD', usernameVariable: 'DOCKERHUB_USER')]) {
                    sh "echo  Loggin to DockerHub now..."
                    sh "echo \"${DOCKERHUB_PWD}\" | docker login -u ${DOCKERHUB_USER} --password-stdin"
                  
                    sh "echo  Building The Image now..."
                    sh "docker build -t ${REPO}/${IMG}:${TAG} -t ${REPO}/${IMG}:latest ."
                  
                    sh "echo  Trivy Scanning the Image now..."
                    sh "trivy image --severity HIGH,CRITICAL --exit-code 1 ${IMG}:${TAG}"
                  
                    sh "echo  Pushing the Images now..."
                    sh "docker push ${IMG}:${TAG}"
                    sh "docker push ${IMG}:latest"
                }
                sh "echo  Generating the deploy file now..."
                sh """
                    cat > deploy-info-${BUILD_NUMBER}.txt <<EOF
image: ${IMG}:${TAG}
build: ${BUILD_NUMBER}
commit: ${GIT_COMMIT}
branch: ${GIT_BRANCH}
url: ${BUILD_URL}
date: \$(date +"%Y_%m_%d-%H:%M:%S")
EOF
                """
            }
        }
        stage('Stage 6 - Deploying & Testing The Running App'){
            agent {
                docker {
                    image "zaproxy/zap-stable"
                    args '--network pipeline-net --entrypoint=""' 
                }
            }
            steps{

                sh "echo  Removing any existing container with the same name..."
                sh "docker rm -f ${CONTAINER_NAME} || true"

                sh "echo  Running the container..."
                sh "docker run -d --name ${CONTAINER_NAME} -p 8080:${APP_PORT} ${REPO}/${IMG}:${TAG}"
                
                sh "echo  Running A Smoke Testing..."
                sh "docker network create pipeline-net"
                sh "docker network connect ${CONTAINER_NAME} pipeline-net"
                sh "sleep 10"
                sh "curl -s -o /dev/null -w \"%{http_code}\" ${CONTAINER_NAME}:8080/actuator/health || false"

                sh "echo  Running DAST..."
                sh 'zap-baseline.py -t http://petclinic-app:8080  -r zap-report.html -l MEDIUM,HIGH'
            }
        }
    }
    post{
        success{
            sh "echo 'Pipeline completed successfully!'"
        }
        failure{
            sh 'echo "Pipeline failed!"'
            sh "echo ' echo Removing any existing container with the same name...'"
            sh "docker rmi -f ${REPO}/${IMG}:${TAG} || true"
            sh "docker rm -f ${CONTAINER_NAME} || true"
        }
        always{
            archiveArtifacts artifacts: "deploy-info-${BUILD_NUMBER}.txt", followSymlinks: false
            archiveArtifacts artifacts: 'sbom.json', followSymlinks: false
            archiveArtifacts artifacts: 'zap-report.html', followSymlinks: false
            
            echo "Cleaning Workspace..."
            cleanWs()
        }
    }
}