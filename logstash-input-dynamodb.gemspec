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
  s.requirements << "jar 'log4j:log4j', '1.2.17'"
  s.requirements << "jar 'com.amazonaws:aws-java-sdk', '1.10.67'"
  s.requirements << "jar 'com.amazonaws:dynamodb-import-export-tool', '1.0.0'"
  s.requirements << "jar 'com.amazonaws:amazon-kinesis-client', '1.6.2'"
  s.requirements << "jar 'org.apache.httpcomponents:httpclient', '4.4.1'"
  s.requirements << "jar 'org.apache.httpcomponents:httpcore', '4.4.1'"
  s.requirements << "jar 'com.amazonaws:dynamodb-streams-kinesis-adapter', '1.0.2'"
  s.requirements << "jar 'com.google.guava:guava', '15.0'"
  s.add_runtime_dependency 'jar-dependencies'
  # Development dependencies
  s.add_development_dependency "mocha"
end
