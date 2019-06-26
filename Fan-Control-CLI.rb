#! /usr/bin/ruby
#
# Author: Sledge Sulaweyo <sledge.sulaweyo@gmail.com>
#
# ---------------------------------------------------------------------
# Dell R710 fan control
# Query and set values or use a configurable automatic adjustment
#
# Requirements:
# ipmitool must be installed and allowed to access idrac
# lm_sensors must be running to get current cpu core temp
# ---------------------------------------------------------------------
# WARNING:
# Be careful with what you configure!
# I take NO responsibility if you mess up anything.
# ---------------------------------------------------------------------
#
require 'thor'

require_relative 'Fan_Control.rb'

module R710_Tools
  class Fan_Control_CLI < Thor

    desc "fanspeed", "Get the current fan speed"
    def fanspeed
      fs = R710_Tools::Fan_Control.instance.get_fan_speed
      puts "Current fan speed: #{fs[:min]}-#{fs[:max]}RPM (min/max)"
    end

    desc "temp", "Get current cpu core temperature"

    def temp
      t = R710_Tools::Fan_Control.instance.get_temperature
      puts "Current CPU temperature: #{t[:min]}-#{t[:max]}°C (min/max)"
    end

    desc 'ambient', 'Get current ambient temperature'

    def ambient
      a = R710_Tools::Fan_Control.instance.get_ambient
      puts "Current ambient temperature: #{a[:current]}°C - Status: #{a[:status]}"
      puts "Ambient warning threshold: #{a[:warn]}°C"
      puts "Ambient critical threshold: #{a[:crit]}°C"
    end

    desc 'setspeed [value]', 'Set fan speed to given percent of max speed'

    def setspeed(value)
      raise 'Given value out of acceptable range (10-100)' unless value.to_i.between?(10, 100)
      fc = R710_Tools::Fan_Control.instance
      fc.set_fan_manual
      fc.set_fan_speed(value.to_i)
    end

    desc 'reset', 'Switch back to automatic fan control'

    def reset
      R710_Tools::Fan_Control.instance.set_fan_automatic
    end

    desc 'start', 'Start fan control loop'

    def start
      R710_Tools::Fan_Control.instance.fan_control_loop
    end

  end
end

R710_Tools::Fan_Control_CLI.start

