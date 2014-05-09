require_relative 'spec_helper'

describe Ibis::Parser do
  before do
    @parser = Ibis::Parser.new
  end

  context "Expression" do
    it "~-" do
      expect(@parser.parse("-9")).to eq([:App, "(~-)", [:Const, 9]])
    end

    it "varref" do
      expect(@parser.parse("foo")).to eq([:Var, "foo"])
    end
  end

  context "Literal" do
    it "int" do
      expect(@parser.parse("99")).to eq([:Const, 99])
    end

    it "string" do
      expect(@parser.parse('"abc"')).to eq([:Const, "abc"])
    end

    it "true" do
      expect(@parser.parse("true")).to eq([:Const, true])
    end

    it "false" do
      expect(@parser.parse("false")).to eq([:Const, false])
    end
  end
end
