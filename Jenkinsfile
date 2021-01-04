pipeline {
    agent any
    stages {
        stage('Copy Base Build') {
            when { not { environment name: 'JOPT_BASE_BUILD', value: '' } }
            steps {
                build job: 'Copy base build', parameters: [
                    string(name: 'JOPT_BASE_BUILD', value: "${JOPT_BASE_BUILD}"),
                    string(name: 'JOPT_UPLOAD_DIR', value: "${JOPT_UPLOAD_DIR}")
                    ]
            }
        }
        stage('Build') {
            parallel {
                stage('Linux build') {
                    when { environment name: 'JOPT_RUN_LINUX64', value: 'true' }
                    steps {
                        script {
                            def allParams = params.collect{
                                if (it.value instanceof java.lang.Boolean) {
                                    return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                                } else {
                                    return string(name: it.key, value: it.value)
                                }
                            }
                            build job: 'Build Linux-64 components', parameters: allParams
                        }
                    }
                }
                stage('Windows build') {
                    when { environment name: 'JOPT_RUN_WIN', value: 'true' }
                    steps {
                        script {
                            def allParams = params.collect{
                                if (it.value instanceof java.lang.Boolean) {
                                    return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                                } else {
                                    return string(name: it.key, value: it.value)
                                }
                            }
                            build job: 'Build Windows components', parameters: allParams
                        }
                    }
                }
                stage('macOS build') {
                    when { environment name: 'JOPT_RUN_OSX', value: 'true' }
                    steps {
                        script {
                            def allParams = params.collect{
                                if (it.value instanceof java.lang.Boolean) {
                                    return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                                } else {
                                    return string(name: it.key, value: it.value)
                                }
                            }
                            build job: 'Build OSX components', parameters: allParams
                        }
                    }
                }
            }
        }
        stage('Run repogen') {
            when { environment name: 'JOPT_RUN_REPOGEN', value: 'true' }
            steps {
                script {
                    def allParams = params.collect{
                        if (it.value instanceof java.lang.Boolean) {
                            return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                        } else {
                            return string(name: it.key, value: it.value)
                        }
                    }
                    build job: 'Run repogen', parameters: allParams
                }
            }
        }
        stage('Deploy installer to sdkautotest') {
            when { environment name: 'JOPT_RUN_AUTOTEST', value: 'true' }
            steps {
                script {
                    def allParams = params.collect{
                        if (it.value instanceof java.lang.Boolean) {
                            return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                        } else {
                            return string(name: it.key, value: it.value)
                        }
                    }
                    build job: 'Deploy installer to sdkautotest', parameters: allParams
                }
            }
        }
        stage('Run automated tests') {
            when { environment name: 'JOPT_RUN_AUTOTEST', value: 'true' }
            steps {
                script {
                    def allParams = params.collect{
                        if (it.value instanceof java.lang.Boolean) {
                            return booleanParam(name: it.key, value: Boolean.valueOf(it.value))
                        } else {
                            return string(name: it.key, value: it.value)
                        }
                    }
                    build job: 'sdk-test-suite', parameters: allParams
                }
            }
        }
    }
}
