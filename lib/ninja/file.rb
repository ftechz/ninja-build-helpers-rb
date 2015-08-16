module Ninja
  class File
    def initialize(path=nil, &block)
      @variables = []
      @rules = []
      @builds = []
      @defaults = []
      Delegator.new(self, :except => [:save]).instance_eval(&block) if block_given?
      self.save(path) if path
    end

    def variable(name, value)
      @variables.push(Ninja::Variable.new(name, value))
    end

    def rule(name, command, opts={})
      @rules.push(Ninja::Rule.new(:name => name,
                                  :command => command,
                                  :dependencies => opts[:dependencies]))
    end

    def build(rule, outputs_to_inputs={})
      outputs_to_inputs.each do |output, inputs|
        @builds.push(Ninja::Build.new(:rule => rule, :inputs => [*inputs], :output => output))
      end
    end

    def default(outputs)
      raise "Expected output(s) to be paths." unless [*outputs].all?{|output| /\A(?:[-\w\.]+\/?)+\z/.match(output)}
      @defaults.push(*outputs)
    end

    def save(path)
      raise "Path not specified!" unless path
       # TODO(mtwilliams): Check if everything up to |path| exists.
      ::File.open(path, 'w') do |f|
        f.write "# This file was auto-generated by \"#{::File.basename($PROGRAM_NAME, ::File.extname($0))}\".\n"
        f.write "# Do not modify! Instead, modify the aforementioned program.\n\n"
        f.write "# We require Ninja >= 1.3 for `deps` and >= 1.5 for `msvc_deps_prefix`.\n"
        f.write "ninja_required_version = 1.5\n\n"

        @variables.each do |variable|
          # TODO(mtwilliams): Escape.
          f.write "#{variable.name} = #{variable.value}\n"
        end

        @rules.each do |rule|
          f.write "rule #{rule.name}\n"
          if rule.dependencies
            if (rule.dependencies == :gcc) or (rule.dependencies == :clang)
              f.write "  depfile = $out.d\n"
              f.write "  deps = gcc\n"
            elsif rule.dependencies == :msvc
              # TODO(mtwilliams): Handle non-English output.
              f.write "  msvc_deps_prefix = Note: including file: \n"
              f.write "  deps = msvc\n"
            else
              f.write "  depfile = #{rule.dependencies}\n"
            end
          end
          f.write "  command = #{rule.command}\n\n"
        end

        @builds.each do |build|
          f.write "build #{build.output}: #{build.rule} #{build.inputs.join(' ')}\n"
        end
        f.write "\n" unless @builds.empty?

        f.write "default #{@defaults.join(' ')}\n" unless @defaults.empty?

        # TODO(mtwilliams): Aliases (via the 'phony' rule).
        # TODO(mtwilliams): Execute other files (via 'subninja').
        # TODO(mtwilliams): Specify pools, to optimize compilation times.
      end
    end
  end
end
