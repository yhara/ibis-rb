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

  context "Operator" do
    it "~-" do
      expect(@parse["-9"]).to eq([:App, "(~-)", [:Const, 9]])
    end

    it "binary operator" do
      expect(@parse["1 + 2"]).to eq(
        [:App, [:App, "(+)", [:Const, 1]], [:Const, 2]])
      expect(@parse["1 - 2"]).to eq(
        [:App, [:App, "(-)", [:Const, 1]], [:Const, 2]])
      expect(@parse["1 * 2"]).to eq(
        [:App, [:App, "(*)", [:Const, 1]], [:Const, 2]])
      expect(@parse["1 / 2"]).to eq(
        [:App, [:App, "(/)", [:Const, 1]], [:Const, 2]])
      expect(@parse["1 mod 2"]).to eq(
        [:App, [:App, "(mod)", [:Const, 1]], [:Const, 2]])
    end
  end

  context "Expression" do
    it "varref" do
      expect(@parse["foo"]).to eq([:Var, "foo"])
    end

    it "abs" do
      expect(@parse["fun x -> x"]).to eq([:Abs, [:Var, "x"],
                                                [:Body, [:Var, "x"]]])
    end

    # let
    # let-tuple
    # let-rec
    # if
    # app
    # var def
    # type expr
    # paren
    # case
    # multiple exprs
    # compexpr#
  end

end
