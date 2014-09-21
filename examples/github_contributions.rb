require 'rugged'
require 'date'

def create_simple_tree(repo)
  oid = repo.write("This is a blob.", :blob)
  entry = {:type => :blob,
           :name => "README.txt",
           :oid  => oid,
           :filemode => 33188}
  builder = Rugged::Tree::Builder.new
  builder << entry
  builder.write(repo)
end

def create_github_contributions_repo(repo_path, name, email)
  fail 'repo exists' if Dir.exist?(repo_path)
  repo = Rugged::Repository.init_at(repo_path)
  date = DateTime.now.prev_year
  author = {
    :time => date.to_time,
    :name => name,
    :email => email
  }
  parents = []
  tree = create_simple_tree(repo)
  365.times.each do
    sha = Rugged::Commit.create(repo,
        :author => author,
        :message => 'foo',
        :committer => author,
        :parents => parents,
        :tree => tree
    )
    parents = [sha]
    date = date.next_day
    author[:time] = date.to_time
  end
  repo.branches.create('master', parents[0])
end

create_github_contributions_repo('/tmp/test-git-rewrite', 'john1king', 'uifantasy@gmail.com')
