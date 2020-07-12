class RbsTsGenerator < Rails::Generators::Base
  class TypeScriptVisitor < ActionDispatch::Journey::Visitors::FunctionalVisitor
    private

    def binary(node, seed)
      visit(node.right, visit(node.left, seed) + ' + ')
    end

    def nary(node, seed)
      last_child = node.children.last
      node.children.inject(seed) { |s, c|
        string = visit(c, s)
        string << '|' unless last_child == c
        string
      }
    end

    def terminal(node, seed)
      seed + node.left.to_s.to_json
    end

    def visit_GROUP(node, seed)
      # TODO: support nested level 2
      visit(node.left, seed.dup << '(() => { try { return ') << ' } catch { return "" } })()'
    end

    def visit_SYMBOL(n, seed);  variable(n, seed); end

    def variable(node, seed)
      if node.left.to_s[0] == '*'
        seed + '(' + node.left.to_s[1..-1] + ' ?? "")'
      else
        v = node.left.to_s[1..-1]
        seed + "(() => { if (#{v}) return #{v}; throw #{v.to_json} })()"
      end
    end

    INSTANCE = new
  end
end
