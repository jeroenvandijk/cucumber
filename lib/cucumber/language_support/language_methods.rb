require 'cucumber/step_match'
require 'cucumber/step_definition_light'

module Cucumber
  module LanguageSupport
    module LanguageMethods
      def create_step_match(step_definition, step_name, name_to_report, step_arguments)
        StepMatch.new(step_definition, step_name, name_to_report, step_arguments)
      end

      def before(scenario)
        begin_scenario(scenario)
        execute_before(scenario)
      end

      def after(scenario)
        execute_after(scenario)
        end_scenario
      end

      def after_configuration(configuration)
        hooks[:after_configuration].each do |hook|
          hook.invoke('AfterConfiguration', configuration)
        end
      end

      def execute_after_step(scenario)
        hooks_for(:after_step, scenario).each do |hook|
          invoke(hook, 'AfterStep', scenario, false)
        end
      end

      def execute_transforms(args)
        transformed_args = args.map do |arg|
            matching_transform = transforms.detect {|transform| transform.match(arg) }
            matching_transform ? matching_transform.invoke(arg) : arg
        end
        execute_tupil_transforms(transformed_args)
      end
      
      # Will try to find the combination of a normal string and a table
      # When found it will try to find a transform of the form /^some string table:.*$/ that can be applied
      def execute_tupil_transforms(args) #:nodoc:
        if args.size >= 2 && 
            (matched_string = args[-2]).kind_of?(String) && 
            (matched_table  = args[-1]).kind_of?(Ast::Table)
          matching_transform = transforms.detect {|transform| transform.match("#{matched_string} table:#{matched_table.headers.join(',')}") }
          
          # In order to apply the transform we need to temporarily change the regex i.e. strip al non related table stuff
          orig_regexp = matching_transform.regexp
          matching_transform.regexp = /^#{orig_regexp.inspect.slice(/table:.*/).chop}/

          transformations = matching_transform.invoke(matched_table)
          # raise "A tupil transform should return an array of length 2, got size #{transformations.size}" if transformations.size != 2
          args[-2..-1] = transformations

          # reset regexp
          matching_transform.regexp = orig_regexp
        end
        args
      end

      def add_hook(phase, hook)
        hooks[phase.to_sym] << hook
        hook
      end

      def add_transform(transform)
        transforms.unshift transform
        transform
      end

      def hooks_for(phase, scenario) #:nodoc:
        hooks[phase.to_sym].select{|hook| scenario.accept_hook?(hook)}
      end

      def unmatched_step_definitions
        available_step_definition_hash.keys - invoked_step_definition_hash.keys
      end

      def available_step_definition(regexp_source, file_colon_line)
        available_step_definition_hash[StepDefinitionLight.new(regexp_source, file_colon_line)] = nil
      end

      def invoked_step_definition(regexp_source, file_colon_line)
        invoked_step_definition_hash[StepDefinitionLight.new(regexp_source, file_colon_line)] = nil
      end

      private

      def available_step_definition_hash
        @available_step_definition_hash ||= {}
      end

      def invoked_step_definition_hash
        @invoked_step_definition_hash ||= {}
      end

      def hooks
        @hooks ||= Hash.new{|h,k| h[k] = []}
      end

      def transforms
        @transforms ||= []
      end

      def execute_before(scenario)
        hooks_for(:before, scenario).each do |hook|
          invoke(hook, 'Before', scenario, true)
        end
      end

      def execute_after(scenario)
        hooks_for(:after, scenario).reverse_each do |hook|
          invoke(hook, 'After', scenario, true)
        end
      end

      def invoke(hook, location, scenario, exception_fails_scenario)
        begin
          hook.invoke(location, scenario)
        rescue Exception => exception
          if exception_fails_scenario
            scenario.fail!(exception)
          else
            raise
          end
        end
      end
    end
  end
end
