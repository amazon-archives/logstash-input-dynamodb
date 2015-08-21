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
require 'java'
require 'json'
require 'bigdecimal'
require 'activesupport/json_encoder'
require 'base64'

require "logstash-input-dynamodb_jars"
java_import "com.fasterxml.jackson.databind.ObjectMapper"
java_import "com.amazonaws.services.dynamodbv2.model.AttributeValue"
java_import "com.amazonaws.dynamodb.bootstrap.AttributeValueMixIn"

module Logstash
  module Inputs
    module DynamoDB
      class DynamoDBLogParser

        MAX_NUMBER_OF_BYTES_FOR_NUMBER = 21;

        def initialize(view_type, log_format, key_schema, region)
          @view_type = view_type
          @log_format = log_format
          @mapper ||= ObjectMapper.new()
          @mapper.setSerializationInclusion(JsonInclude::Include::NON_NULL)
          @mapper.addMixInAnnotations(AttributeValue, AttributeValueMixIn);
          @key_schema = key_schema
          ActiveSupport.encode_big_decimal_as_string = false
          @hash_template = Hash.new
          @hash_template["eventID"] = "0"
          @hash_template["eventName"] = "INSERT"
          @hash_template["eventVersion"] = "1.0"
          @hash_template["eventSource"] = "aws:dynamodb"
          @hash_template["awsRegion"] = region
        end

        public
        def parse_scan(log, new_image_size)
          data_hash = JSON.parse(@mapper.writeValueAsString(log))

          @hash_template["dynamodb"] = Hash.new
          @hash_template["dynamodb"]["keys"] = Hash.new
          size_bytes = calculate_key_size_in_bytes(log)
          @key_schema.each { |x|
            @hash_template["dynamodb"]["keys"][x] = data_hash[x]
          }
          unless @view_type == "keys_only"
            size_bytes += new_image_size
            @hash_template["dynamodb"]["newImage"] = data_hash
          end
          @hash_template["dynamodb"]["sequenceNumber"] = "0"
          @hash_template["dynamodb"]["sizeBytes"] = size_bytes
          @hash_template["dynamodb"]["streamViewType"] = @view_type.upcase

          return parse_view_type(@hash_template)
        end

        public
        def parse_stream(log)
          return parse_view_type(JSON.parse(@mapper.writeValueAsString(log))["internalObject"])
        end

        private
        def calculate_key_size_in_bytes(record)
          key_size = 0
          @key_schema.each { |x|
            key_size += x.length
            value = record.get(x)
            if !(value.getB().nil?)
              b = value.getB();
              key_size += Base64.decode64(b).length
            elsif !(value.getS().nil?)
              s = value.getS();
              key_size += s.length;
            elsif !(value.getN().nil?)
              key_size += MAX_NUMBER_OF_BYTES_FOR_NUMBER;
            end
          }
          return key_size
        end

        private
        def parse_view_type(hash)
          if @log_format == LogStash::Inputs::DynamoDB::LF_PLAIN
            return hash.to_json
          end
          case @view_type
          when LogStash::Inputs::DynamoDB::VT_KEYS_ONLY
            return parse_format(hash["dynamodb"]["keys"])
          when LogStash::Inputs::DynamoDB::VT_OLD_IMAGE
            return parse_format(hash["dynamodb"]["oldImage"])
          when LogStash::Inputs::DynamoDB::VT_NEW_IMAGE
            return parse_format(hash["dynamodb"]["newImage"]) #check new and old, dynamodb.
          end
        end

        private
        def parse_format(hash)
          if @log_format == LogStash::Inputs::DynamoDB::LF_DYNAMODB
            return hash.to_json
          else
            return dynamodb_to_json(hash)
          end
        end

        private
        def dynamodb_to_json(hash)
          return formatAttributeValueMap(hash).to_json
        end

        private
        def formatAttributeValueMap(hash)
          keys_to_delete = []
          hash.each do |k, v|
            dynamodb_key = v.keys.first
            dynamodb_value = v.values.first
            if @log_format == LogStash::Inputs::DynamoDB::LF_JSON_NO_BIN and (dynamodb_key == "BS" or dynamodb_key == "B")
              keys_to_delete.push(k) # remove binary values and binary sets
              next
            end
            hash[k] = formatAttributeValue(v.keys.first, v.values.first)
          end
          keys_to_delete.each {|key| hash.delete(key)}
          return hash
        end

        private
        def formatAttributeValue(key, value)
          case key
          when "M"
            formatAttributeValueMap(value)
          when "L"
            value.map! do |v|
              v = formatAttributeValue(v.keys.first, v.values.first)
            end
          when "NS","SS","BS"
            value.map! do |v|
              v = formatAttributeValue(key[0], v)
            end
          when "N"
            BigDecimal.new(value)
          when "NULL"
            nil
          else
            value
          end
        end

      end
    end
  end
end
