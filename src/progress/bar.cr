require "log"

module Progress
  class Bar
    @log = ::Log.for("progress.bar")
    def initialize(@title="",@ticks=100,@width=50,@steps=1,@char="=",@show_percentage=true,@show_memory=true,@show_time=true,@show_remaining=true)
      @position = 0
      @start = Time.monotonic
      @custom = Proc(String).new { "" }
      redraw unless @ticks == 0
    end
    def custom_info(&block : -> String)
      @custom = block
    end
    def tick
      unless @position >= @ticks
        @position += 1
      end
      redraw
    end
    def redraw
      return if @log.level != Log::Severity::Notice
      if @position == 0 || @position == @ticks || @position % @steps == 0
        pos = state
        per = percentage
        t = time
        spe = t / per
        memory = GC.stats.total_bytes.to_i64
        begin
          line = "#{@title}[#{@char * pos}#{" " * (@width - pos)}]"
          line = "#{line} #{sprintf "%.2f", per}%" if @show_percentage
          line = "#{line} / #{sprintf "%.2f", memory / 1000000}MB" if @show_memory
          line = "#{line} #{time_style(t)}" if @show_time
          line = "#{line} --> #{time_style(spe * (100.to_f - per))}" if @show_remaining
          line = "#{line} #{@custom.call}"
          line = "#{line}\r"
          print line
          puts "" if @position == @ticks
        rescue exception
          #puts exception.message
        end
      end
    end
    private def state
      (@width * @position.to_f / @ticks.to_f).round.to_i
    end
    private def percentage
      @position.to_f * 100.to_f / @ticks.to_f
    end
    private def time
      (Time.monotonic - @start).total_milliseconds / 1000.to_f
    end
    private def time_style(t)
      unless t == Float64::INFINITY
        Time::Span.new(seconds: t.to_i)
      end
    end
  end
end
