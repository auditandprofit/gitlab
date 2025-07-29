# frozen_string_literal: true

module Gitlab
  module Llm
    module AiGateway
      module Completions
        class ReviewMergeRequest
          class ResponseBodyParser
            include ::Gitlab::Utils::StrongMemoize

            class Comment
              ATTRIBUTES = %w[old_line new_line file].freeze

              attr_reader :attributes, :content, :from

              def initialize(attrs, content, from)
                @attributes = attrs
                @content = content
                @from = from
              end

              ATTRIBUTES.each do |attr|
                define_method(attr) do
                  attr == 'file' ? attributes[attr] : Integer(attributes[attr], exception: false)
                end
              end

              def valid?
                return false if content.blank?
                return false if old_line.blank? && new_line.blank?

                # Always require the file attribute since we now include it in all cases,
                # even for single-file reviews
                return false if file.blank?

                true
              end
            end

            attr_reader :response

            def initialize(response)
              @response = response
            end

            def comments
              return [] if response.blank?

              review_content = response.match(review_wrapper_regex)

              return [] if review_content.blank?

              review_content[1].scan(comment_wrapper_regex).filter_map do |attrs, body|
                parsed_body = parsed_content(body)
                comment = Comment.new(parsed_attrs(attrs), parsed_body[:body], parsed_body[:from])
                comment if comment.valid?
              end
            end
            strong_memoize_attr :comments

            def review_description
              review_description_matches = response.match(review_description_regex)

              return unless review_description_matches && review_description_matches[1].present?

              review_description_matches[1].strip
            end
            strong_memoize_attr :review_description

            private

            def review_description_regex
              %r{<review>\s*(.*?)(?=\s*<comment|\s*</review>)}m
            end

            def review_wrapper_regex
              %r{^<review>(.+)</review>$}m
            end

            def comment_wrapper_regex
              %r{^<comment (.+?)>(?:\n?)(.+?)</comment>$}m
            end

            def comment_attr_regex
              %r{([^\s]*?)="(.*?)"}
            end

            def parsed_attrs(attrs)
              Hash[attrs.scan(comment_attr_regex)]
            end

            def parsed_content(body)
              ::Gitlab::Llm::Utils::CodeSuggestionFormatter.parse(body)
            end
          end
        end
      end
    end
  end
end
