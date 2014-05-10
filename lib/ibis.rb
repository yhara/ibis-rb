Dir.glob("#{__dir__}/ibis/*.rb").each do |path|
  require path
end

require 'pp'
require 'pattern-match'

module Ibis
  class Inferer
    def self.infer(*args)
      return polyInfer(*args)
    end

    def self.polyInfer(*args)
      inferredType = infer_(*args)
      return createPolyType(inferredType)
    end

    def self.infer_(ctxt, env, variants, expr)
      match(expr){
        with(_[:Const, :unit]) { Type::UNIT } 
        with(_[:Const, Integer]) { Type::INT } 
        with(_[:Const, String]) { Type::STRING } 
        with(_[:Const, Or(true, false)]) { Type::BOOL } 

        with(_[:Var, varName]) {
          typeSchema = ctxt.find(varName)
          raise "undefined variable: #{varName}" unless typeSchema

          createAlphaEquivalent(typeSchema).bodyType
        }

        with(_[:Abs, _[:Var, varName], _[:Body, bodyExpr]]) {
          paramType = Type::Var.new(nil)

          newCtxt = Env.createLocal({}, ctxt)
          newCtxt.add(varName, Type::TypeSchema.new([], paramType))

          retType = infer_(newCtxt, env, variants, bodyExpr)
          Type::Fun.new(paramType, retType)
        }

        with(_[:App, funExpr, argExpr]) {
          funType = infer_(ctxt, env, variants, funExpr)
          argType = infer_(ctxt, env, variants, argExpr)

          retType = Type::Var.new(nil)
          unify(funType, Type::Fun.new(argType, retType))

          retType
        }

        with(_[:Let])
        with(_[:LetRec])
        with(_[:LetTuple])
        with(_[:If])
        with(_[:Tuple])
        with(_[:Seq])
        with(_[:VariantDef])
        with(_[:Case])

        with(_) { raise "no match: #{expr.inspect}" }
      }
    end

    def self.unify(type1, type2)
      return if type1.equal?(type2)
      match([type1, type2]) do
        with(_[var1 & Type::Var, var2 & Type::Var]) {
          if var1.value
            unify(var1.value, var2)
          elsif var2.value
            unify(var1, var2.value)
          else
            var1.value = var2
          end
        }
        with(_[var & Type::Var, other]) {
          if var.value
            unify(var.value, other)
          else
            if other.occur?(var)
              raise "unification error 2: #{type1.str} and #{type2.str}"
            end
            var.value = other
          end
        }
        with(_[other, var & Type::Var]) {
          unify(var, other)
        }
        with(_[fun1 & Type::Fun, fun2 & Type::Fun]) {
          unify(fun1.paramType, fun2.paramType)
          unify(fun1.retType, fun2.retType)
        }
        with(_[Type::Tuple, Type::Tuple]) { TODO }

        with(_) {
          raise "unification error 1: #{type1.str}(#{type1.class}) and #{type2.str}(#{type2.class})"
        }
      end
    end

    def self.createAlphaEquivalent(typeSchema)
      map = typeSchema.typeVars.map{|typeVar|
        freshVar = Type::Var.new(nil)
        [typeVar, freshVar]
      }.to_h
      newTypeVars = map.values
      newBodyType = typeSchema.bodyType.subst(map)
      return Type::TypeSchema.new(newTypeVars, newBodyType)
    end

    def self.createPolyType(type)
      freeVars = []
      unwrappedType = type.unwrapVar(freeVars)
      return Type::TypeSchema.new(freeVars, unwrappedType)
    end
  end

  class Eva

  end

  class Type
    def subst(map)
      self
    end

    def occur?(typeVar)
      false
    end

    # Unwrap Var 
    # Modifies freeVars
    def unwrapVar(freeVars)
      self
    end

    def str
      self.class.name.split(/::/).last.downcase
    end

    class Int < Type; end
    INT = Int.new
    class Bool < Type; end
    BOOL = Bool.new
    class Unit < Type; end
    UNIT = Unit.new
    class String < Type; end
    STRING = String.new

    class Fun < Type
      def initialize(paramType, retType)
        @paramType, @retType = paramType, retType
      end
      attr_reader :paramType, :retType

      def subst(map)
        Fun.new(@paramType.subst(map),
                @retType.subst(map))
      end

      def occur?(typeVar)
        @paramType.occur?(typeVar) || @retType.occur?(typeVar)
      end

      def unwrapVar(freeVars)
        Fun.new(@paramType.unwrapVar(freeVars),
                @retType.unwrapVar(freeVars))
      end

      def str
        "(#{@paramType.str} -> #{@retType.str})"
      end
    end

    # Type variable
    # Represents an unknown type when @value is nil.
    class Var < Type
      @@currentId = 0
      def initialize(value)
        @value = value
        @id = @@currentId
        @@currentId += 1
      end
      attr_accessor :value

      def subst(map)
        if (found = map[self])
          found
        elsif @value
          @value.subst(map)
        else
          self
        end
      end

      def occur?(typeVar)
        if typeVar.equal?(self)
          true
        elsif @value
          @value.occur?(typeVar)
        else
          false
        end
      end

      def unwrapVar(freeVars)
        if @value
          return @value.unwrapVar(freeVars)
        else
          return self if freeVars.include?(self)
          freeVars.push(self)
          return self
        end
      end

      def str
        "<#{@id}#{':' + @value.str if @value}>"
      end
    end

    class Tuple < Type
      def initialize(typeArray)
        @typeArray = typeArray
      end

      def collect(&block)
        Tuple.new(@typeArray.map(&block))
      end
      
      def subst(map)
        collect{|x| subst(x, map)}
      end

      def occur?(typeVar)
        @typeArray.any?{|x| x.occur?(typeVar)}
      end

      def unwrapVar(freeVars)
        collect{|x| x.unwrapVar(freeVars)}
      end

      def str
        "(#{@typeArray.map(&:str).join(' * ')})"
      end
    end

    class Variant < Type
      def initialize(typeName, typeCtors)
        @typeName, @typeCtors = typeName, typeCtors 
      end
      attr_reader :typeName, :typeCtors

      def str
        @typeName
      end
    end

    class TypeSchema
      def initialize(typeVars, bodyType)
        @typeVars, @bodyType = typeVars, bodyType
      end
      attr_reader :typeVars, :bodyType

      def str
        return @bodyType.str if @typeVars.length == 0

        # Supports up to 26 variables
        map = @typeVars.zip("a".."z").map{|item, c|
          [item, "'#{c}"]
        }.to_h
        
        x = @bodyType.subst(map)
        "TS<#{(x.is_a?(::String) ? x : x.str)}"
      end
    end
  end

  class Value
    class Unit < Value; end
    UNIT = Unit.new
    class True < Value; end
    TRUE_ = True.new
    class False < Value; end
    FALSE_ = True.new

    class Int < Value
      def initialize(v)
        @intValue = v
      end
      attr_reader :intValue
    end

    class String < Value
      def initialize(v)
        @stringValue = v
      end
      attr_reader :stringValue
    end

    class Closure < Value
      def initialize(env, varName, bodyExpr)
        @env, @varName, @bodyExpr = env, varName, bodyExpr
      end
    end

    class Subr < Value
      def initialize(&block)
        @subrValue = block
      end
      attr_reader :subrValue
    end

    class Tuple < Value
      def initialize(v)
        @valueArray = v
      end
      attr_reader :valueArray
    end

    class Variant < Value
      def initialize(ctorName, v)
        @ctorName, @value = ctorName, v
      end
    end
  end

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

  def self.main
    src = "fun x -> x * 2"
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
