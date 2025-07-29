# frozen_string_literal: true

module VirtualRegistries
  class CheckUpstreamsService < ::VirtualRegistries::BaseService
    MAX_CONCURRENCY = 3

    def initialize(registry:, params: {})
      super

      @hydra = Typhoeus::Hydra.new(max_concurrency: MAX_CONCURRENCY)
      @results = Array.new(registry.upstreams.size)
      @successful_upstream = nil
    end

    def execute
      return BASE_ERRORS[:path_not_present] unless path.present?

      configure_hydra
      @hydra.run

      return BASE_ERRORS[:file_not_found_on_upstreams] unless @successful_upstream

      ServiceResponse.success(
        payload: { upstream: @successful_upstream }
      )
    end

    private

    def configure_hydra
      registry.upstreams.each_with_index do |upstream, index|
        request = Typhoeus::Request.new(
          upstream.url_for(path),
          headers: upstream.headers,
          method: :head,
          followlocation: true,
          timeout: NETWORK_TIMEOUT
        )

        request.on_complete do |response|
          # given that each url is checked in parallel, the order which we receive the
          # results are not guaranteed. Thus, we need to first record the result for
          # this index and then check the results array to know if we are in a
          # success state or not. If that's the case, we need to get which index
          # contains the first true value.
          @results[index] = response.success?
          index = first_successful_index

          if index
            @hydra.abort
            @successful_upstream = registry.upstreams[index]
          end
        end

        @hydra.queue(request)
      end
    end

    def path
      params[:path]
    end

    # Returns the index of the first true value that is preceded only by false values.
    # Returns nil otherwise.
    #
    # Examples:
    #   [false, false, true, true]  => 2   (first true at index 2, all preceding are false)
    #   [false, nil, true, false]   => nil (nil before true, not all preceding are false)
    #   [true, false, nil]          => 0   (first true at index 0, no preceding values)
    #   [false, false, false]       => nil (no true values)
    def first_successful_index
      @results.find_index.with_index { |e, i| e && @results[0...i].all?(false) }
    end
  end
end
