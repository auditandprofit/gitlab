# frozen_string_literal: true

module Search
  module RakeTask
    module Zoekt
      class << self
        def info(name:, extended: nil, watch_interval: nil)
          extended_mode = if extended.present?
                            Gitlab::Utils.to_boolean(extended)
                          else
                            !watch_interval
                          end

          options = { extended_mode: extended_mode }

          run_with_interval(name:, watch_interval:) do
            task_executor_service(options: options).execute(:info)
          end
        end

        private

        def task_executor_service(options: {})
          Search::Zoekt::RakeTaskExecutorService.new(logger: stdout_logger, options: options)
        end

        def run_with_interval(name:, watch_interval:)
          interval = watch_interval.to_f
          return yield if interval <= 0

          loop do
            clear_screen

            stdout_logger.info "Every #{interval}s: #{name} (Updated: #{Time.now.utc.iso8601})"
            yield
            sleep interval
          end
        rescue Interrupt
          puts "\nInterrupted. Exiting gracefully..."
        end

        def clear_screen
          system('clear') || system('cls') # Clear screen (Linux/macOS & Windows)
        end

        def stdout_logger
          @stdout_logger ||= Logger.new($stdout).tap do |l|
            l.formatter = ->(_severity, _datetime, _progname, msg) { "#{msg}\n" }
          end
        end
      end
    end
  end
end
