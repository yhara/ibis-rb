module Ibis
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
end
