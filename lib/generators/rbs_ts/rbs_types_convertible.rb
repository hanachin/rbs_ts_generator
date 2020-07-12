require 'rbs'

unless RBS::Types.constants.sort == [:NoSubst, :EmptyEachType, :Literal, :Bases, :Interface, :Tuple, :Union, :ClassSingleton, :Application, :ClassInstance, :Record, :Function, :Optional, :Variable, :Alias, :Proc, :Intersection, :NoFreeVariables].sort
  raise 'Unsupported'
end

unless RBS::Types::Bases.constants.sort == [:Instance, :Base, :Class, :Void, :Any, :Nil, :Top, :Bottom, :Self, :Bool].sort
  raise 'Unsupported'
end

class RbsTsGenerator < Rails::Generators::Base
  module RbsTypesConvertible
    using self

    refine(RBS::MethodType) do
      def to_ts_params_type
        raise 'Unsupported' unless type_params.empty?

        s = case
            when block && block.required
              raise 'Unsupported'
            when block
              raise 'Unsupported'
            else
              type.param_to_s
            end

        if type_params.empty?
          s
        else
          raise 'Unsuported'
        end
      end

      def to_ts_return_type
        type.return_to_s
      end
    end

    refine(RBS::Types::Function::Param) do
      def to_s
        type.to_s
      end
    end

    refine(RBS::Types::Function) do
      def param_to_s
        params = []
        params.push(*required_positionals.map { |param| "#{param.name}: #{param.type}" })
        params.push(*optional_positionals.map {|param| "#{param.name}?: #{param.type}" })
        raise 'Unsupported' if rest_positionals
        params.push(*trailing_positionals.map { |param| "#{param.name}: #{param.type}" })
        params.push(*required_keywords.map {|name, param| "#{name}: #{param}" })
        params.push(*optional_keywords.map {|name, param| "#{name}?: #{param}" })
        raise 'Unsupported' if rest_keywords

        return '' if params.empty?

        "{ #{params.join("; ")} }"
      end

      def return_to_s
        return_type.to_s
      end
    end

    # RBS::Types.constants.map { RBS::Types.const_get(_1) }.select { _1.public_instance_methods(false).include?(:to_s) }
    refine(RBS::Types::Literal) do
      def to_s(level = 0)
        case literal
        when Symbol, String
          literal.to_s.inspect
        when Integer, TrueClass, FalseClass
          literal.inspect
        else
          raise 'Unsupported'
        end
      end
    end

    refine(RBS::Types::Interface) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Tuple) do
      # copy from super to use refinements
      def to_s(level = 0)
        if types.empty?
          "[ ]"
        else
          "[ #{types.map(&:to_s).join(", ")} ]"
        end
      end
    end

    refine(RBS::Types::Record) do
      def to_s(level = 0)
        return "{ }" if self.fields.empty?

        fields = self.fields.map do |key, type|
          if key.is_a?(Symbol) && key.match?(/\A[A-Za-z_][A-Za-z0-9_]*\z/) && !key.match?(RBS::Parser::KEYWORDS_RE)
            "#{key.to_s}: #{type}"
          else
            "#{key.to_s.inspect}: #{type}"
          end
        end
        "{ #{fields.join("; ")} }"
      end
    end

    refine(RBS::Types::Union) do
      # copy from super to use refinements
      def to_s(level = 0)
        if level > 0
          "(#{types.map(&:to_s).join(" | ")})"
        else
          types.map(&:to_s).join(" | ")
        end
      end
    end

    refine(RBS::Types::ClassSingleton) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Application) do
      def to_s(level = 0)
        case name.to_s
        when '::Integer'
          'number'
        when '::String'
          'string'
        when '::Array'
          raise 'Unsupported' unless args.one?

          args[0].to_s + '[]'
        else
          raise 'Unsupported'
        end
      end
    end

    refine(RBS::Types::Optional) do
      # copy from super to use refinements
      def to_s(level = 0)
        if type.is_a?(RBS::Types::Literal) && type.literal.is_a?(Symbol)
          "#{type.to_s(1)} ?"
        else
          "#{type.to_s(1)}?"
        end
      end
    end

    refine(RBS::Types::Variable) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Alias) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Proc) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Intersection) do
      # copy from super to use refinements
      def to_s(level = 0)
        strs = types.map {|ty| ty.to_s(2) }
        if level > 0
          "(#{strs.join(" & ")})"
        else
          strs.join(" & ")
        end
      end
    end

    # RBS::Types::Bases.constants.map { RBS::Types::Bases.const_get(_1) }
    refine(RBS::Types::Bases::Instance) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Base) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Class) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Void) do
      def to_s(level = 0)
        'void'
      end
    end

    refine(RBS::Types::Bases::Any) do
      def to_s(level = 0)
        'any'
      end
    end

    refine(RBS::Types::Bases::Nil) do
      def to_s(level = 0)
        'null'
      end
    end

    refine(RBS::Types::Bases::Top) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Bottom) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Self) do
      def to_s(level = 0)
        raise 'Unsupported'
      end
    end

    refine(RBS::Types::Bases::Bool) do
      def to_s(level = 0)
        'boolean'
      end
    end
  end
end
