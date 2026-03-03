pipeline
{
    
agent any
environment {
    MY_VAR = "Hello, Hun!"
}
parameters {
    string (name: 'MY_NAME', defaultValue: 'Csacsi', description: 'My nick name')
    choice choices: ['dev', 'prod'], name: 'select_environment'
    choice(choices:['Hello','Bye'], description: 'Users Choice', name: 'CHOICE')
}
stages {
    stage ('build') 
    {
        steps {
            echo "This is the build stage"
        }
    }
    stage ('test') 
    {
        steps {
            echo "This is the test stage"
        }
    }
    stage ('deploy') 
    {
        steps {
            echo "This is the deploy stage"
        }
    }
    stage ('bat')
    {
        steps {
            dir ("C://Users/Csacso/AppData/Local/Jenkins/.jenkins/workspace/pipeline_test") {
                bat "bat1.bat"
            }
        }
    }
    stage ('py')
    {
        steps {
            dir ("C://Users/Csacso/AppData/Local/Jenkins/.jenkins/workspace/pipeline_test") {
                bat "python hello.py"
            }
        }
    }
    stage ('groovy')
    {
        steps {
            script {
                def file = load "script.groovy"
                file.hello ()
            }
        }
    }
    stage ('when')
    {
        when {
            expression { return params.select_environment == 'dev' }
        }
        steps {
            echo "This stage runs only if the 'dev' environment is selected otherwise skipped"
        }
    }
    stage ('input') {
        steps('Input') {
            echo "choice: ${CHOICE}"
            echo "choice params.: " + params.CHOICE
            echo "choice env: " + env.CHOICE
        }
    }
    stage('Hello') {
        when { 
            expression { env.CHOICE == 'Hello' }
        }   
            
        steps('Execute')    {
            echo 'Say Hello'
        } 
    }           
    stage('Bye') {
        when {
            expression {env.CHOICE == 'Bye'}
        }
            
        steps('Execute'){
            echo 'Say Bye'    
        }
    }
    stage ('final')
    {
        parallel {
            stage ('final_A') {
                steps {
                    echo "This is the final_A stage"
                }
            }
            stage ('final_B') {
                steps {
                    echo "This is the final_B stage"
                }
            }
        }
        post {
            always {
                echo "This post will always run" + " " + "${MY_VAR}" + " " + "${params.MY_NAME}"
            }
            success {
                echo "This post will run only if successful"
            }
            failure {
                echo "This post will run only if failed"
            }
        }
    }
}
}