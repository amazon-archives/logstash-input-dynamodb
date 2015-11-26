# Logstash Plugin

NOTE: CONFIGURATION ON RUNNING THE INPUT PLUGIN FOR DYNAMODB LOOK AT THE BOTTOM

This is a plugin for [Logstash](https://github.com/elasticsearch/logstash).

It is fully free and fully open source. The license is Apache 2.0, meaning you are pretty much free to use it however you want in whatever way.

## Documentation

Logstash provides infrastructure to automatically generate documentation for this plugin. We use the asciidoc format to write documentation so any comments in the source code will be first converted into asciidoc and then into html. All plugin documentation are placed under one [central location](http://www.elasticsearch.org/guide/en/logstash/current/).

- For formatting code or config example, you can use the asciidoc `[source,ruby]` directive
- For more asciidoc formatting tips, see the excellent reference here https://github.com/elasticsearch/docs#asciidoc-guide

## Need Help?

Need help? Try #logstash on freenode IRC or the logstash-users@googlegroups.com mailing list.

## Developing

### 1. Plugin Development and Testing

#### Code
- To get started, you'll need JRuby with the Bundler gem installed.

- Create a new plugin or clone and existing from the GitHub [logstash-plugins](https://github.com/logstash-plugins) organization. We also provide [example plugins](https://github.com/logstash-plugins?query=example).

- Install dependencies
```sh
bundle install
```

#### Test

- Update your dependencies

#####TODO: NOT DONE YET
```sh
bundle install
```

- Run tests

```sh
bundle exec rspec
```

### 2. Running your unpublished Plugin in Logstash

#### 2.1 Run in a local Logstash clone

##### TODO need to figure out the local plugin path.  For now use 'gem build logstash-input-dynamodbstreams.gemspec' and add the absolute path of this the gem created to the Gemfile of the logstash app.
- Edit Logstash `Gemfile` and add the local plugin path, for example:
```ruby
gem "logstash-filter-awesome", :path => "/your/local/logstash-filter-awesome"
```
- Install plugin
```sh
bin/plugin install --no-verify
```
- Run Logstash with your plugin
```sh
bin/logstash -e 'filter {awesome {}}'
```
At this point any modifications to the plugin code will be applied to this local Logstash setup. After modifying the plugin, simply rerun Logstash.

#### 2.2 Run in an installed Logstash

You can use the same **2.1** method to run your plugin in an installed Logstash by editing its `Gemfile` and pointing the `:path` to your local plugin development directory or you can build the gem and install it using:

- Install all dependencies of the gem
```sh
bundle install
```

- Build your plugin gem
```sh
gem build logstash-filter-awesome.gemspec
```

- Install the plugin from the Logstash home
```sh
bin/plugin install /your/local/plugin/logstash-filter-awesome.gem
```
- Start Logstash and proceed to test the plugin

## Contributing

All contributions are welcome: ideas, patches, documentation, bug reports, complaints, and even something you drew up on a napkin.

Programming is not a required skill. Whatever you've seen about open source and maintainers or community members  saying "send patches or die" - you will not see that here.

It is more important to the community that you are able to contribute.

For more information about contributing, see the [CONTRIBUTING](https://github.com/elasticsearch/logstash/blob/master/CONTRIBUTING.md) file.

#Configuration for DynamoDB Logstash plugin

To run the DynamoDB Logstash plugin simply add a configuration following the below documentation.

An example configuration:
input {
    dynamodb {
        table_name => "My_DynamoDB_Table"
        endpoint => "dynamodb.us-west-1.amazonaws.com"
        streams_endpoint => "streams.dynamodb.us-west-1.amazonaws.com"
        aws_access_key_id => "my aws access key"
        aws_secret_access_key => "my aws secret access key"
        perform_scan => true
        perform_stream => true
        read_ops => 100
        number_of_write_threads => 8
        number_of_scan_threads => 8
        log_format => "plain"
        view_type => "new_and_old_images"
    }
}

#Configuration Parameters

config :<variable name>, <type of expected variable>, :required => <true if required to run>, :default => <default value of configuration>

  # The name of the table to copy and stream through Logstash
  config :table_name, :validate => :string, :required => true

  # Configuration for what information from the scan and streams to include in the log.
  # keys_only will return the hash and range keys along with the values for each entry
  # new_image will return the entire new entry and keys
  # old_image will return the entire entry before modification and keys (NOTE: Cannot perform scan when using this option)
  # new_and_old_images will return the old entry before modification along with the new entry and keys
  config :view_type, :validate => ["keys_only", "new_image", "old_image", "new_and_old_images"], :required => true

  # Endpoint from which the table is located. Example: dynamodb.us-east-1.amazonaws.com
  config :endpoint, :validate => :string, :required => true

  # Endpoint from which streams should read. Example: streams.dynamodb.us-east-1.amazonaws.com
  config :streams_endpoint, :validate => :string

  # AWS credentials access key.
  config :aws_access_key_id, :validate => :string, :default => ""

  # AWS credentials secret access key.
  config :aws_secret_access_key, :validate => :string, :default => ""

  # A flag to indicate whether or not the plugin should scan the entire table before streaming new records.
  # Streams will only push records that are less than 24 hours old, so in order to get the entire table
  # an initial scan must be done.
  config :perform_scan, :validate => :boolean, :default => true

  # A string that uniquely identifies the KCL checkpointer name and cloudwatch metrics name.
  # This is used when one worker leaves a shard so that another worker knows where to start again.
  config :checkpointer, :validate => :string, :default => "logstash_input_dynamodb_cptr"

  # Option to publish metrics to Cloudwatch using the checkpointer name.
  config :publish_metrics, :validate => :boolean, :default => false

  # Option to not automatically stream new data into logstash from DynamoDB streams.
  config :perform_stream, :validate => :boolean, :default => true

  # Number of read operations per second to perform when scanning the specified table.
  config :read_ops, :validate => :number, :default => 1

  # Number of threads to use when scanning the specified table
  config :number_of_scan_threads, :validate => :number, :default => 1

  # Number of threads to write to the logstash queue when scanning the table
  config :number_of_write_threads, :validate => :number, :default => 1

  # Configuation for how the logs will be transferred.
  # plain is simply pass the message along without editing it.
  # dynamodb will return just the data specified in the view_format in dynamodb format.
    # For more information see: docs.aws.amazon.com/amazondynamodb/latest/developerguide/DataFormat.html
  # json_drop_binary will return just the data specified in the view_format in JSON while not including any binary values that were present.
  # json_binary_as_text will return just the data specified in the view_format in JSON while including binary values as base64-encoded text.
  config :log_format, :validate => ["plain", "dynamodb", "json_drop_binary", "json_binary_as_text"], :default => "plain"

