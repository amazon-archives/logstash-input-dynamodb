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
require "spec/spec_helper"

class LogStash::Inputs::TestDynamoDB < LogStash::Inputs::DynamoDB
  default :codec, 'json'

  private
  def shutdown_count
    @shutdown_count ||= 0
  end

  def queue_event(event, logstash_queue, host)
    super(event, logstash_queue, host)
    # Add additional item to plugin's queue to ensure run() flushes queue before shutting down.
    # Queue the event and then shutdown, otherwise the threads would run forever
    if shutdown_count == 0
      @shutdown_count += 1
      @queue << "additional event stuck in queue during shutdown"
      raise LogStash::ShutdownSignal
    end
  end

  def start_kcl_thread()
    @queue << "some message from kcl thread calling process"
  end
end

class TestParser

  def parse_scan(msg)
    return msg
  end

  def parse_stream(msg)
    return msg
  end

end

describe 'inputs/dynamodb' do
  let (:dynamodb_client) {mock("AmazonDynamoDB::AmazonDynamoDBClient")}
  let (:dynamodb_streams_client) {mock("AmazonDynamoDB::AmazonDynamoDBStreamsClient")}
  let (:adapter) {mock("AmazonDynamoDB::AmazonDynamoDBStreamsAdapterClient")}
  let (:parser) {mock("DynamoDBLogParser")}
  let (:region_utils) {mock("RegionUtils")}

  def allow_invalid_credentials(stream_status = "ENABLED", error_to_raise = nil)
    AmazonDynamoDB::AmazonDynamoDBClient.expects(:new).returns(dynamodb_client)
    AmazonDynamoDB::AmazonDynamoDBStreamsClient.expects(:new).returns(dynamodb_streams_client)
    AmazonDynamoDB::AmazonDynamoDBStreamsAdapterClient.expects(:new).returns(adapter)
    Logstash::Inputs::DynamoDB::DynamoDBLogParser.expects(:new).returns(TestParser.new())
    RegionUtils.expects(:getRegionByEndpoint).with("some endpoint").returns("some region")

    mock_table_description = stub
    mock_table = stub
    mock_key_schema = stub
    mock_iterator = stub
    mock_describe_stream = stub
    mock_stream_description = stub
    unless error_to_raise.nil?
      dynamodb_client.expects(:describeTable).raises(error_to_raise)
      return
    end

    adapter.expects(:setEndpoint).with("some streams endpoint")
    dynamodb_streams_client.expects(:setEndpoint).with("some streams endpoint")
    dynamodb_streams_client.expects(:describeStream).returns(mock_describe_stream)
    mock_describe_stream.expects(:getStreamDescription).returns(mock_stream_description)
    mock_stream_description.expects(:getStreamStatus).returns(stream_status)
    mock_stream_description.expects(:getStreamViewType).returns("new_and_old_images")
    mock_table.expects(:getLatestStreamArn).returns("test streamId")
    dynamodb_client.expects(:setEndpoint)
    dynamodb_client.expects(:describeTable).returns(mock_table_description)
    mock_table_description.expects(:getTable).returns(mock_table)
    mock_table.expects(:getKeySchema).returns(mock_key_schema)
    mock_key_schema.expects(:iterator).returns(mock_iterator)
    mock_iterator.expects(:hasNext).returns(false)

  end

	it "should not allow empty config" do
    expect {LogStash::Plugin.lookup("input", "dynamodb").new(empty_config)}.to raise_error(LogStash::ConfigurationError)
  end

	it "should need endpoint" do
    config = tablename
    config.delete("endpoint")
    expect {LogStash::Plugin.lookup("input", "dynamodb").new(config)}.to raise_error(LogStash::ConfigurationError)
  end

	it "should need table_name config" do
    config = tablename
    config.delete("table_name")
    expect {LogStash::Plugin.lookup("input", "dynamodb").new(config)}.to raise_error(LogStash::ConfigurationError)
  end

	it "should need view_type config" do
    config = tablename
    config.delete("view_type")
    expect {LogStash::Plugin.lookup("input", "dynamodb").new(config)}.to raise_error(LogStash::ConfigurationError)
  end

  it "should use default AWS credentials " do
    input = LogStash::Plugin.lookup("input", "dynamodb").new(tablename)
    expect(input.build_credentials()).to be_an_instance_of(Java::ComAmazonawsAuth::DefaultAWSCredentialsProviderChain)
  end

  it "should register correctly" do
    input = LogStash::Plugin.lookup("input", "dynamodb").new(invalid_aws_credentials_config)
    allow_invalid_credentials()
    expect {input.register}.not_to raise_error
  end

  it "should create new logstash event with metadata and add to queue" do
    input = LogStash::Plugin.lookup("input", "dynamodb").new(invalid_aws_credentials_config)
    queue = SizedQueue.new(20)
    input.queue_event("some message", queue, "some host")
    expect(queue.size()).to eq(1)
    event = queue.pop()
    expect(event["message"]).to eq("some message")
    expect(event["host"]).to eq("some host")
  end

  it "should start mock kcl worker thread and receive event from it, then flush additional events stuck in queue before shutting down" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({'perform_scan' => false}))
    allow_invalid_credentials()
    input.register
    queue = SizedQueue.new(20)
    input.run queue
    expect(queue.size()).to eq(2)
    event = queue.pop()
    expect(event["message"]).to eq("some message from kcl thread calling process")
    event = queue.pop()
    expect(event["message"]).to eq("additional event stuck in queue during shutdown")
  end

  it "should raise error since no active streams" do
    input = LogStash::Plugin.lookup("input", "dynamodb").new(invalid_aws_credentials_config)
    allow_invalid_credentials(stream_status="DISABLED")
    expect {input.register}.to raise_error(LogStash::PluginLoadingError, "No streams are enabled")
  end

  it "should handle error for nonexistent table" do
    input = LogStash::Plugin.lookup("input", "dynamodb").new(invalid_aws_credentials_config)
    allow_invalid_credentials(error_to_raise=Java::ComAmazonawsServicesDynamodbv2Model::ResourceNotFoundException.new("table does not exist"))
    expect {input.register}.to raise_error(LogStash::PluginLoadingError)
  end

  it "should allow cloudwatch metrics when specified by user" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({"publish_metrics" => true}))
    allow_invalid_credentials()
    cloudwatch_mock = mock("Java::ComAmazonawsServicesCloudwatch::AmazonCloudWatchClient")
    Java::ComAmazonawsServicesCloudwatch::AmazonCloudWatchClient.expects(:new).returns(cloudwatch_mock)
    
    input.register
  end

  it "should throw error trying to perform scan with old images" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({"view_type" => LogStash::Inputs::DynamoDB::VT_OLD_IMAGE, \
      "perform_scan" => true}))
    expect {input.register}.to raise_error(LogStash::ConfigurationError)
  end

  it "should throw error when view type all images and dynamodb format" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({"view_type" => LogStash::Inputs::DynamoDB::VT_ALL_IMAGES, \
      "log_format" => LogStash::Inputs::DynamoDB::LF_DYNAMODB}))
    expect {input.register}.to raise_error(LogStash::ConfigurationError)
  end

  it "should throw error when view type all images and json_drop_binary format" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({"view_type" => LogStash::Inputs::DynamoDB::VT_ALL_IMAGES, \
      "log_format" => LogStash::Inputs::DynamoDB::LF_JSON_NO_BIN}))
    expect {input.register}.to raise_error(LogStash::ConfigurationError)
  end

  it "should throw error when view type all images and json_binary_as_text format" do
    input = LogStash::Inputs::TestDynamoDB.new(invalid_aws_credentials_config.merge({"view_type" => LogStash::Inputs::DynamoDB::VT_ALL_IMAGES, \
      "log_format" => LogStash::Inputs::DynamoDB::LF_JSON_BIN_AS_TEXT}))
    expect {input.register}.to raise_error(LogStash::ConfigurationError)
  end


end
