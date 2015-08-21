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

describe 'inputs/LogStashRecordProcessor' do
  before(:each) do
    @queue = SizedQueue.new(20)
    @processor = Logstash::Inputs::DynamoDB::LogStashRecordProcessor.new(@queue)
  end

  it "should call setShardId when being called with a String" do
    processor_with_shard = Logstash::Inputs::DynamoDB::LogStashRecordProcessor.new("test shardId")
    expect(processor_with_shard.shard_id).to eq("test shardId")
  end

  it "should not call setShardId when being called with a queue" do
    expect(@processor.queue).to eq(@queue)
    expect(@processor.shard_id).to be_nil
  end

  it "should checkpoint when shutdown is called with reason TERMINATE" do
    checkpointer = mock("checkpointer")
    checkpointer.expects(:checkpoint).once
    @processor.shutdown(checkpointer, ShutdownReason::TERMINATE)
  end

  it "should not checkpoint when shutdown is called with reason ZOMBIE" do
    checkpointer = mock("checkpointer")
    checkpointer.expects(:checkpoint).never
    @processor.shutdown(checkpointer, ShutdownReason::ZOMBIE)
  end

  it "should raise error when shutdown is called with unknown reason" do
    expect {@processor.shutdown("some checkpointer", "unknown reason")}.to raise_error(RuntimeError)
  end

  it "should translate each record into String, push them onto queue, and then checkpoint when process_records is called" do
    checkpointer = mock("checkpointer")
    checkpointer.expects(:checkpoint).once

    records = [{"a records data" => "a records value"}, {"another records data" => "another records value"}]
    @processor.process_records(records, checkpointer)
  end

end

describe 'inputs/LogStashRecordProcessorFactory' do

  it "should create a new factory correctly and create a new LogStashRecordProcessor when called upon" do
    queue = SizedQueue.new(20)
    factory = Logstash::Inputs::DynamoDB::LogStashRecordProcessorFactory.new(queue)
    processor = factory.create_processor
    expect(processor).to be_an_instance_of(Logstash::Inputs::DynamoDB::LogStashRecordProcessor)
  end

end
