require_relative 'spec_helper'

describe Ibis::Parser do
  before do
    parser = Ibis::Parser.new
    @parse = ->(src){
      parser.parse(src)
    }
  end

  context "Constant" do
    it "int" do
      expect(@parse["99"]).to eq([:Const, 99])
    end

    it "string" do
      expect(@parse['"abc"']).to eq([:Const, "abc"])
    end

    it "true" do
      expect(@parse["true"]).to eq([:Const, true])
    end

    it "false" do
      expect(@parse["false"]).to eq([:Const, false])
    end

    # tuple
    # unit
  end

  context "Expression" do
    it "~-" do
      expect(@parse["-9"]).to eq([:App, "(~-)", [:Const, 9]])
    end

    it "varref" do
      expect(@parse["foo"]).to eq([:Var, "foo"])
    end

    # let
    # let-tuple
    # let-rec
    # if
    # app
    # binary expr
    # var def
    # type expr
    # paren
    # case
    # multiple exprs
    # compexpr#
  end

end
