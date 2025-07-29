# frozen_string_literal: true

module Search
  module Elastic
    module References
      class Legacy < Reference
        def self.serialize(record)
          Gitlab::Elastic::DocumentReference.serialize_record(record)
        end

        def self.instantiate_from_array(array)
          instantiate(Gitlab::Elastic::DocumentReference.serialize_array(array))
        end

        override :instantiate
        def self.instantiate(string)
          Gitlab::Elastic::DocumentReference.deserialize(string)
        end

        def self.init(*args)
          Gitlab::Elastic::DocumentReference.new(*args)
        end
      end
    end
  end
end
