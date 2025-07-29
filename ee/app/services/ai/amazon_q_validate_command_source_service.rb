# frozen_string_literal: true

module Ai
  class AmazonQValidateCommandSourceService
    UnsupportedCommandError = Class.new(StandardError)
    UnsupportedSourceError = Class.new(StandardError)

    def initialize(command:, source:)
      @command = command
      @source = source
    end

    def validate
      case source
      when Issue
        command_list = ::Ai::AmazonQ::Commands::ISSUE_SUBCOMMANDS
        message = "Unsupported issue command: #{command}"
        raise UnsupportedCommandError, message unless command_list.include?(command)
      when MergeRequest
        command_list = ::Ai::AmazonQ::Commands::MERGE_REQUEST_SUBCOMMANDS
        message = "Unsupported merge request command: #{command}"
        raise UnsupportedCommandError, message unless command_list.include?(command)

      else
        raise UnsupportedSourceError, "Unsupported source type: #{source.class}"
      end
    end

    private

    attr_reader :command, :source
  end
end
