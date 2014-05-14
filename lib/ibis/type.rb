module Ibis
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

    # TODO: what is proper name for this?
    class Tmp < Type
      def initialize(c)
        @c = c
      end
      
      def str
        "'#{@c}"
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
          [item, Tmp.new(c)]
        }.to_h
        
        return @bodyType.subst(map).str
      end
    end
  end
end
