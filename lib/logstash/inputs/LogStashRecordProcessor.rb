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
require "java"

require "logstash-input-dynamodb_jars"
java_import "com.amazonaws.services.kinesis.clientlibrary.types.ShutdownReason"
java_import "java.lang.IllegalStateException"
java_import "org.apache.log4j.LogManager"

module Logstash
  module Inputs
    module DynamoDB
      class LogStashRecordProcessor
        include com.amazonaws.services.kinesis.clientlibrary.interfaces::IRecordProcessor

        attr_accessor :queue, :shard_id

        def initialize(queue)
          # Workaround for IRecordProcessor.initialize(String shardId) interfering with constructor.
          # No good way to overload methods in JRuby, so deciding which was supposed to be called here.
          if (queue.is_a? String)
            @shard_id  = queue
            return
          else
            @queue ||= queue
            @logger ||= LogStash::Inputs::DynamoDB.logger
          end
        end

        def process_records(records, checkpointer)
          @logger.debug("Processing batch of " + records.size().to_s + " records")
          records.each do |record|
            @queue.push(record)
          end
          #checkpoint once all of the records have been consumed
          checkpointer.checkpoint()
        end

        def shutdown(checkpointer, reason)
          case reason
          when ShutdownReason::TERMINATE
            checkpointer.checkpoint()
          when ShutdownReason::ZOMBIE
          else
            raise RuntimeError, "Invalid shutdown reason."
          end
          unless @shard_id.nil?
            @logger.info("shutting down record processor with shardId: " + @shard_id + " with reason " + reason.to_s)
          end
        end
      end
    end
  end
end
