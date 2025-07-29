# frozen_string_literal: true

module RemoteDevelopment
  module DevfileOperations
    class YamlParser
      include Messages

      # @param [Hash] context
      # @return [Gitlab::Fp::Result]
      def self.parse(context)
        context => {
          devfile_yaml: String => devfile_yaml
        }

        begin
          # load YAML, convert YAML to JSON and load it again to remove YAML vulnerabilities
          devfile_to_json_and_back_to_yaml = YAML.safe_load(YAML.safe_load(devfile_yaml).to_json)
          # symbolize keys for domain logic processing of devfile (to_h is to avoid nil dereference error in RubyMine)
          devfile = devfile_to_json_and_back_to_yaml.to_h.deep_symbolize_keys
        rescue RuntimeError, JSON::GeneratorError => e
          return Gitlab::Fp::Result.err(DevfileYamlParseFailed.new(
            details: "Devfile YAML could not be parsed: #{e.message}",
            context: context
          ))
        end

        Gitlab::Fp::Result.ok(context.merge({
          devfile: devfile
        }))
      end
    end
  end
end
