file "lib/ibis/parser.rb" => "lib/ibis/parser.y" do
  chdir("lib/ibis") do
    sh "racc -g -o parser.rb parser.y"
  end
end

task :make => "lib/ibis/parser.rb"

task :run => :make do
  sh "./bin/ibis"
end

task :debug => :make do
  ENV['DEBUG'] = "1"
  sh "./bin/ibis"
end
  
task :test => :make do
  sh "rspec"
end

task :looptest do
  loop{ system "rake test"; $stdin.gets }
end

task :default => :test
