Gem::Specification.new do |s|
  s.name = 'logstash-input-dynamodb'
  s.version = '1.0.1'
  s.licenses = ['Apache License (2.0)']
  s.summary = "This input plugin scans a specified DynamoDB table and then reads changes to a DynamoDB table from the associated DynamoDB Stream."
  s.description = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors = ["Amazon"]
  s.email = 'dynamodb-interest@amazon.com'
  s.homepage = "https://github.com/logstash-plugins/logstash-input-dynamodb"
  s.require_paths = ["lib"]
  s.platform = 'java'

  # Files
  s.files = `git ls-files`.split($\)
   # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "input" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core", ">= 2.0.0", "< 3.0.0"
  s.add_runtime_dependency 'logstash-codec-json'
  s.add_runtime_dependency 'stud', '>= 0.0.22'
  s.add_runtime_dependency "activesupport-json_encoder"
  s.add_development_dependency 'logstash-devutils', '>= 0.0.16'
  # Jar dependencies
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-elasticbeanstalk', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-ses', '1.10.11' "
  s.requirements << "jar 'log4j:log4j', '1.2.17'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-opsworks', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:dynamodb-streams-kinesis-adapter', '1.0.0'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-sqs', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-emr', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudformation', '1.10.11'"
  s.requirements << "jar 'com.beust:jcommander', '1.48'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-redshift', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-iam', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-codedeploy', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-dynamodb', '1.10.10'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-directconnect', '1.10.11'"
  s.requirements << "jar 'org.apache.httpcomponents:httpclient', '4.4.1'"
  s.requirements << "jar 'org.apache.httpcomponents:httpcore', '4.4.1'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-sns', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-directory', '1.10.11'"
  s.requirements << "jar 'com.google.protobuf:protobuf-java', '2.6.1'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudfront', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-kinesis', '1.10.8'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-workspaces', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-swf-libraries', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudhsm', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-simpledb', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-codepipeline', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-s3', '1.10.10'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cognitoidentity', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-machinelearning', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-logs', '1.10.11'"
  s.requirements << "jar 'org.apache.commons:commons-lang3', '3.3.2'"
  s.requirements << "jar 'commons-codec:commons-codec', '1.6'"
  s.requirements << "jar 'com.fasterxml.jackson.core:jackson-annotations', '2.5.0'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-sts', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-route53', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-elasticloadbalancing', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-storagegateway', '1.10.11'"
  s.requirements << "jar 'org.apache.httpcomponents:httpcore', '4.3.3'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-efs', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-ec2', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-ssm', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-core', '1.10.10'"
  s.requirements << "jar 'com.amazonaws:dynamodb-import-export-tool', '1.0.0'"
  s.requirements << "jar 'commons-lang:commons-lang', '2.6'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-config', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudtrail', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-elastictranscoder', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-codecommit', '1.10.11'"
  s.requirements << "jar 'joda-time:joda-time', '2.5'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-importexport', '1.10.11'"
  s.requirements << "jar 'com.fasterxml.jackson.core:jackson-databind', '2.5.3'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudsearch', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:amazon-kinesis-client', '1.6.0'"
  s.requirements << "jar 'com.google.guava:guava', '15.0'"
  s.requirements << "jar 'com.fasterxml.jackson.core:jackson-core', '2.5.3'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-rds', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cognitosync', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-datapipeline', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-support', '1.10.11'"
  s.requirements << "jar 'commons-logging:commons-logging', '1.1.3'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudwatchmetrics', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-glacier', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-elasticache', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-simpleworkflow', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-lambda', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-autoscaling', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-ecs', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-devicefarm', '1.10.11'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-kms', '1.10.10'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk-cloudwatch', '1.10.8'"
  s.add_runtime_dependency 'jar-dependencies'
  # Development dependencies
  s.add_development_dependency "mocha"
end
