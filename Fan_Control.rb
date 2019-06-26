require 'yaml'
require 'colorize'
require 'singleton'

module R710_Tools
  class Fan_Control
    include Singleton
    @@config_locations = [ '/etc/fan-control.yaml', 'fan-control.yaml' ]
    @config = nil
    @is_manual = false
    @last_speed_set = 0
    @ipmitool = nil

    # load config on init
    def initialize
      @ipmitool = `which ipmitool`.strip
      raise "ipmitool command not found" unless File.exist? @ipmitool
      @sensors = `which sensors`.strip
      raise "sensors command not found" unless File.exist? @sensors
      @@config_locations.each do |loc|
        if File.exist?(loc)
          puts "Loading configuration from #{loc}".colorize(:yellow)
          @config = YAML.load_file(loc)
          break
        end
      end
      raise "Did not find config file!" if @config.nil?
    end

    # get current cpu core temperature from sensors
    def get_temperature
      output = `#{@sensors}`
      max_temp = 0.0
      min_temp = 100
      output.each_line do |line|
        if line =~ /^Core.*\+(\d+\.\d+)°C\s+\(/
          t = $1.to_f
          max_temp = t if t > max_temp
          min_temp = t if t < min_temp
        end
      end
      return { :min => min_temp, :max => max_temp}
    end

    # get current ambient temp via ipmi
    def get_ambient
      output = `#{@ipmitool} -I lanplus -H #{@config[:host]} -U #{@config[:user]} -P #{@config[:pass]} sdr get "Ambient Temp"`
      result = {}
      output.each_line do |line|
        if line =~ /Sensor Reading\s+:\s+(\d+)/
          result[:current] = $1.to_i
          next
        end
        if line =~ /Upper critical\s+:\s+(\d+)/
          result[:crit] = $1.to_i
          next
        end
        if line =~ /Upper non-critical\s+:\s+(\d+)/
          result[:warn] = $1.to_i
          next
        end
        if line =~ /Status\s+:\s+(\w+)/
          result[:status] = $1
          next
        end
      end
      return result
    end

    # get current fan speeds via ipmi
    def get_fan_speed
      output = `#{@ipmitool} -I lanplus -H #{@config[:host]} -U #{@config[:user]} -P #{@config[:pass]} sdr type Fan`
      max_speed = 0
      min_speed = 15000
      output.each_line do |line|
        if line =~ /(\d+)\s+RPM$/
          rpm = $1.to_i
          max_speed = rpm if rpm > max_speed
          min_speed = rpm if rpm < min_speed
        end
      end
      return { :min => min_speed, :max => max_speed}
    end

    # set the fan speed to the given percentage of max speed
    #
    # @param target fan speed in percent of max speed as integer
    def set_fan_speed(speed_percent)
      target_speed = sprintf("%02X",speed_percent)
      system("#{@ipmitool} -I lanplus -H #{@config[:host]} -U #{@config[:user]} -P #{@config[:pass]} raw 0x30 0x30 0x02 0xff 0x#{target_speed}")
      @last_speed_set = speed_percent
      puts "Fan speed set to #{speed_percent}% (0x#{target_speed})"
    end

    # set fan speed control to manual
    def set_fan_manual
      system("#{@ipmitool} -I lanplus -H #{@config[:host]} -U #{@config[:user]} -P #{@config[:pass]} raw 0x30 0x30 0x01 0x00")
      @is_manual = true
      puts "Manual fan control active".colorize(:light_blue)
    end

    # set fan speed control to automatic
    def set_fan_automatic
      system("#{@ipmitool} -I lanplus -H #{@config[:host]} -U #{@config[:user]} -P #{@config[:pass]} raw 0x30 0x30 0x01 0x01")
      @is_manual = false
      puts "Automatic fan control restored".colorize(:green)
    end

    # get target speed for current temperature
    #
    # @param current max cpu temperature as float
    def get_target_speed(temp)
      @config[:speed_steps].each do |range|
        return range[1] if range[0].cover?(temp)
      end
    end

    # the main loop adjusting fan speeds
    # check current temp against max manual temp
    # if above end manual control and switch back to automatic
    # -> wait for cool down period until we check again
    # else get the speed for the current temp and apply if != last set
    def fan_control_loop
      puts 'Starting fan control loop'.colorize(:white).bold
      begin
        while true
          cur_temp = get_temperature[:max]
          if cur_temp > @config[:max_manual_temp]
            puts "Temperature higher than max_manual_temp -> switching to automatic"
            set_fan_automatic
            puts "Cool down period started"
            sleep @config[:cool_down_time]
            next
          end
          set_fan_manual if !@is_manual
          target = get_target_speed(cur_temp)
          set_fan_speed(target) if target != @last_speed_set
          sleep @config[:interval]
        end
      rescue StandardError => e
        puts "Exception or Interrupt occurred - switching back to automatic fan control"
        set_fan_automatic
        raise e
      end
    end
  end
end
