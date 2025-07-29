# frozen_string_literal: true

namespace :gitlab do
  namespace :duo do
    desc 'GitLab | Duo | Enable GitLab Duo features'
    task :setup, [:add_on] => :environment do |_, args|
      Gitlab::Duo::Developments::Setup.new(args).execute
    end

    desc 'GitLab | Duo | Enable GitLab Duo feature flags'
    task enable_feature_flags: :gitlab_environment do
      Gitlab::Duo::Developments::FeatureFlagEnabler.execute
    end

    desc 'GitLab | Duo | Seed development self-hosted models'
    task seed_self_hosted_models: :gitlab_environment do
      Gitlab::Duo::Developments::DevSelfHostedModelsManager.seed_models
    end

    desc 'GitLab | Duo | List self-hosted models'
    task list_self_hosted_models: :gitlab_environment do
      Gitlab::Duo::Developments::DevSelfHostedModelsManager.list_models
    end

    desc 'GitLab | Duo | Create evaluation-ready group'
    task :setup_evaluation, [:root_group_path] => :environment do |_, args|
      Gitlab::Duo::Developments::SetupGroupsForModelEvaluation.new(args).execute
    end

    desc 'GitLab | Duo | Verify self-hosted Duo setup'
    task :verify_self_hosted_setup, [:username] => :gitlab_environment do |_, args|
      Gitlab::Duo::Administration::VerifySelfHostedSetup.new(args[:username]).execute
    end
  end
end
