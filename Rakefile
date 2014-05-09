file "lib/ibis/parser.rb" => "lib/ibis/parser.y" do
  chdir("lib/ibis") do
    sh "racc -o parser.rb parser.y"
  end
end

task :make => "lib/ibis/parser.rb"

task :run => :make do
  sh "./bin/ibis"
end
  
task :test => :make do
  sh "rspec"
end

task :default => :test
