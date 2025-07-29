# frozen_string_literal: true

namespace :gitlab do
  namespace :zoekt do
    desc 'GitLab | Zoekt | List information about Exact Code Search integration'
    task :info, [:watch_interval, :extended] => :environment do |t, args|
      Search::RakeTask::Zoekt.info(
        name: t.name,
        extended: args[:extended],
        watch_interval: args[:watch_interval]
      )
    end

    desc "GitLab | Zoekt Indexer | Install or upgrade gitlab-zoekt"
    task :install, [:dir, :repo] => :gitlab_environment do |_, args|
      unless args.dir.present?
        abort %(Please specify the directory where you want to install the indexer
Usage: rake "gitlab:zoekt:install:[/installation/dir,repo]")
      end

      args.with_defaults(repo: 'https://gitlab.com/gitlab-org/gitlab-zoekt-indexer.git')
      version = Rails.root.join('GITLAB_ZOEKT_VERSION').read.chomp
      make = Gitlab::Utils.which('gmake') || Gitlab::Utils.which('make')

      abort "Couldn't find a 'make' binary" unless make

      checkout_or_clone_version(version: version, repo: args.repo, target_dir: args.dir, clone_opts: %w[--depth 1])

      Dir.chdir(args.dir) { run_command!([make, 'build-unified']) }
    end
  end
end
