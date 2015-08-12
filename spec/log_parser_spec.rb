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
require "logstash/devutils/rspec/spec_helper"
require "logstash/inputs/DynamoDBLogParser"
require "logstash/inputs/dynamodb"
require "rspec/expectations"
require "rspec/mocks"
require "mocha"
require "java"

RSpec.configure do |config|
  config.mock_with :mocha
end

class DynamoDBLogParserTest < DynamoDBLogParser

  private
  def calculate_key_size_in_bytes(record)
    return 10
  end

end

describe "inputs/LogParser" do
  let (:object_mapper) {mock("ObjectMapper")}
  let (:key_schema) {["TBCZDPHPXUTOTYGP", "some bin key"]}
  let (:sample_scan_result) {{"TBCZDPHPXUTOTYGP" => {"S" => "sampleString"}, "some bin key" => {"B" => "actualbinval"}}}
  let (:sample_stream_result) {{"internalObject" => {"eventID" => "0","eventName" => "INSERT","eventVersion" => "1.0", \
    "eventSource" => "aws:dynamodb","awsRegion" => "us-west-1","dynamodb" => {"keys" => {"TBCZDPHPXUTOTYGP" => {"S" => "sampleString"}, \
    "some bin key" => {"B" => "actualbinval"}}, "newImage" => {"TBCZDPHPXUTOTYGP" => {"S" => "sampleString"}, \
    "some bin key" => {"B" => "actualbinval"}},"sequenceNumber" => "0","sizeBytes" => 48,"streamViewType" => LogStash::Inputs::DynamoDB::VT_ALL_IMAGES.upcase}}}}

  before(:each) do
    Java::comFasterxmlJacksonDatabind::ObjectMapper.expects(:new).returns(object_mapper)
    object_mapper.expects(:setSerializationInclusion)
    object_mapper.expects(:addMixInAnnotations)
  end

  def expect_parse_stream()
    object_mapper.expects(:writeValueAsString).with(sample_stream_result).returns(sample_stream_result)
    JSON.expects(:parse).with(sample_stream_result).returns(sample_stream_result)
  end

  def expect_parse_scan()
    object_mapper.expects(:writeValueAsString).with(sample_scan_result).returns(sample_scan_result)
    JSON.expects(:parse).with(sample_scan_result).returns(sample_scan_result)
  end

  it "should parse a scan and parse a stream the same way" do
    expect_parse_stream
    expect_parse_scan
    parser = DynamoDBLogParserTest.new(LogStash::Inputs::DynamoDB::VT_ALL_IMAGES, LogStash::Inputs::DynamoDB::LF_PLAIN, key_schema, "us-west-1")
    scan_after_parse = parser.parse_scan(sample_scan_result, 38)
    stream_after_parse = parser.parse_stream(sample_stream_result)
    expect(scan_after_parse).to eq(stream_after_parse)
  end

  it "should drop binary values when parsing into a json with the correct configuration" do
    expect_parse_scan
    parser = DynamoDBLogParserTest.new(LogStash::Inputs::DynamoDB::VT_NEW_IMAGE, LogStash::Inputs::DynamoDB::LF_JSON_NO_BIN, key_schema, "us-west-1")
    result = parser.parse_scan(sample_scan_result, 38)
    expect(result).to eq({"TBCZDPHPXUTOTYGP" => "sampleString"}.to_json)
  end

end
