module Ibis
  class Env
    def self.createGlobal
      new(:Global, {})
    end

    def self.createLocal(vars, outerEnv)
      new(:Local, vars, outerEnv)
    end

    def initialize(tag, vars={}, outerEnv=nil)
      @tag, @vars, @outerEnv = tag, vars, outerEnv
    end

    def find(varName)
      if (value = @vars[varName])
        value
      else
        if @tag == :Global
          nil
        else
          @outerEnv.find(varName)
        end
      end
    end

    def add(varName, value)
      @vars[varName] = value
    end

    def self.default
      typeEnv = Env.new(:Global)
      typeCtxt = Env.new(:Global)
      valueEnv = Env.new(:Global)

      typeEnv.add("unit", Type::UNIT)
      typeEnv.add("int", Type::INT)
      typeEnv.add("bool", Type::BOOL)

      [
        ["(+)", :+],
        ["(-)", :-],
        ["(*)", :*],
        ["(/)", :/],
        ["(mod)", :%],
      ].each do |opName, opMethod|
        typeCtxt.add(opName, binOpType(Type::INT, Type::INT, Type::INT))
        valueEnv.add(opName, Value::Subr.new{|lhs|
          Value::Subr.new{|rhs|
            Value::Int.new(lhs.intValue.send(:opMethod, rhs.intValue))
          }
        })
      end

      typeVar = Type::Var.new(nil)
      typeCtxt.add("show", Type::TypeSchema.new(
        [typeVar], Type::Fun.new(typeVar, Type::STRING)
      ))
      valueEnv.add("show", Value::Subr.new{|x|
        Value::String.new(x.to_s)
      })

      typeVar = Type::Var.new(nil)
      typeCtxt.add("print", Type::TypeSchema.new(
        [typeVar], Type::Fun.new(typeVar, Type::STRING)
      ))
      valueEnv.add("print", Value::Subr.new{|x|
        print(x.inspect)
        x
      })
      
      {typeEnv: typeEnv,
       typeCtxt: typeCtxt,
       valueEnv: valueEnv}
    end

    def self.binOpType(lhs, rhs, ret)
      Type::TypeSchema.new(
        [], Type::Fun.new(lhs, Type::Fun.new(rhs, ret))
      )
    end
  end
end
