# frozen_string_literal: true

module Search
  module Zoekt
    class Cache
      extend NumbersHelper

      MAX_PAGES = 10
      EXPIRES_IN = 5.minutes

      attr_reader :current_user, :query, :project_ids, :per_page, :current_page, :max_per_page, :search_mode,
        :multi_match

      def self.humanize_expires_in
        parts = EXPIRES_IN.parts
        unit = parts.each_key.first
        number = parts.each_value.first
        "#{number_in_words(number)} #{unit}"
      end

      def initialize(
        query, current_user:, project_ids:, per_page:, page:, max_per_page:, search_mode:,
        multi_match: false)
        @query = query
        @current_user = current_user
        @project_ids = project_ids
        @per_page = per_page
        @current_page = page
        @max_per_page = max_per_page
        @search_mode = search_mode
        @multi_match = multi_match
      end

      def enabled?
        return false unless Gitlab::CurrentSettings.zoekt_cache_response?

        project_ids.is_a?(Array) && project_ids.present? && per_page <= max_per_page
      end

      def fetch
        return yield page_limit unless enabled?

        search_results, total_count, file_count = read_cache

        unless search_results
          search_results, total_count, file_count = yield page_limit

          update_cache!(search_results: search_results, total_count: total_count, file_count: file_count)
        end

        [search_results, total_count, file_count]
      end

      def cache_key(page: current_page)
        user_id = current_user&.id || 0
        # We need to use {user_id} as part of the key for Redis Cluster support
        "cache:zoekt:{#{user_id}}/#{search_fingerprint}/#{per_page}/#{page}"
      end

      private

      def with_redis(&block)
        Gitlab::Redis::Cache.with(&block) # rubocop:disable CodeReuse/ActiveRecord -- this has nothing to do with AR
      end

      def page_limit
        return [current_page, MAX_PAGES].max if enabled?

        current_page
      end

      def search_fingerprint
        project_ids_key = project_ids.sort.hash.to_s
        multi_match_key = multi_match.present? ? multi_match.max_chunks_size : 'false'

        OpenSSL::Digest.hexdigest('SHA256',
          "#{query}-#{project_ids_key}-#{search_mode}-#{multi_match_key}")
      end

      def read_cache
        data = with_redis do |redis|
          redis.get(cache_key)
        end

        return unless data

        Marshal.load(data) # rubocop:disable Security/MarshalLoad -- We're loading data we saved below (similar to Rails.cache)
      end

      def update_cache!(search_results:, total_count:, file_count:)
        return unless search_results && total_count > 0 && file_count > 0

        with_redis do |redis|
          redis.multi do |pipeline|
            (0..MAX_PAGES).each do |page_idx|
              result = search_results[page_idx]
              next unless result

              cached_result = [{ page_idx => result }, total_count, file_count]

              key = cache_key(page: page_idx + 1)
              pipeline.set(key, Marshal.dump(cached_result), ex: EXPIRES_IN)
            end
          end
        end
      end
    end
  end
end
