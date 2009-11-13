# === Synopsis:
#   RightScale Nanite Controller (rnac) - (c) 2009 RightScale
#
#   rnac is a command line tool that allows managing Nanite agents.
#
# === Examples:
#   Start new agent:
#     rnac --start AGENT
#     rnac -s AGENT
#
#   Create agent configuration file and start it:
#     rnac --start AGENT --create_conf
#     rnac -s AGENT -c
#
#   Terminate agent with given ID token:
#     rnac --terminate ID
#     rnac -t ID
#
#   Terminate all agents:
#     rnac --killall
#     rnac -K
#
#   List running agents on /nanite vhost on local machine:
#     rnac --status --vhost /nanite
#     rnac -U -v /nanite
#
#   Start new agent in foreground:
#     rnac --start AGENT --foreground
#     rnac -s AGENT -f
#
#  === Usage:
#    rnac [options]
#
#    options:
#      --start, -s AGENT:   Start agent AGENT
#      --term-agent, -T ID: Stop agent with given serialized identity
#      --kill, -k PIDFILE:  Kill process with given pid file
#      --killall, -K:       Stop all running agents
#      --status, -U:        List running agents on local machine
#      --decommission, -d:  Send decom signal to instance agent
#      --identity, -i ID    Use base id ID to build agent's identity
#      --token, -t TOKEN    Use token TOKEN to build agent's identity
#      --prefix, -r PREFIX  Prefix agent's identity with PREFIX
#      --list, -l:          List all registered agents
#      --user, -u USER:     Set AMQP user
#      --pass, -p PASS:     Set AMQP password
#      --vhost, -v VHOST:   Set AMQP vhost
#      --host, -h HOST:     Set AMQP server hostname
#      --port, -P PORT:     Set AMQP server port
#      --log-level LVL:     Log level (debug, info, warning, error or fatal)
#      --log-dir DIR:       Log directory
#      --pid-dir DIR:       Pid files directory (/tmp by default)
#      --foreground, -f:    Run agent in foreground
#      --interactive, -I:   Spawn an irb console after starting agent
#      --debugger, -D PORT  Start a debug server on PORT and immediately break
#      --test:              Use test settings
#      --version, -v:       Display version information
#      --help:              Display help

require 'optparse'
require 'rdoc/ri/ri_paths' # For backwards compat with ruby 1.8.5
require 'rdoc/usage'
require 'yaml'
require 'ftools'
require 'fileutils'
require 'nanite'
require File.join(File.dirname(__FILE__), 'rdoc_patch')
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'config', 'right_link_config'))
require File.join(File.dirname(__FILE__), 'agent_utils')
require File.join(File.dirname(__FILE__), 'common_parser')
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'agents', 'lib', 'instance', 'instance_state'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'agents', 'lib', 'common', 'right_link_log'))
require File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'lib', 'amqp_retry_patch'))
require File.join(File.dirname(__FILE__), 'command_client')

