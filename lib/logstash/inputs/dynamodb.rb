# encoding: utf-8
#
#Copyright 2015 Amazon.com, Inc. or its affiliates. All Rights Reserved.
#
#Licensed under the Apache License, Version 2.0 (the "License");
#you may not use this file except in compliance with the License.
#You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
#Unless required by applicable law or agreed to in writing, software
#distributed under the License is distributed on an "AS IS" BASIS,
#WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#See the License for the specific language governing permissions and
#limitations under the License.
#
require "logstash/inputs/base"
require "logstash/namespace"
require "securerandom"
require "thread"
require "socket"
require_relative "LogStashRecordProcessorFactory"
require_relative "DynamoDBLogParser"

require "logstash-input-dynamodb_jars"

require 'java'
java_import "com.amazonaws.AmazonClientException"
java_import "org.apache.log4j.LogManager"
java_import "org.apache.log4j.Level"
java_import "com.fasterxml.jackson.annotation.JsonInclude"
java_import "com.amazonaws.regions.RegionUtils"

module AmazonDynamoDB
  include_package "com.amazonaws"
  include_package "com.amazonaws.services.dynamodbv2"
  include_package "com.amazonaws.services.dynamodbv2.streamsadapter"
  include_package "com.amazonaws.services.dynamodbv2.model"
end
module AmazonCredentials
  include_package "com.amazonaws.auth"
  include_package "com.amazonaws.internal"
end

module DynamoDBBootstrap
  include_package "com.amazonaws.dynamodb.bootstrap"
end

module CloudWatch
  include_package "com.amazonaws.services.cloudwatch"
end

module KCL
  include_package "com.amazonaws.services.kinesis.clientlibrary.lib.worker"
end

