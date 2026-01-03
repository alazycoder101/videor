if defined?(Rails::LineFiltering)
  module Rails
    module LineFiltering
      def run(*args, **kwargs, &block)
        if args.length <= 2
          reporter = args[0]
          options = args[1] || kwargs[:options] || {}
          options = options.merge(filter: Rails::TestUnit::Runner.compose_filter(self, options[:filter]))
          if kwargs.key?(:options)
            kwargs = kwargs.merge(options: options)
            super(reporter, **kwargs, &block)
          else
            super(reporter, options, &block)
          end
        else
          super(*args, **kwargs, &block)
        end
      end
    end
  end
end
