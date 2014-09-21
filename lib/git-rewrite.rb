require 'rugged'
require 'date'

class GitRewrite
  attr_reader :repo

  class << self
    def next_commit_time(parent_time, time)
      str = parent_time.to_date.next_day.to_s + time.to_s[10..-1]
      DateTime.strptime(str, '%F %T %z').to_time
    end

    def default_start_time(commit)
      next_commit_time(commit.parents[0].author[:time], commit.author[:time])
    end
  end

  def initialize(repo_path)
    @repo = Rugged::Repository.new(repo_path)
  end

  def create_branch!(name, sha)
    @repo.branches.delete(name) if repo.branches.exists?(name)
    @repo.branches.create(name, sha)
  end

  def update_branch(name, sha)
    @repo.references.update("refs/heads/#{name}", sha)
  end

  def refresh_time(commit, new_time, parents = nil)
    commit = @repo.lookup(commit) if commit.is_a? String
    author = commit.author.dup
    committer = commit.committer.dup
    author[:time] = committer[:time] = new_time
    Rugged::Commit.create(@repo,
        :author => author,
        :message => commit.message,
        :committer => committer,
        :parents => parents || commit.parents.map(&:oid),
        :tree => commit.tree
    )
  end

  def commits(first_sha, last_sha)
    commits = []
    last_commit = @repo.lookup(last_sha)
    loop do
      commits.push last_commit
      break if last_commit.oid == first_sha
      fail 'nonsupport merge commit' if last_commit.parents.size > 1
      last_commit = last_commit.parents[0]
    end
    commits.reverse
  end
end

# 重写提交时间为每天一次提交
def rewrite_commit_time_to_every_day(repo_path, first_sha, last_sha)
  new_br = "_rewrite_#{last_sha[0..10]}"
  writer = GitRewrite.new(repo_path)
  commits = writer.commits(first_sha, last_sha)

  fail 'nonsupport merge commit' if commits[0].parents.size > 1

  writer.create_branch!(new_br, commits[0].parents[0].oid)

  first_parents = commits[0].parents.map(&:oid)
  first_time = GitRewrite.default_start_time(commits[0])

  last_sha, _ = commits.reduce([first_parents, first_time]) do |(parents, commit_time), commit|
    commit_time = GitRewrite.next_commit_time(commit_time, commit.author[:time])
    sha = writer.refresh_time(commit, commit_time, parents)
    [[sha], commit_time]
  end
  writer.update_branch(new_br, last_sha[0])
end

