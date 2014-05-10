Dir.glob("#{__dir__}/ibis/*.rb").each do |path|
  require path
end

require 'pp'
require 'pattern-match'

module Ibis
  class Inferer
    def self.infer(*args)
      infer_(*args)
      #polyInfer(*args)
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

        with(_[:Abs, [:Var, name], [:Body, body]]) { TODO }

        with(_[:App])
        with(_[:Let])
        with(_[:LetRec])
        with(_[:LetTuple])
        with(_[:If])
        with(_[:Tuple])
        with(_[:Seq])
        with(_[:VariantDef])
        with(_[:Case])

        with(_) { raise "no match" }
      }
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
  end

  class Eva

  end

  class Type
    def subst(map)
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

      def subst(map)
        Fun.new(@paramType.subst(map),
                @retType.subst(map))
      end

      def str
        "(#{@paramType.str} -> #{@retType.str})"
      end
    end

    class Var < Type
      @@currentId = 0
      def initialize(value)
        @value = value
        @id = @@currentId
        @@currentId += 1
      end

      def subst(map)
        if (found = map[self])
          found
        elsif @value
          @value.subst(map)
        else
          self
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

      def any?(&block)
        @typeArray.any?(&block)
      end
      
      def subst(map)
        collect{|x| subst(x, map)}
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

    class TypeSchema < Type  # not sure this is meant to be a subclass of Type
      def initialize(typeVars, bodyType)
        @typeVars, @bodyType = typeVars, bodyType
      end
      attr_reader :typeVars, :bodyType

      def str
        return @bodyType.str if @typeVars.length == 0

        # Supports up to 26 variables
        pairs = @typeVars.zip("a".."z").map{|item, c|
          [item, "'#{c}"]
        }
        return bodyType.subst(Hash[pairs]).str
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

      typeCtxt.add("(+)", binOpType(Type::INT, Type::INT, Type::INT))
      valueEnv.add("(+)", Value::Subr.new{|lhs|
        Value::Subr.new{|rhs|
          Value::Int.new(lhs.intValue + rhs.intValue)
        }
      })

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
    src = "1"
    expr = Parser.new.parse(src)

    variants = Env.new(:Global)
    env = Env.default
    type = Inferer.infer(env[:typeCtxt], env[:typeEnv], variants, expr)

    value = Eva.eval(env[:valueEnv], expr)

    pp expr: expr, type: type, value: value
  end
end
