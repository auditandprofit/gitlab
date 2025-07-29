# frozen_string_literal: true

module Sbom
  module Exporters
    class JsonArrayService
      include WriteBlob

      class << self
        def combine_parts(part_files)
          Tempfile.open do |export_file|
            json_stream = Oj::StreamWriter.new(export_file, indent: 2)

            json_stream.push_array

            part_files.each { |part_file| write_part_to_stream(json_stream, part_file) }

            json_stream.pop_all

            if block_given?
              yield export_file
            else
              export_file.rewind
              export_file.read
            end
          end
        end

        private

        def write_part_to_stream(json_stream, file)
          file.open do |stream|
            stream.each_line do |line|
              json_stream.push_json(line.chomp.force_encoding(Encoding::UTF_8))
            end
          end
        end
      end

      def initialize(_export, sbom_occurrences)
        @sbom_occurrences = sbom_occurrences
      end

      attr_reader :sbom_occurrences

      def generate(&block)
        write_json_blob(data, &block)
      end

      def generate_part
        Tempfile.open do |file|
          each_occurrence do |data|
            file.puts(data.to_json)
          end

          if block_given?
            yield file
          else
            file.rewind
            file.read
          end
        end
      end

      private

      def data
        [].tap do |list|
          each_occurrence do |data|
            list.push(data)
          end
        end
      end

      def each_occurrence
        iterator.each_batch do |batch|
          occurrences = Sbom::Occurrence.id_in(batch.map(&:id)).with_version.with_project_namespace

          occurrences.each do |occurrence|
            data = {
              name: occurrence.component_name,
              packager: occurrence.package_manager,
              version: occurrence.version,
              licenses: occurrence.licenses,
              location: occurrence.location
            }

            yield data
          end
        end
      end

      def iterator
        scope = sbom_occurrences.select(:id, :traversal_ids).order_traversal_ids_asc

        Gitlab::Pagination::Keyset::Iterator.new(
          scope: scope,
          use_union_optimization: false
        )
      end
    end
  end
end
