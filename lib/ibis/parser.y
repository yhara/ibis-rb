class Ibis::Parser
  options no_result_var
rule
  toplevel : Stmt { val[0] }

  Stmt :
    Def DSEMI
      { val[0] }
    | Def
      { val[0] }

  Def :
    Let
    | TypeDef
    | Expr

  Let :
    LET_ REC_ _IDENT EQ Abs
      { [:LetRec, {var: val[2], expr: val[4]}] }
    | LET_ LPAREN _IDENT COMMA 
    # TODO: parserLetTuple
    | LET_ _IDENT EQ SimpleExpr
      { [:Let, {var: val[1], expr: val[3]}] }

  TypeDef :
    TYPE _IDENT EQ TypeCtors

  TypeCtors :
    _IDENT OF_ TypeExpr VBAR TypeCtors
    | _IDENT OF_ TypeExpr

  TypeExpr :
    TypeMulExpr ARROW TypeExpr
    | TypeMulExpr

  TypeMulExpr :
    TypeAtom # TODO STAR 
  
  TypeAtom :
    _IDENT TypeVar
      { [:TypeVar, val[1]] }
    | LPAREN TypeExpr RPAREN
      { val[1] }

  Expr :
    CompExpr

  CompExpr :
    SimpleExpr
    # TODO

  SimpleExpr :
    Abs
    | If
    | Case
    | LogicExpr

  Abs : 
    FUN_ _IDENT ARROW SimpleExpr
      { [:Abs, [:Var, val[1]], [:Body, val[3]]] }

  If : 
    IF_ SimpleExpr THEN_ SimpleExpr ELSE_ SimpleExpr
      { [:If, {cond: val[1], then: val[3], else: val[5]}] }

  Case :
    CASE_ SimpleExpr OF_ CaseClauses ELSE_ VBAR SimpleExpr
      { [:Case, {variant: val[1], clauses: val[3], else: val[6]}] }
    | CASE_ SimpleExpr OF_ CaseClauses 
      { [:Case, {variant: val[1], clauses: val[3]}] }

  CaseClauses :
    _IDENT ARROW SimpleExpr VBAR CaseClauses
      { val[4].merge({val[0] => val[2]}) }
    | _IDENT ARROW SimpleExpr
      { {val[0] => val[2]} }

  LogicExpr :
    EqExpr

  EqExpr :
    ConcatExpr
    # TODO BinExpr

  ConcatExpr :
    AddExpr
    # TODO BinExpr

  AddExpr :
    MulExpr PLUS AddExpr
      { [:App, [:App, [:Var, "(+)"], val[0]], val[2]] }
    | MulExpr MINUS AddExpr
      { [:App, [:App, [:Var, "(-)"], val[0]], val[2]] }
    | MulExpr

  MulExpr :
    UnaryExpr STAR MulExpr
      { [:App, [:App, [:Var, "(*)"], val[0]], val[2]] }
    | UnaryExpr SLASH MulExpr
      { [:App, [:App, [:Var, "(/)"], val[0]], val[2]] }
    | UnaryExpr MOD_ MulExpr
      { [:App, [:App, [:Var, "(mod)"], val[0]], val[2]] }
    | UnaryExpr

  UnaryExpr :
    MINUS UnaryExpr
      { [:App, [:Var, "(~-)"], val[1]] }
    | PrimExpr

  PrimExpr :
    Atom

  Atom :
    _INT       { [:Const, val[0]] }
    | _STRING  { [:Const, val[0]] }
    | _IDENT   { [:Var, val[0]] }
    | TRUE_    { [:Const, true] }
    | FALSE_   { [:Const, false] }
    | LPAREN
end

---- header

require 'strscan'

---- inner

  def parse(str)
    @yydebug = ENV['DEBUG']
    @s = StringScanner.new(str)
    yyparse self, :scan
  end

  private

  KEYWORDS = %w(let rec fun if case true false mod)
  KEYWORDS_REXP = Regexp.new(KEYWORDS.map{|k| Regexp.quote(k)}.join("|"))

  SYMBOLS = {
    "|"   => "VBAR",
    ";"   => "SEMI",
    ";;"  => "DSEMI",
    ","   => "COMMA",
    "="   => "EQ",
    "("   => "LPAREN",
    ")"   => "RPAREN",
    "->"  => "ARROW",
    "+"   => "PLUS",
    "-"   => "MINUS",
    "*"   => "STAR",
    "/"   => "SLASH",
    "^"   => "HAT",
    "<"   => "LT",
    "<="  => "LE",
    ">"   => "GT",
    ">="  => "GE",
    "<>"  => "NE",
  }
  SYMBOLS_REXP = Regexp.new(SYMBOLS.map{|k, v| Regexp.quote(k)}.join("|"))

  def scan
    until @s.eos?
      case
      when (s = @s.scan(KEYWORDS_REXP))
        yield ["#{s.upcase}_".to_sym, s.upcase.to_sym]
      when (s = @s.scan(SYMBOLS_REXP))
        name = SYMBOLS[s]
        yield [name.to_sym, name.to_sym]
      when (s = @s.scan(/\d+/))
        n = s.to_i
        yield [:_INT, n]
      when @s.scan(/"/)
        s = @s.scan_until(/"/)
        raise "unterminated string" if s.nil?
        yield [:_STRING, s.chop]
      when (s = @s.scan(/[A-Za-z][0-9A-Za-z]*/))
        yield [:_IDENT, s]
      when @s.scan(/\s+/)
        # skip
      else
        p "@s" => @s
        raise "Syntax Error"
      end
      # TODO: comment (*(* *)*)
    end
    yield [false, '$']   # is optional from Racc 1.3.7
  end
