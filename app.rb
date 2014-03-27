#!/usr/bin/env ruby
# encoding: utf-8
require 'rubygems'
require 'sinatra'
require 'serialport'
require 'celluloid/autostart'
set :server, %w[thin mongrel webrick]
set :bind, '0.0.0.0'
set :port, 8000

class LightStatus
  @@red = 0
  @@green = 0
  @@blue = 0
  @@device = nil
  @@shutdown = false
  @@ambient = 0

  DEVICES = ['/dev/rfcomm0','/dev/rfcomm1']

  def self.shutdown?
    @@shutdown
  end

  def self.shutdown!
    @@shutdown = true
  end

  def self.device=(d)
    @@device = d
  end

  def self.red_percent
    (@@red/255 * 100).to_i
  end

  def self.green_percent
    (@@green/255 * 100).to_i
  end

  def self.blue_percent
    (@@blue/255 * 100).to_i
  end

  def self.color_ratio
    {
      r: 1.to_f,
      g: @@green.to_f / @@red,
      b: @@blue.to_f / @@red
    }
  end

  def self.brightness(percent)

    ratios = LightStatus.color_ratio.sort{|a,b| b[1] <=> a[1]}

    return false if ratios.to_a[0][1] * percent > 255 ||
                    ratios.to_a[1][1] * percent > 255 ||
                    ratios.to_a[2][1] * percent > 255
    ratio = LightStatus.color_ratio
    LightStatus.set_color((ratio[:r] * percent).abs,(ratio[:g] * percent).abs,(ratio[:b] * percent).abs)
    puts "#{ratio[:r] * percent},#{ratio[:g] * percent},#{ratio[:b] * percent}"
  end

  def self.set_color(red,green,blue)
      @@red = red = red.to_i
      @@green = green = green.to_i
      @@blue = blue = blue.to_i
      red += 1
      green += 1
      blue += 1
      red = 255 if red > 255
      green = 255 if green > 255
      blue = 255 if blue > 255
      red = 1 if red < 1
      green = 1 if green < 1
      blue = 1 if blue < 1
      puts "#{red} #{green} #{blue} L#{red.chr}#{green.chr}#{blue.chr}"
      DEVICES.each do |d|
        if File.exist?(d)
          device_alt = SerialPort.new d, 9600, 8, 1, SerialPort::NONE
          device_alt.write("L#{red.chr}#{green.chr}#{blue.chr}")
          device_alt.close
        end
      end

  end

  def self.cycle
    DEVICES.each do |d|
      if File.exist?(d)
        device = SerialPort.new d, 9600, 8, 1, SerialPort::NONE
        device.write "D\r\n"
        device.close
      end
    end
  end

  def self.fade
    DEVICES.each do |d|
      if File.exist?(d)
        device = SerialPort.new d, 9600, 8, 1, SerialPort::NONE
        device.write "F\r\n"
        device.close
      end
    end
  end

  def self.html_color
    return "#{@@red.to_s(16).rjust(2,'0')}#{@@green.to_s(16).rjust(2,'0')}#{@@blue.to_s(16).rjust(2,'0')}"
  end
end

class RemoteControl
  include Celluloid
  attr_reader :serial_device
  def initialize(serial_device)
    @serial_device = serial_device
  end

  def start
    loop do
      if File.exist?(@serial_device)
        device = SerialPort.new @serial_device, 9600, 8, 1, SerialPort::NONE
        process_command(device.gets.chomp)
        device.close
      end
    end
  end

  def process_command command
    case command
      when "CYCLEON"
        LightStatus.cycle
      when "CYCLEOFF"
        LightStatus.set_color(255,0,0)
      when "FADE"
        LightStatus.fade
      when "OFF"
        LightStatus.set_color(0,0,0)


    end

  end

end

get '/lights' do
  hex = params[:hex]
  red = green = blue = 0
  red = hex[0..1].to_i(16)
  green = hex[2..3].to_i(16)
  blue = hex[4..5].to_i(16)
  LightStatus.set_color(red,green,blue)
end

get '/fade_lamp' do
  LightStatus.fade
  "ok!"
end

get '/cycle' do
  LightStatus.cycle
  "ok!"
end

get '/' do
  @color = '#000000'
  erb :index
end
