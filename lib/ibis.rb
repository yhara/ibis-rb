Dir.glob("#{__dir__}/ibis/*.rb").each do |path|
  require path
end

require 'pp'
require 'pattern-match'

module Ibis
  class Eva

  end

  def self.main
    src = "fun x -> x"
    puts "-- src --"
    puts src
    puts

    expr = Parser.new.parse(src)

    puts "-- expr --"
    pp expr
    puts

    variants = Env.new(:Global)
    env = Env.default
    type = Inferer.infer(env[:typeCtxt], env[:typeEnv], variants, expr)

    puts "-- inferred type --"
    puts type.str
    puts

    #value = Eva.eval(env[:valueEnv], expr)
    #puts "-- evaluated value --"
    #pp value
  end
end
