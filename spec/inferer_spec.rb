require_relative 'spec_helper'

module Ibis
  describe Inferer do
    before do
      inferer = Inferer.new
      @infer = ->(src){
        expr = Parser.new.parse(src)

        variants = Env.new(:Global)
        env = Env.default
        type = Inferer.infer(env[:typeCtxt], env[:typeEnv], variants, expr)
        type.str
      }
    end

    it "constants" do
      expect(@infer["123"]).to eq("int")
      expect(@infer["true"]).to eq("bool")
      expect(@infer["false"]).to eq("bool")
    end
  end
end