#DynamoDBStreams plugin that will first scan the DynamoDB table
#and then consume streams and push those records into Logstash
class LogStash::Inputs::DynamoDB < LogStash::Inputs::Base
  config_name "dynamodb"

  USER_AGENT = " logstash-input-dynamodb/1.0.0".freeze

  LF_DYNAMODB = "dynamodb".freeze
  LF_JSON_NO_BIN = "json_drop_binary".freeze
  LF_PLAIN = "plain".freeze
  LF_JSON_BIN_AS_TEXT = "json_binary_as_text".freeze
  LF_EXTENDED = "extended".freeze
  VT_KEYS_ONLY = "keys_only".freeze
  VT_OLD_IMAGE = "old_image".freeze
  VT_NEW_IMAGE = "new_image".freeze
  VT_ALL_IMAGES = "new_and_old_images".freeze

  default :codec, 'json'

  # The name of the table to copy and stream through Logstash
  config :table_name, :validate => :string, :required => true

  # Configuration for what information from the scan and streams to include in the log.
  # keys_only will return the hash and range keys along with the values for each entry
  # new_image will return the entire new entry and keys
  # old_image will return the entire entry before modification and keys (NOTE: Cannot perform scan when using this option)
  # new_and_old_images will return the old entry before modification along with the new entry and keys
  config :view_type, :validate => [VT_KEYS_ONLY, VT_OLD_IMAGE, VT_NEW_IMAGE, VT_ALL_IMAGES], :required => true

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
  config :log_format, :validate => [LF_PLAIN, LF_DYNAMODB, LF_JSON_NO_BIN, LF_JSON_BIN_AS_TEXT, LF_EXTENDED], :default => "plain"

  public
  def build_credentials
    if !@aws_access_key_id.to_s.empty? and !@aws_secret_access_key.to_s.empty?
      @logger.info("Using static credentials: " + @aws_access_key_id + ", " + @aws_secret_access_key)
      basic = AmazonCredentials::BasicAWSCredentials.new(@aws_access_key_id, @aws_secret_access_key)
      return AmazonCredentials::StaticCredentialsProvider.new(basic)
    else
      @logger.info("Using default provider chain")
      return AmazonCredentials::DefaultAWSCredentialsProviderChain.new()
    end # if neither aws access keys
  end # def build_credentials

  public
  def register
    LogStash::Logger.setup_log4j(@logger)

    @host = Socket.gethostname
    @logger.info("Tablename: " + @table_name)
    @queue = SizedQueue.new(20)
    @credentials = build_credentials()
    @logger.info("Checkpointer: " + @checkpointer)

    if @perform_scan and @view_type == VT_OLD_IMAGE
      raise(LogStash::ConfigurationError, "Cannot perform scan with view type: " + @view_type + " configuration")
    end
    if @view_type == VT_ALL_IMAGES and ![LF_PLAIN, LF_EXTENDED].include?(@log_format)
      raise(LogStash::ConfigurationError, "Cannot show view_type: " + @view_type + ", with log_format: " + @log_format)
    end

    #Create DynamoDB Client
    @client_configuration = AmazonDynamoDB::ClientConfiguration.new()
    @client_configuration.setUserAgent(@client_configuration.getUserAgent() + USER_AGENT)
    @dynamodb_client = AmazonDynamoDB::AmazonDynamoDBClient.new(@credentials, @client_configuration)

    @logger.info(@dynamodb_client.to_s)

    @dynamodb_client.setEndpoint(@endpoint)
    @logger.info("DynamoDB endpoint: " + @endpoint)

    @key_schema = Array.new
    @table_description = @dynamodb_client.describeTable(@table_name).getTable()
    key_iterator = @table_description.getKeySchema().iterator()
    while(key_iterator.hasNext())
      @key_schema.push(key_iterator.next().getAttributeName().to_s)
    end
    region = RegionUtils.getRegionByEndpoint(@endpoint)

    @parser ||= Logstash::Inputs::DynamoDB::DynamoDBLogParser.new(@view_type, @log_format, @key_schema, region, @table_name)

    if @perform_stream
      setup_stream
    end # unless @perform_stream
  end # def register

  public
  def run(logstash_queue)
    begin
      run_with_catch(logstash_queue)
    rescue LogStash::ShutdownSignal
      exit_threads
      until @queue.empty?
        @logger.info("Flushing rest of events in logstash queue")
        event = @queue.pop()
        queue_event(@parser.parse_stream(event), logstash_queue, @host)
      end # until !@queue.empty?
    end # begin
  end # def run(logstash_queue)

  # Starts KCL app in a background thread
  # Starts parallel scan if need be in a background thread
  private
  def run_with_catch(logstash_queue)
    if @perform_scan
      scan(logstash_queue)
    end # if @perform_scan

    # Once scan is finished, start kcl thread to read from streams
    if @perform_stream
      stream(logstash_queue)
    end # unless @perform_stream
  end # def run

  private
  def setup_stream
    worker_id = SecureRandom.uuid()
    @logger.info("WorkerId: " + worker_id)

    dynamodb_streams_client = AmazonDynamoDB::AmazonDynamoDBStreamsClient.new(@credentials, @client_configuration)
    adapter = Java::ComAmazonawsServicesDynamodbv2Streamsadapter::AmazonDynamoDBStreamsAdapterClient.new(@credentials)
    if !@streams_endpoint.nil?
      adapter.setEndpoint(@streams_endpoint)
      dynamodb_streams_client.setEndpoint(@streams_endpoint)
      @logger.info("DynamoDB Streams endpoint: " + @streams_endpoint)
    else
      raise(LogStash::ConfigurationError, "Cannot stream without a configured streams endpoint")
    end # if not @streams_endpoint.to_s.empty?

    stream_arn = nil
    begin
      stream_arn = @table_description.getLatestStreamArn()
      stream_description = dynamodb_streams_client.describeStream(AmazonDynamoDB::DescribeStreamRequest.new() \
        .withStreamArn(stream_arn)).getStreamDescription()

      stream_status = stream_description.getStreamStatus()

      stream_view_type = stream_description.getStreamViewType().to_s.downcase
      unless (stream_view_type == @view_type or @view_type == VT_KEYS_ONLY or stream_view_type == VT_ALL_IMAGES)
        raise(LogStash::ConfigurationError, "Cannot stream " + @view_type + " when stream is setup for " + stream_view_type)
      end

      while stream_status == "ENABLING"
        if(stream_status == "ENABLING")
          @logger.info("Sleeping until stream is enabled")
          sleep(1)
        end # if stream_status == "ENABLING"
        stream_description = dynamodb_streams_client.describeStream(AmazonDynamoDB::DescribeStreamRequest.new() \
          .withStreamArn(stream_arn)).getStreamDescription()
        stream_status = stream_description.getStreamStatus()
      end # while not active

      if !(stream_status == "ENABLED")
        raise(LogStash::PluginLoadingError, "No streams are enabled")
      end # if not active
      @logger.info("Stream Id: " + stream_arn)
    rescue AmazonDynamoDB::ResourceNotFoundException => rnfe
      raise(LogStash::PluginLoadingError, rnfe.message)
    rescue AmazonClientException => ace
      raise(LogStash::ConfigurationError, "AWS credentials invalid or not found in the provider chain\n" + ace.message)
    end # begin

    kcl_config = KCL::KinesisClientLibConfiguration.new(@checkpointer, stream_arn, @credentials, worker_id) \
      .withInitialPositionInStream(KCL::InitialPositionInStream::TRIM_HORIZON)
		cloudwatch_client = nil
    if @publish_metrics
      cloudwatch_client = CloudWatch::AmazonCloudWatchClient.new(@credentials)
    else
      kclMetricsLogger = LogManager.getLogger("com.amazonaws.services.kinesis.metrics")
      kclMetricsLogger.setAdditivity(false)
      kclMetricsLogger.setLevel(Level::OFF)
    end # if @publish_metrics
    @worker = KCL::Worker.new(Logstash::Inputs::DynamoDB::LogStashRecordProcessorFactory.new(@queue), kcl_config, adapter, @dynamodb_client, cloudwatch_client)
  end # def setup_stream

  private
  def scan(logstash_queue)
    @logger.info("Starting scan...")
    @logstash_writer = DynamoDBBootstrap::BlockingQueueConsumer.new(@number_of_write_threads)

    @connector = DynamoDBBootstrap::DynamoDBBootstrapWorker.new(@dynamodb_client, @read_ops, @table_name, @number_of_scan_threads)
    start_table_copy_thread

    scan_queue = @logstash_writer.getQueue()
    while true
      event = scan_queue.take()
      if event.getEntry().nil? and event.getSize() == -1
        break
      end # if event.isEmpty()
      queue_event(@parser.parse_scan(event.getEntry(), event.getSize()), logstash_queue, @host)
    end # while true
  end

  private
  def stream(logstash_queue)
    @logger.info("Starting stream...")
    start_kcl_thread

    while true
      event = @queue.pop()
      queue_event(@parser.parse_stream(event), logstash_queue, @host)
    end # while true
  end

  private
  def exit_threads
    unless @dynamodb_scan_thread.nil?
      @dynamodb_scan_thread.exit
    end # unless @dynamodb_scan_thread.nil?

    unless @kcl_thread.nil?
      @kcl_thread.exit
    end # unless @kcl_thread.nil?
  end # def exit_threads

  public
  def queue_event(event, logstash_queue, event_host)
    logstash_event = LogStash::Event.new("message" => event, "host" => event_host)
    decorate(logstash_event)
    logstash_queue << logstash_event
  end # def queue_event

  private
  def start_table_copy_thread
    @dynamodb_scan_thread = Thread.new(@connector, @logstash_writer) {
      begin
        @connector.pipe(@logstash_writer)
      rescue Exception => e
        abort("Scanning the table caused an error.\n" + e.message)
      end # begin
    }
  end # def start_table_copy_thread()

  private
  def start_kcl_thread
    @kcl_thread = Thread.new(@worker) {
      begin
        @worker.run()
      rescue Exception => e
        abort("KCL worker encountered an error.\n" + e.message)
      end # begin
    }
  end # def start_kcl_thread

end # class Logstash::Inputs::DynamoDB
