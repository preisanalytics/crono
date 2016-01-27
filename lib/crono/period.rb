module Crono
  # Period describe frequency of jobs
  class Period

    def self.load(period_hash)
      self.from_h period_hash if period_hash
    end

    def self.dump(period)
      period.to_h if period
    end

    DAYS = [:monday, :tuesday, :wednesday, :thursday, :friday, :saturday,
            :sunday]

    def initialize(period, at: nil, on: nil, within: nil)
      @period = period
      @at_hour, @at_min = parse_at(at) if at
      @interval = Interval.parse(within) if within
      @on = parse_on(on) if on
    end

    def self.from_h(hash)
      hash = hash.symbolize_keys
      if hash[:period] =~ /^(\d{0,10})\.(year|month|week|day|hour|minute|second)s?$/
         period = $1.to_i.send($2)
      end
      new(period, at: hash[:at], on: hash[:on])
    end

    def next(since: nil)
      if @interval
        if since
          @next = @interval.next_within(since, @period)
        else
          return initial_next if @interval.within?(initial_next)
          @next = @interval.next_within(initial_next, @period)
        end
      else
        return initial_next unless since
        @next = @period.since(since)
      end
      @next = @next.beginning_of_week.advance(days: @on) if @on
      @next = @next.change(time_atts)
      return @next if @next.future?
      Time.now
    end

    def description
      desc = "every #{@period.inspect}"
      desc += " between #{@interval.from} and #{@interval.to} UTC" if @interval
      desc += format(' at %.2i:%.2i', @at_hour, @at_min) if @at_hour && @at_min
      desc += " on #{DAYS[@on].capitalize}" if @on
      desc
    end

    def to_h
      fail unless @period.is_a?(ActiveSupport::Duration) 
      hash = {}
      hash[:period] = @period.inspect.gsub(' ','.') 
      hash[:at] = "#{@at_hour}:#{@at_min}" if @at_hour and @at_min
      hash[:on] = @on
      hash
    end

    private

    def initial_next
      next_time = initial_day.change(time_atts)
      return next_time if next_time.future?
      @period.from_now.change(time_atts)
    end

    def initial_day
      return Time.now unless @on
      day = Time.now.beginning_of_week.advance(days: @on)
      return day if day.future?
      @period.from_now.beginning_of_week.advance(days: @on)
    end

    def parse_on(on)
      return on if on.is_a? Numeric
      day_number = DAYS.index(on)
      fail "Wrong 'on' day" unless day_number
      fail "period should be at least 1 week to use 'on'" if @period < 1.week
      day_number
    end

    def parse_at(at)
      if @period < 1.day && (at.is_a? String || at[:hour])
        fail "period should be at least 1 day to use 'at' with specified hour"
      end

      case at
      when String
        time = Time.parse(at)
        return time.hour, time.min
      when Hash
        return at[:hour], at[:min]
      else
        fail "Unknown 'at' format"
      end
    end

    def time_atts
      { hour: @at_hour, min: @at_min }.compact
    end
  end
end
