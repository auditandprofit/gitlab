# frozen_string_literal: true

module Security
  class AnalyzerNamespaceStatusPolicy < BasePolicy
    delegate { @subject.group }

    rule { can?(:developer_access) }.policy do
      enable :read_security_inventory
    end

    rule { can?(:admin_vulnerability) }.policy do
      enable :read_security_inventory
    end
  end
end