module RightScale

  class AgentController

    include Utils
    include CommonParser

    VERSION = [0, 2]
    YAML_EXT = %w{ yml yaml }
    FORCED_OPTIONS = { :format => :secure, :single_threaded => true }
    DEFAULT_OPTIONS =
    {
      :log_dir => RightLinkConfig[:platform].filesystem.log_dir,
      :daemonize => true
    }

    # Convenience wrapper
    def self.run
      c = AgentController.new
      c.control(c.parse_args)
    end

    # Parse arguments and run
    def control(options)     

      # Validate arguments
      action = options.delete(:action)
      fail("No action specified on the command line.", print_usage=true) if action.nil?
      if action == 'kill' && (options[:pid_file].nil? || !File.file?(options[:pid_file]))
        fail("Missing or invalid pid file #{options[:pid_file]}", print_usage=true)
      end
      if options[:pid_dir] && !File.directory?(options[:pid_dir])
        File.makedirs(options[:pid_dir])
      end
      if options[:agent]
        root_dir = gen_agent_dir(options[:agent])
        fail("Deployment directory #{root_dir} is missing.") if !File.directory?(root_dir)
        cfg = File.join(root_dir, 'config.yml')
        fail("Deployment is missing configuration file in #{root_dir}.") unless File.exist?(cfg)
        file_options = symbolize(YAML.load(IO.read(cfg))) rescue {} || {}
        file_options.merge!(options)
        options = file_options
        RightLinkLog.program_name = syslog_program_name(options)
        RightLinkLog.log_to_file_only(options[:log_to_file_only])
      end 
      options.merge!(FORCED_OPTIONS)
      options_with_default = {}
      DEFAULT_OPTIONS.each { |k, v| options_with_default[k] = v }
      options = options_with_default.merge(options)
      @options = options

      # Start processing
      success = case action
      when /show|killall/
        action = 'stop' if action == 'killall'
        s = true
        running_agents.each { |id| s &&= run_cmd(action, id) }
        s
      when 'kill'
        kill_process
      else
        run_cmd(action, options[:identity])
      end

      exit(1) unless success
    end

    # Parse arguments
    def parse_args
      # The options specified in the command line will be collected in 'options'
      options = {}

      opts = OptionParser.new do |opts|
        parse_common(opts, options)

        opts.on("-s", "--start AGENT") do |a|
          options[:action] = 'run'
          options[:agent] = a
        end

        opts.on("-T", "--term-agent ID") do |id|
          options[:action] = 'stop'
          options[:identity] = id
        end

        opts.on("-k", "--kill PIDFILE") do |file|
          options[:pid_file] = file
          options[:action] = 'kill'
        end
    
        opts.on("-K", "--killall") do
          options[:action] = 'killall'
        end

        opts.on("-d", "--decommission") do
          options[:action] = 'decommission'
        end

        opts.on("-U", "--status") do
          options[:action] = 'show'
        end

        opts.on("-l", "--list") do
          res =  available_agents
          if res.empty?
            puts "Found no registered agent"
          else
            puts version
            puts "Available agents:"
            res.each { |a| puts "  - #{a}" }
          end
          exit
        end

        opts.on("--log-level LVL") do |lvl|
          options[:log_level] = lvl
        end

        opts.on("--log-dir DIR") do |dir|
          options[:log_dir] = dir

          # ensure log directory exists (for windows, etc.)
          FileUtils.mkdir_p(options[:log_dir]) unless File.directory?(options[:log_dir])
        end
        
        opts.on("--pid-dir DIR") do |dir|
          options[:pid_dir] = dir
        end
        
        opts.on("-f", "--foreground") do
          options[:daemonize] = false
          #Squelch Ruby VM warnings about various things 
          $VERBOSE = nil
        end

        opts.on("-I", "--interactive") do
          options[:console] = true
        end

        opts.on("-D", "--debugger PORT") do |port|
          options[:debugger] = port.to_i 
        end

        opts.on("--help") do
          RDoc::usage_from_file(__FILE__)
        end

      end

      opts.parse(ARGV)
      resolve_identity(options)
      options
    end

    protected

    # Dispatch action
    def run_cmd(action, id)
      # setup the environment from config if necessary
      begin
        case action
          when 'run'          then start_agent
          when 'stop'         then stop_agent(id)
          when 'show'         then show_agent(id)
          when 'decommission' then run_decommission
        end
      rescue SystemExit
        true
      rescue SignalException
        true
      rescue Exception => e
        msg = "Failed to #{action} #{name} (#{e.class.to_s}: #{e.message})" + "\n" + e.backtrace.join("\n")
        puts msg
      end
    end

    # Kill process defined in pid file
    def kill_process(sig='TERM')
      content = IO.read(@options[:pid_file])
      pid = content.to_i
      fail("Invalid pid file content '#{content}'") if pid == 0
      begin
        Process.kill(sig, pid)
      rescue Errno::ESRCH => e
        fail("Could not find process with pid #{pid}")
      rescue Errno::EPERM => e
        fail("You don't have permissions to stop process #{pid}")
      rescue Exception => e
        fail(e.message)
      end
      true
    end

    # Print failure message and exit abnormally
    def fail(message, print_usage=false)
      puts "** #{message}"
      RDoc::usage_from_file(__FILE__) if print_usage
      exit(1)
    end

    # Trigger execution of decommission scripts in instance agent and wait for it to be done
    # then causes agent to terminate
    def run_decommission
      puts "Attempting to decommission local instance..."
      begin
        @client = CommandClient.new
        File.open('/tmp/juju','a'){|f|f.puts "ABOUT TO DECOMMISSION, EM RUNNING: #{EM.reactor_running?}"}
        @client.send_command({ :name => 'decommission' }, verbose=false, timeout=100) do |r|
          puts r
          File.open('/tmp/juju','a'){|f|f.puts "ABOUT TO TERMINATE, EM RUNNING: #{EM.reactor_running?}"}
          @client.send_command({ :name => 'terminate' }, verbose=false, timeout=10)
        end
        return true
      rescue Exception => e
        File.open('/tmp/juju','a'){|f|f.puts "FAILED WITH #{e.message + "\n" + e.backtrace.join("\n")}"}
        puts "Failed to decommission or else time limit was exceeded (#{e.message}).\nConfirm that the local instance is still running."
      end
      false
    end

    # Start nanite agent, return true
    def start_agent
      @options[:root] = gen_agent_dir(@options[:agent])
      puts "#{name} started."

      start_debugger(@options[:debugger]) if @options[:debugger]

      EM.run do
        Nanite.start_agent(@options)
      end
      
      true
    end      
    
    # Stop given agent, return true on success, false otherwise
    def stop_agent(id)
      @options[:identity] = id
      try_kill(agent_pid_file)
    end
    
    # Show status of given agent, return true on success, false otherwise
    def show_agent(id)
      @options[:identity] = id
       show(agent_pid_file)
    end

    # Start a debug server listening on the specified port
    def start_debugger(port)
      begin
        require 'ruby-debug'
        require 'ruby-debug-ide'
        Debugger::start_server('127.0.0.1', port)
      rescue LoadError => e
        raise LoadError.new("Cannot start debugger unless ruby-debug and ruby-debug-ide gems are available")
      end
    end

    # Human readable name for managed entity
    def name
      "Agent #{@options[:agent] + ' ' if @options[:agent]}with ID #{@options[:identity]}"
    end

    # Retrieve agent pid file
    def agent_pid_file
      agent = Nanite::Agent.new(@options)
      Nanite::PidFile.new(agent.identity, agent.options)
    end
    
    # Kill process with pid in given pid file
    def try_kill(pid_file)
      res = false
      if pid = pid_file.read_pid
        begin
          Process.kill('TERM', pid)
          res = true
          puts "#{name} stopped."
        rescue Errno::ESRCH
          puts "#{name} not running."
        end
      else
        if File.file?(pid_file.to_s)
          puts "Invalid pid file '#{pid_file.to_s}' content: #{IO.read(pid_file.to_s)}"
        else
          puts "Non-existant pid file '#{pid_file.to_s}'"
        end
      end
      res
    end

    # Show status of process with pid in given pid file
    def show(pid_file)
      res = false
      if pid = pid_file.read_pid
        pid = Process.getpgid(pid) rescue -1
        if pid != -1
          psdata = `ps up #{pid}`.split("\n").last.split
          memory = (psdata[5].to_i / 1024)
          puts "#{name} is alive, using #{memory}MB of memory"
          res = true
        else
          puts "#{name} is not running but has a stale pid file at #{pid_file}"
        end
      end
      res
    end

    # List of running agent IDs
    def running_agents
      list = `rabbitmqctl list_queues -p #{@options[:vhost]}`
      list.scan(/^\s*nanite-([\S]+)/).flatten
    end

    # Available agents i.e. agents that have a config file in the 'agents' dir
    def available_agents
      agents_configs.map { |cfg| File.basename(cfg, '.*') }
    end

    # List of all agents configuration files
    def agents_configs
      Dir.glob(File.join(agents_dir, "**", "*.{#{YAML_EXT.join(',')}}"))
    end

    # Version information
    def syslog_program_name(options)
      'RightLink'
    end

    # Version information
    def version
      "rnac #{VERSION.join('.')} - RightScale Nanite Controller (c) 2009 RightScale"
    end

  end
end
