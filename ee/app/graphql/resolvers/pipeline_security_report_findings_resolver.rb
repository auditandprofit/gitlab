# frozen_string_literal: true

module Resolvers
  class PipelineSecurityReportFindingsResolver < BaseResolver
    type ::Types::PipelineSecurityReportFindingType, null: true

    alias_method :pipeline, :object

    argument :report_type, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by report type.'

    argument :severity, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by severity.'

    argument :scanner, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerability findings by Scanner.externalId.'

    argument :state, [Types::VulnerabilityStateEnum],
      required: false,
      description: 'Filter vulnerability findings by state.'

    argument :sort, Types::Security::PipelineSecurityReportFindingSortEnum,
      required: false,
      default_value: 'severity_desc',
      description: 'List vulnerability findings by sort order.'

    def resolve(**args)
      params = args.merge(limit: limit(args))

      ::Security::FindingsFinder.new(pipeline, params: params)
        .execute
        .tap { |findings| findings.each(&:remediations) } # initiates Batchloader
        .then { |findings| offset_pagination(findings) }
    end

    def preloads
      {
        severity: { vulnerability: :severity_overrides }
      }
    end

    private

    def limit(args)
      first = args[:first]
      last = args[:last]
      after = decode(args[:after])
      before = decode(args[:before])

      validate_pagination_args!(first: first, last: last, after: after, before: before)

      page_size = first || last || context.schema.default_max_page_size

      if after
        after + page_size
      elsif before
        before - 1
      else
        page_size
      end
    end

    def validate_pagination_args!(first:, last:, after:, before:)
      if first && last
        raise(Gitlab::Graphql::Errors::ArgumentError, "Can only provide either `first` or `last`, not both")
      end

      if after && before
        raise(Gitlab::Graphql::Errors::ArgumentError, "Can only provide either `first` or `last`, not both")
      end

      if first && before
        raise(
          Gitlab::Graphql::Errors::ArgumentError,
          "Behaviour of `first` and `before` in combination is undefined. " \
          "Use either `first` + `after` or `last` + `before`."
        )
      end

      return unless last && after

      raise(
        Gitlab::Graphql::Errors::ArgumentError,
        "Behaviour of `last` and `after` in combination is undefined. " \
        "Use either `first` + `after` or `last` + `before`."
      )
    end

    # The :before and :after cursor arguments when used with keyset
    # pagination are JSON structures Base64 encoded.
    #
    # When using offset pagination they are just an integer representing
    # the offset of the desired page.  The framework still encodes them
    # with Base64 though, so we need to decode them here to get an int.
    def decode(value)
      GraphQL::Schema::Base64Encoder.decode(value).to_i if value
    end
  end
end
