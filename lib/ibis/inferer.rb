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
end
