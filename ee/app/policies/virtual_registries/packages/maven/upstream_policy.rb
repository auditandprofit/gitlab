# frozen_string_literal: true

module VirtualRegistries
  module Packages
    module Maven
      class UpstreamPolicy < ::BasePolicy
        delegate { ::VirtualRegistries::Packages::Policies::Group.new(@subject.group) }
      end
    end
  end
end
