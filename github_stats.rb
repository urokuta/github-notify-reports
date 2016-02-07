require 'octokit'
require 'parallel'
class GithubStats
  attr_accessor :client
  def initialize(access_token:)
    @access_token = access_token
    @client = GithubStats.get_client(access_token: access_token)
    @filter_repo_names = []
  end

  def set_filter_repo_names(names)
    @filter_repo_names = names
  end

  def target_repo_names
    client.repos.map{|r| r[:full_name]}.select{|name| @filter_repo_names.find{|fname| name.include?(fname)} == nil }
  end

  def target_repo_branches
    Parallel.map(target_repo_names, in_threads: 3) do |name|
      _client = GithubStats.get_client(access_token: @access_token)
      _branches = _client.branches(name)
      branches = _branches.map{|b| b[:name]}.select{|n| n != "production"}
      {name: name, branches: branches}
    end
  end

  def apply_date_options_for_commits(_client:, name:, date_options:, branch: 'master')
    from = date_options[:from]
    to = date_options[:to]
    date = date_options[:date]
    if from && to
      _client.commits_between(name, from, to, branch)
    elsif date
      _client.commits_on(name, date, branch)
    else
      raise "wrong date_options: #{date_options.inspect}"
    end
  end

  def commits(**date_options)
    repo_branches = target_repo_branches
    all_commits = []
    Parallel.each(repo_branches, in_threads: 10) do |name_with_branches|
      name = name_with_branches[:name]
      branches = name_with_branches[:branches]
      _client = GithubStats.get_client(access_token: @access_token)
      Parallel.each(branches, in_threads: 3) do |branch|
        commits = apply_date_options_for_commits(_client: _client, name: name, date_options: date_options, branch: branch)
        all_commits << commits
        puts "  branch completed: #{branch}"
      end
      puts "repo completed: #{name}"
    end
    all_commits.flatten
  end

  def name_mapped_commits(**date_options)
    commits = commits(date_options)
    _name_mapped_commits(commits: commits)
  end

  def _name_mapped_commits(commits:)
    result = commits.group_by{|c| c[:commit][:author][:name]}
    result.map do |k,v|
      uniqued = v.uniq{|c| c[:commit][:tree][:sha]}
      sorted = uniqued.sort_by{|e| e[:commit][:author][:date]}.reverse
      {name: k, commits: sorted}
    end
  end

  class << self
    def get_client(access_token:)
      client = Octokit::Client.new(access_token: access_token)
    end

    def formatted_commit(commit)
      c = commit[:commit]
      a = c[:author]
      name = a[:name][0..8]
      date = a[:date].to_date.to_s
      message = c[:message]
      "#{date} #{name} - #{message}"
    end
  end
end
