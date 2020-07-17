require 'stringio'
require 'rbs'
require_relative './rbs_types_convertible'
require_relative './type_script_visitor'

using RbsTsGenerator::RbsTypesConvertible

using Module.new {
  refine(Object) do
    def parse_type_name(string)
      RBS::Namespace.parse(string).yield_self do |namespace|
        last = namespace.path.last
        RBS::TypeName.new(name: last, namespace: namespace.parent)
      end
    end

    def type_script_params_type_name(controller, action)
      "#{controller.to_s.camelcase}#{action.to_s.camelcase}Params"
    end

    def type_script_return_type_name(controller, action)
      "#{controller.to_s.camelcase}#{action.to_s.camelcase}Return"
    end

    def typescript_path_function(route_info, verb_type)
      name = route_info.fetch(:name).camelize(:lower)
      parts = route_info.fetch(:parts)
      body = RbsTsGenerator::TypeScriptVisitor::INSTANCE.accept(route_info.fetch(:spec), '')
      <<~TS
      export const #{name} = {
        path: (#{ parts.empty? ? '' : "{ #{parts.join(', ')} }: any" }) => #{ body },
        names: [#{ parts.map(&:to_json).join(",") }]
      } as {
        path: (args: any) => string
        names: [#{ parts.map(&:to_json).join(",") }]
        Methods?: #{verb_type.keys.map(&:to_json).join(' | ')}
        Params?: {
      #{verb_type.map { |v, t| "    #{v}: #{t.fetch(:params_type)}" }.join(",\n")}
        }
        Return?: {
      #{verb_type.map { |v, t| "    #{v}: #{t.fetch(:return_type)}" }.join(",\n")}
        }
      }
      TS
    end

    def routes_info
      rs = Rails.application.routes.routes.filter_map { |r|
        {
          verb: r.verb,
          name: r.name,
          parts: r.parts,
          reqs: r.requirements,
          spec: r.path.spec
        } if !r.internal && !r.app.engine?
      }
      rs.inject([]) do |new_rs, r|
        prev_r = new_rs.last
        if prev_r && r[:name].nil? && r.fetch(:spec).to_s != prev_r.fetch(:spec).to_s
          # puts prev_r[:name]
          # puts r.fetch(:spec).to_s
          # puts prev_r.fetch(:spec).to_s
          # raise
          next new_rs
        end
        r[:name] = prev_r[:name] if prev_r && r[:name].nil?
        next new_rs if r[:name].nil?
        new_rs << r
      end
    end

    def rbs_loader
      RBS::EnvironmentLoader.new.tap do |loader|
        dir = Pathname('sig')
        loader.add(path: dir)
      end
    end

    def rbs_env
      RBS::Environment.new.tap { |e| rbs_loader.load(env: e) }
    end

    def rbs_builder
      RBS::DefinitionBuilder.new(env: rbs_env)
    end

    def collect_controller_action_method_type
      builder = rbs_builder
      types = {}
      ApplicationController.subclasses.each do |subclass|
        subclass_type_name = parse_type_name(subclass.inspect).absolute!
        begin
          binding.pry
          definition = builder.build_instance(subclass_type_name)
        rescue
          e = $!
          binding.irb
        end
        actions = subclass.public_instance_methods(false)
        actions.each do |action|
          method = definition.methods[action]
          next unless method
          raise 'Unsupported' unless method.method_types.size == 1
          method_type = method.method_types.first
          raise 'Unsupported' unless method_type.is_a?(RBS::MethodType)
          controller = subclass.to_s.sub(/Controller$/, '').underscore.to_s
          types[controller] ||= {}
          types[controller][action.to_s] = method_type
        rescue
          $stderr.puts $!.backtrace.join("\n")
          $stderr.puts "#{subclass}##{action} not supported"
        end
      end
      types
    end

    def collect_controller_action_params_types
      types = {}
      collect_controller_action_method_type.each do |controller, action_method_types|
        action_method_types.each do |action, method_type|
          type = method_type.to_ts_params_type
          types[controller] ||= {}
          types[controller][action] ||= {}
          types[controller][action] = type.empty? ? '{}' : type
        end
      end
      types
    end

    def collect_controller_action_return_types
      types = {}
      collect_controller_action_method_type.each do |controller, action_method_types|
        action_method_types.each do |action, method_type|
          type = method_type.to_ts_return_type
          types[controller] ||= {}
          types[controller][action] ||= {}
          types[controller][action] = type.empty? ? '{}' : type
        end
      end
      types
    end
  end
}

using Module.new {
  refine(Object) do
    def generate_params_types
      output = StringIO.new
      types = collect_controller_action_params_types
      types.each do |controller, actions|
        actions.each do |action, type|
          output.puts "type #{type_script_params_type_name(controller, action)} = #{type}"
        end
      end
      output.string
    end

    def generate_return_types
      output = StringIO.new
      types = collect_controller_action_return_types
      types.each do |controller, actions|
        actions.each do |action, type|
          output.puts "type #{type_script_return_type_name(controller, action)} = Exclude<#{type}, void>"
        end
      end
      output.string
    end

    def generate_request_functions
      output = StringIO.new
      type = collect_controller_action_params_types
      routes_info.group_by { |r| r.fetch(:name) }.each do |name, routes|
        route = routes.first
        verb_type = routes.each_with_object({}) do |r, vt|
          controller = r.dig(:reqs, :controller)
          action = r.dig(:reqs, :action)
          next unless type.dig(controller, action)
          vt[r.fetch(:verb)] = {
            params_type: type_script_params_type_name(controller, action),
            return_type: type_script_return_type_name(controller, action)
          }
        end
        next if verb_type.empty?
        output.puts typescript_path_function(route, verb_type)
      end
      output.string
    end
  end
}

class RbsTsGenerator < Rails::Generators::Base
  source_root File.expand_path('templates', __dir__)

  def copy_rbs_ts_runtime_ts
    copy_file 'rbs_ts_runtime.ts', 'app/javascript/packs/rbs_ts_runtime.ts'
  end

  def create_rbs_ts_routes_ts
    Rails.application.eager_load!
    params_types = generate_params_types
    return_types = generate_return_types
    request_functions = generate_request_functions
    create_file 'app/javascript/packs/rbs_ts_routes.ts', [params_types, return_types, request_functions].join("\n")
  end
end
