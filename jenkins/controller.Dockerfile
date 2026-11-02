# Jenkins controller: schedules builds and shows results (runs no build steps itself).
FROM jenkins/jenkins:lts-jdk17

# Plugins needed by the Jenkinsfile, the stage view and the trigger.
RUN jenkins-plugin-cli --plugins \
    git \
    workflow-aggregator \
    pipeline-stage-view \
    pipeline-graph-view \
    junit \
    credentials-binding \
    timestamper \
    ws-cleanup \
    github
