# Ripped without remorse from: https://github.com/cucumber/aruba/blob/master/lib/aruba/process.rb
# slightly modified for my purposes.
require 'childprocess'
require 'tempfile'
require 'shellwords'

class CLIProcess
  include Shellwords

  def initialize(cmd, exit_timeout = 0, io_wait = 1)
    @exit_timeout = exit_timeout
    @io_wait = io_wait
    @io_waited = false

    @cmd = cmd
    @process = nil
    @exit_code = nil
  end

  def run!(&block)
    @process = ChildProcess.build(*shellwords(@cmd))
    @out = Tempfile.new("binary-out")
    @err = Tempfile.new("binary-err")
    @process.io.stdout = @out
    @process.io.stderr = @err
    @process.duplex = true
    @exit_code = nil
    begin
      @process.start
    rescue ChildProcess::LaunchError => e
      raise LaunchError.new(e.message)
    end
    yield self if block_given?
  end

  def stdin
    @process.io.stdin
  end

  def output(keep_ansi = false)
    stdout(keep_ansi) + stderr(keep_ansi)
  end

  def stdout(keep_ansi = false)
    wait_for_io do
      @out.rewind
      filter_ansi(@out.read, keep_ansi)
    end
  end

  def stderr(keep_ansi = false)
    wait_for_io do
      @err.rewind
      filter_ansi(@err.read, keep_ansi)
    end
  end

  def read_stdout(keep_ansi = false)
    wait_for_io do
      @process.io.stdout.flush
      content = filter_ansi(open(@out.path).read, keep_ansi)
    end
  end

  def stop(reader, keep_ansi)
    return @exit_code unless @process
    unless @process.exited?
      @process.poll_for_exit(@exit_timeout)
    end
    reader.stdout stdout(keep_ansi)
    reader.stderr stderr(keep_ansi)
    @exit_code = @process.exit_code
    @process = nil
    @exit_code
  end

  def terminate(keep_ansi = false)
    if @process
      stdout(keep_ansi = false) && stderr(keep_ansi) # flush output
      @process.stop
      stdout(keep_ansi) && stderr(keep_ansi) # flush output
    end
  end

  private

  def wait_for_io(&block)
    if @process && !@io_waited
      sleep @io_wait
      @io_waited = true
    end
    yield
  end

  def filter_ansi(string, keep_ansi)
    keep_ansi ? string : string.gsub(/\e\[\d+(?>(;\d+)*)m/, '')
  end

end
