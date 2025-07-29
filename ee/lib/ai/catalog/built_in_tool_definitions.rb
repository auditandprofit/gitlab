# frozen_string_literal: true

module Ai
  module Catalog
    module BuiltInToolDefinitions
      extend ActiveSupport::Concern

      ITEMS = [
        {
          id: 1,
          name: "gitlab_blob_search",
          title: "Gitlab Blob Search",
          description: "Search for blobs in the specified GitLab group or project. In GitLab, a \"blob\" " \
            "refers to a file's content in a specific version of the repository."
        },
        {
          id: 2,
          name: "ci_linter",
          title: "Ci Linter",
          description: "Validates a CI/CD YAML configuration against GitLab CI syntax rules in the context " \
            "of the project. This tool can be used when you have a project_id and the content " \
            "of the CI/CD YAML configuration and will return a JSON response indicating whether " \
            "the configuration is valid or not, along with any errors found."
        },
        {
          id: 3,
          name: "run_git_command",
          title: "Run Git Command",
          description: "Runs a git command in the repository working directory."
        },
        {
          id: 4,
          name: "gitlab_commit_search",
          title: "Gitlab Commit Search",
          description: "Search for commits in the specified GitLab project or group."
        },
        {
          id: 5,
          name: "create_epic",
          title: "Create Epic",
          description: "Create a new epic in a GitLab group."
        },
        {
          id: 6,
          name: "create_issue",
          title: "Create Issue",
          description: "Create a new issue in a GitLab project."
        },
        {
          id: 7,
          name: "create_issue_note",
          title: "Create Issue Note",
          description: "Create a new note (comment) on a GitLab issue."
        },
        {
          id: 8,
          name: "create_merge_request",
          title: "Create Merge Request",
          description: "Create a new merge request in the specified project."
        },
        {
          id: 9,
          name: "create_merge_request_note",
          title: "Create Merge Request Note",
          description: "Create a note (comment) on a merge request. You are NOT allowed to ever use a " \
            "GitLab quick action in a merge request note."
        },
        {
          id: 10,
          name: "edit_file",
          title: "Edit File",
          description: "Use this tool to edit an existing file."
        },
        {
          id: 11,
          name: "find_files",
          title: "Find Files",
          description: "Find files, recursively, with names matching a specific pattern in the repository."
        },
        {
          id: 12,
          name: "get_commit",
          title: "Get Commit",
          description: "Get a single commit from a GitLab project repository."
        },
        {
          id: 13,
          name: "get_commit_comments",
          title: "Get Commit Comments",
          description: "Get the comments on a specific commit in a GitLab project."
        },
        {
          id: 14,
          name: "get_commit_diff",
          title: "Get Commit Diff",
          description: "Get the diff of a specific commit in a GitLab project."
        },
        {
          id: 15,
          name: "get_epic",
          title: "Get Epic",
          description: "Get a single epic in a GitLab group"
        },
        {
          id: 16,
          name: "get_epic_note",
          title: "Get Epic Note",
          description: "Get a single note (comment) from a specific epic."
        },
        {
          id: 17,
          name: "get_issue",
          title: "Get Issue",
          description: "Get a single issue in a GitLab project."
        },
        {
          id: 18,
          name: "get_issue_note",
          title: "Get Issue Note",
          description: "Get a single note (comment) from a specific issue."
        },
        {
          id: 19,
          name: "get_job_logs",
          title: "Get Job Logs",
          description: "Get the trace for a job."
        },
        {
          id: 20,
          name: "get_merge_request",
          title: "Get Merge Request",
          description: "Fetch details about the merge request."
        },
        {
          id: 21,
          name: "get_pipeline_errors",
          title: "Get Pipeline Errors",
          description: "Get the logs for failed jobs in the latest pipeline in a merge request."
        },
        {
          id: 22,
          name: "get_project",
          title: "Get Project",
          description: "Fetch details about the project"
        },
        {
          id: 23,
          name: "get_repository_file",
          title: "Get Repository File",
          description: "Get the contents of a file from a remote repository."
        },
        {
          id: 24,
          name: "grep",
          title: "Grep",
          description: "Search for text patterns in files. This tool uses searches, recursively, through " \
            "all files in the given directory, respecting .gitignore rules."
        },
        {
          id: 25,
          name: "gitlab_group_project_search",
          title: "Gitlab Group Project Search",
          description: "Search for projects within a specified GitLab group."
        },
        {
          id: 26,
          name: "gitlab_issue_search",
          title: "Gitlab Issue Search",
          description: "Search for issues in the specified GitLab project or group."
        },
        {
          id: 27,
          name: "list_all_merge_request_notes",
          title: "List All Merge Request Notes",
          description: "List all notes (comments) on a merge request."
        },
        {
          id: 28,
          name: "list_commits",
          title: "List Commits",
          description: "List commits in a GitLab project repository."
        },
        {
          id: 29,
          name: "list_dir",
          title: "List Dir",
          description: "Lists files in the given directory relative to the root of the project."
        },
        {
          id: 30,
          name: "list_epic_notes",
          title: "List Epic Notes",
          description: "Get a list of all notes (comments) for a specific epic."
        },
        {
          id: 31,
          name: "list_epics",
          title: "List Epics",
          description: "Get all epics of the requested group and its subgroups."
        },
        {
          id: 32,
          name: "list_issue_notes",
          title: "List Issue Notes",
          description: "Get a list of all notes (comments) for a specific issue."
        },
        {
          id: 33,
          name: "list_issues",
          title: "List Issues",
          description: "List issues in a GitLab project."
        },
        {
          id: 34,
          name: "list_merge_request_diffs",
          title: "List Merge Request Diffs",
          description: "Fetch the diffs of the files changed in a merge request."
        },
        {
          id: 35,
          name: "gitlab_merge_request_search",
          title: "Gitlab Merge Request Search",
          description: "Search for merge requests in the specified GitLab project or group."
        },
        {
          id: 36,
          name: "gitlab_milestone_search",
          title: "Gitlab Milestone Search",
          description: "Search for milestones in the specified GitLab project or group."
        },
        {
          id: 37,
          name: "mkdir",
          title: "Mkdir",
          description: "Create a new directory using the mkdir command. The directory creation is " \
            "restricted to the current working directory tree."
        },
        {
          id: 38,
          name: "gitlab_note_search",
          title: "Gitlab Note Search",
          description: "Search for notes in the specified GitLab project."
        },
        {
          id: 39,
          name: "read_file",
          title: "Read File",
          description: "Read the contents of a file."
        },
        {
          id: 40,
          name: "run_command",
          title: "Run Command",
          description: "Run a bash command in the current working directory. Following bash commands are " \
            "not supported: git and will result in error.Pay extra attention to correctly " \
            "escape special characters like '`'"
        },
        {
          id: 41,
          name: "set_task_status",
          title: "Set Task Status",
          description: "Set the status of a single task in the plan"
        },
        {
          id: 42,
          name: "update_epic",
          title: "Update Epic",
          description: "Update an existing epic in a GitLab group."
        },
        {
          id: 43,
          name: "update_issue",
          title: "Update Issue",
          description: "Update an existing issue in a GitLab project."
        },
        {
          id: 44,
          name: "update_merge_request",
          title: "Update Merge Request",
          description: "Updates an existing merge request. You can change the target branch, title, or " \
            "even close the MR."
        },
        {
          id: 45,
          name: "gitlab__user_search",
          title: "Gitlab User Search",
          description: "Search for users in the specified GitLab project or group."
        },
        {
          id: 46,
          name: "gitlab_wiki_blob_search",
          title: "Gitlab Wiki Blob Search",
          description: "Search for wiki blobs in the specified GitLab project or group. In GitLab, a " \
            "\"blob\" refers to a file's content in a specific version of the repository."
        },
        {
          id: 47,
          name: "create_file_with_contents",
          title: "Create File With Contents",
          description: "Create and write the given contents to a file. Please specify the `file_path` " \
            "and the `contents` to write."
        }
      ].freeze
    end
  end
end
