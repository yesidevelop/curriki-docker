pipeline {
  agent {
    label "master"
  }

  environment {
      // GLobal Vars
      NAME = "curriki-tsugi"
      ARGOCD_CONFIG_REPO = "github.com/ActiveLearningStudio/rh-innovation-lab-open-shift.git"
      ARGOCD_CONFIG_REPO_PATH = "applications/deployment/values.yaml"
      ARGOCD_CONFIG_REPO_BRANCH = "main"

      // TODO wire PHP version into pipeline
      VERSION = "0.0.1"

      // Job name contains the branch eg ds-app-feature%2Fjenkins-123
      JOB_NAME = "${JOB_NAME}".replace("%2F", "-").replace("/", "-")

      GIT_SSL_NO_VERIFY = true

      // Credentials bound in OpenShift
      GIT_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-git-auth")
      NEXUS_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-nexus-password")
      ARGOCD_CREDS = credentials("${OPENSHIFT_BUILD_NAMESPACE}-argocd-token")

      // Nexus Artifact repo
      NEXUS_REPO_NAME="labs-static"
      NEXUS_REPO_HELM = "helm-charts"
  }

  options {
      buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '1'))
      timeout(time: 15, unit: 'MINUTES')
      ansiColor('xterm')
      timestamps()
  }

  stages {
    stage('Prepare Environment') {
        failFast true
        parallel {
            stage("Release Build") {
                options {
                    skipDefaultCheckout(true)
                }
                agent {
                    node {
                        label "master"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("main") }
                }
                steps {
                    script {
                        env.TARGET_NAMESPACE = "labs-dev"
                        env.TESTING_NAMESPACE = "labs-test"
                        env.STAGING_NAMESPACE = "labs-staging"
                        env.IMAGE_REPOSITORY = 'image-registry.openshift-image-registry.svc:5000'
                        env.APP_NAME = "${NAME}".replace("/", "-").toLowerCase()
                        env.APP_NAME_UC = "${APP_NAME}".replace("-", "_").toLowerCase()
                    }
                }
            }
            stage("Sandbox Build") {
                options {
                    skipDefaultCheckout(true)
                }
                agent {
                    node {
                        label "master"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("dev") || GIT_BRANCH.startsWith("feature") || GIT_BRANCH.startsWith("fix") }
                }
                steps {
                    script {
                        env.TARGET_NAMESPACE = "labs-dev"
                        env.IMAGE_REPOSITORY = 'image-registry.openshift-image-registry.svc:5000'
                        env.APP_NAME = "${GIT_BRANCH}-${NAME}".replace("/", "-").toLowerCase()
                        env.APP_NAME_UC = "${APP_NAME}".replace("-", "_").toLowerCase()
                        env.NODE_ENV = "test"
                    }
                }
            }
            stage("Pull Request Build") {
                options {
                    skipDefaultCheckout(true)
                }
                agent {
                    node {
                        label "master"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("PR-") }
                }
                steps {
                    script {
                        env.TARGET_NAMESPACE = "labs-dev"
                        env.IMAGE_REPOSITORY = 'image-registry.openshift-image-registry.svc:5000'
                        env.APP_NAME = "${GIT_BRANCH}-${NAME}".replace("/", "-").toLowerCase()
                        env.APP_NAME_UC = "${APP_NAME}".replace("-", "_").toLowerCase()
                    }
                }
            }
        }
    }

    stage("Bake (OpenShift Build)") {
        failFast true
        parallel {
            stage("Bake tsgui image") {
                agent {
                    node {
                        label "jenkins-agent-argocd"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("main") }
                }
                steps {
                    // sh 'printenv'
                    sh  '''
                        oc get bc ${APP_NAME} || rc=$?
                        if [ "$rc" = "1" ]; then
                            echo " 🏗 no build - creating one 🏗"
                            oc new-build --name=${APP_NAME} -l app=${APP_NAME} --strategy=docker ${GIT_URL}#${GIT_BRANCH} --dry-run -o yaml > /tmp/bc.yaml
                            cat /tmp/bc.yaml
                            yq d -i /tmp/bc.yaml items[0].spec.triggers
                            cat /tmp/bc.yaml
                            oc apply -f /tmp/bc.yaml
                        fi

                        echo " 🏗 build found - starting it  🏗"
                        oc start-build ${APP_NAME} --follow
                    '''
                }
            }
        }
     }

    stage("Helm Package App (master)") {
        agent {
            node {
                label "jenkins-agent-helm"
            }
        }
        steps {
            sh 'printenv'
            sh '''
                git clone https://${ARGOCD_CONFIG_REPO} config-repo
                cd config-repo/
                git checkout ${ARGOCD_CONFIG_REPO_BRANCH}

                # lint chart
                echo '### Running chart linter ###'
                cd ${APP_NAME}/web
                helm lint chart

                # update values for deployment
                yq w -i chart/Chart.yaml 'appVersion' ${VERSION}
                yq w -i chart/Chart.yaml 'version' ${VERSION}
                yq w -i chart/Chart.yaml 'name' ${APP_NAME}
                yq w -i chart/values.yaml 'image_repository' ${IMAGE_REPOSITORY}
                yq w -i chart/values.yaml 'image_name' ${APP_NAME}
                yq w -i chart/values.yaml 'image_namespace' ${TARGET_NAMESPACE}
                yq w -i chart/values.yaml 'image_version' ${VERSION}

                # package and release helm chart
                echo '### Package and release helm chart ###'
                helm package chart/ --app-version ${VERSION} --version ${VERSION}
                curl -v -f -u ${NEXUS_CREDS} http://${SONATYPE_NEXUS_SERVICE_SERVICE_HOST}:${SONATYPE_NEXUS_SERVICE_SERVICE_PORT}/repository/${NEXUS_REPO_HELM}/ --upload-file ${APP_NAME}-${VERSION}.tgz
            '''
        }
    }

    stage("Deploy App") {
        failFast true
        parallel {
            stage("sandbox - helm3 publish and install") {
                options {
                    skipDefaultCheckout(true)
                }
                agent {
                    node {
                        label "jenkins-agent-helm"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("dev") || GIT_BRANCH.startsWith("feature") || GIT_BRANCH.startsWith("fix") }
                }
                steps {
                    // TODO - if SANDBOX, create release in rando ns
                    sh '''
                        helm upgrade --install ${APP_NAME} \
                            --namespace=${TARGET_NAMESPACE} \
                            http://${SONATYPE_NEXUS_SERVICE_SERVICE_HOST}:${SONATYPE_NEXUS_SERVICE_SERVICE_PORT}/repository/${NEXUS_REPO_HELM}/${APP_NAME}-${VERSION}.tgz
                    '''
                }
            }

            stage("Dev - ArgoCD sync") {
                options {
                    skipDefaultCheckout(true)
                }
                agent {
                    node {
                        label "jenkins-agent-argocd"
                    }
                }
                when {
                    expression { GIT_BRANCH.startsWith("main") }
                }
                steps {
                    echo '### Commit new image tag to git ###'
                    sh  '''
                        git clone https://${ARGOCD_CONFIG_REPO} config-repo
                        cd config-repo
                        git checkout ${ARGOCD_CONFIG_REPO_BRANCH}

                        # update image tag and version to align
                        oc tag ${OPENSHIFT_BUILD_NAMESPACE}/${APP_NAME}:latest ${TARGET_NAMESPACE}/${APP_NAME}:${VERSION}
                        yq w -i ${ARGOCD_CONFIG_REPO_PATH} "applications.${APP_NAME_UC}_dev.values.image_version" ${VERSION}


                        git config --global user.email "jenkins@rht-labs.bot.com"
                        git config --global user.name "Jenkins"
                        git config --global push.default simple

                        git add ${ARGOCD_CONFIG_REPO_PATH}
                        git commit -m "🚀 AUTOMATED COMMIT - Deployment new app version ${VERSION} 🚀" || rc=$?
                        git remote set-url origin  https://${GIT_CREDS_USR}:${GIT_CREDS_PSW}@${ARGOCD_CONFIG_REPO}
                        git push -u origin ${ARGOCD_CONFIG_REPO_BRANCH}
                    '''

                    echo '### Ask ArgoCD to Sync the changes and roll it out ###'
                    sh '''
                        # 1 Check sync not currently in progress . if so, kill it?
                        # 2. sync argocd to change pushed in previous step
                        ARGOCD_INFO="--auth-token ${ARGOCD_CREDS_PSW} --server ${ARGOCD_SERVER_SERVICE_HOST}:${ARGOCD_SERVER_SERVICE_PORT_HTTP} --insecure"
                        # sync individual app
                        argocd app sync ${APP_NAME}-dev ${ARGOCD_INFO}
                        argocd app wait ${APP_NAME}-dev ${ARGOCD_INFO}
                    '''
                }
            }

        }
    }

    stage("End to End Test") {
        agent {
            node {
                label "master"
            }
        }
        when {
            expression { GIT_BRANCH.startsWith("main") }
        }
        steps {
            sh  '''
                echo "TODO - Run tests"
            '''
        }
    }

    stage("Promote app to Test") {
        agent {
            node {
                label "jenkins-agent-argocd"
            }
        }
        when {
            expression { GIT_BRANCH.startsWith("main") }
        }
        steps {
            echo '### Promote to test ###'
            sh  '''
                git clone https://${ARGOCD_CONFIG_REPO} config-repo
                cd config-repo
                git checkout ${ARGOCD_CONFIG_REPO_BRANCH}

                # update image tag and version to align
                oc tag ${OPENSHIFT_BUILD_NAMESPACE}/${APP_NAME}:latest ${TESTING_NAMESPACE}/${APP_NAME}:${VERSION}
                yq w -i ${ARGOCD_CONFIG_REPO_PATH} "applications.${APP_NAME_UC}_test.values.image_version" ${VERSION}

                git config --global user.email "jenkins@rht-labs.bot.com"
                git config --global user.name "Jenkins"
                git config --global push.default simple

                git add ${ARGOCD_CONFIG_REPO_PATH}
                git commit -m "🚀 AUTOMATED COMMIT - Deployment new app version ${VERSION} 🚀" || rc=$?
                git remote set-url origin  https://${GIT_CREDS_USR}:${GIT_CREDS_PSW}@${ARGOCD_CONFIG_REPO}
                git push -u origin ${ARGOCD_CONFIG_REPO_BRANCH}
            '''

            echo '### Ask ArgoCD to Sync the changes and roll it out ###'
            sh '''
                # 1 Check sync not currently in progress . if so, kill it?
                # 2. sync argocd to change pushed in previous step
                ARGOCD_INFO="--auth-token ${ARGOCD_CREDS_PSW} --server ${ARGOCD_SERVER_SERVICE_HOST}:${ARGOCD_SERVER_SERVICE_PORT_HTTP} --insecure"
                # sync individual app
                argocd app sync ${APP_NAME}-test ${ARGOCD_INFO}
                argocd app wait ${APP_NAME}-test ${ARGOCD_INFO}
            '''
        }
    }
  }
}
