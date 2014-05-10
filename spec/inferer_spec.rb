require_relative 'spec_helper'

module Ibis
  describe Inferer do
    before do
      inferer = Inferer.new
      variants = Env.new(:Global)
      @env = Env.default

      @infer = ->(src){
        expr = Parser.new.parse(src)
        type = Inferer.infer(@env[:typeCtxt], @env[:typeEnv], variants, expr)
        type.str
      }
    end

    context "constants" do
      it "int" do
        expect(@infer["123"]).to eq("int")
      end

      it "true" do
        expect(@infer["true"]).to eq("bool")
      end

      it "false" do
        expect(@infer["false"]).to eq("bool")
      end

      it "unit"
      #do
      #  expect(@infer["()"]).to eq("bool")
      #end

      it "string" do
        expect(@infer['"abc"']).to eq("string")
      end
    end

    context "variables" do
      it "var" do
        @env[:typeCtxt].add("answer", Type::TypeSchema.new([], Type::INT))
        expect(@infer["answer"]).to eq("int")
      end

      it "fun" do
        type = Type::Fun.new(Type::INT, Type::INT)
        @env[:typeCtxt].add("double", Type::TypeSchema.new([], type))
        expect(@infer["double"]).to eq("(int -> int)")
      end
    end

    context "abs" do
      it "fun" do
        expect(@infer["fun x -> x * 2"]).to eq("(int -> int)")
      end

      it "higher order" do
        expect(@infer["fun n -> fun m -> n + m"]).to eq("(int -> (int -> int))")
      end
    end

    #context "app"
    #context "let"
    #context "let-rec"
    #context "let-tuple"
    #context "polymorphic"
    #context "if"
    #context "tuple"
    #context "variant"
    #context "constructor"
    #context "case"
    #context "case in func"
    #context "recursive types"
    #context "type expr"
    #context "apply function n-times"
    #context "compound expr"
  end
end
