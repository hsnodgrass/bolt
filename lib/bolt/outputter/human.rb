require 'terminal-table'
module Bolt
  class Outputter
    class Human < Bolt::Outputter
      COLORS = { red: "31",
                 green: "32",
                 yellow: "33" }.freeze

      def print_head; end

      def colorize(color, string)
        if @stream.isatty
          "\033[#{COLORS[color]}m#{string}\033[0m"
        else
          string
        end
      end

      def indent(indent, string)
        indent = ' ' * indent
        string.gsub(/^/, indent.to_s)
      end

      def remove_trail(string)
        string.sub(/\s\z/, '')
      end

      def print_event(event)
        case event[:type]
        when :node_start
          print_start(event[:target])
        when :node_result
          print_result(event[:result])
        end
      end

      def print_start(target)
        @stream.puts(colorize(:green, "Started on #{target.host}..."))
      end

      def print_result(result)
        if result.success?
          @stream.puts(colorize(:green, "Finished on #{result.target.host}:"))
        else
          @stream.puts(colorize(:red, "Failed on #{result.target.host}:"))
        end

        if result.error_hash
          @stream.puts(colorize(:red, remove_trail(indent(2, result.error_hash['msg']))))
        end

        if result.message
          @stream.puts(remove_trail(indent(2, result.message)))
        end

        # There is more information to output
        if result.generic_value
          # Use special handling if the result looks like a command or script result
          if result.generic_value.keys == %w[stdout stderr exit_code]
            unless result['stdout'].strip.empty?
              @stream.puts(indent(2, "STDOUT:"))
              @stream.puts(indent(4, result['stdout']))
            end
            unless result['stderr'].strip.empty?
              @stream.puts(indent(2, "STDERR:"))
              @stream.puts(indent(4, result['stderr']))
            end
          else
            @stream.puts(indent(2, ::JSON.pretty_generate(result.generic_value)))
          end
        end
      end

      def print_summary(results, elapsed_time)
        @stream.puts format("Ran on %d node%s in %.2f seconds",
                            results.size,
                            results.size == 1 ? '' : 's',
                            elapsed_time)
      end

      def print_table(results)
        @stream.puts Terminal::Table.new(
          rows: results,
          style: {
            border_x: '',
            border_y: '',
            border_i: '',
            padding_left: 0,
            padding_right: 3,
            border_top: false,
            border_bottom: false
          }
        )
      end

      # @param [Hash] A hash representing the task
      def print_task_info(task)
        # Building lots of strings...
        pretty_params = ""
        task_info = ""
        usage = "bolt task run --nodes, -n <node-name> #{task['name']}"

        if task['parameters']
          task['parameters'].each do |k, v|
            pretty_params << "- #{k}: #{v['type']}\n"
            pretty_params << "    #{v['description']}\n" if v['description']
            usage << if !v['type'].to_s.include? "Optional"
                       " #{k}=<value>"
                     else
                       " [#{k}=<value>]"
                     end
          end
        end

        usage << " [--noop]" if task['supports_noop']

        task_info << "\n#{task['name']}"
        task_info << " - #{task['description']}" if task['description']
        task_info << "\n\n"
        task_info << "USAGE:\n#{usage}\n\n"
        task_info << "PARAMETERS:\n#{pretty_params}\n" if task['parameters']
        @stream.puts(task_info)
      end

      def print_plan(result)
        # If a hash or array, pretty-print as JSON
        if result.is_a?(Hash) || result.is_a?(Array)
          if result.empty?
            # Avoids extra lines for an empty result
            @stream.puts(result.to_json)
          else
            @stream.puts(::JSON.pretty_generate(result))
          end
        else
          @stream.puts result.to_s
        end
      end

      def fatal_error(e)
        @stream.puts(colorize(:red, e.message))
        if e.is_a? Bolt::RunFailure
          @stream.puts ::JSON.pretty_generate(e.resultset)
        end
      end
    end

    def print_message(message)
      @stream.puts(message)
    end
  end
end
