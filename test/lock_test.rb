require 'test/unit'
require 'resque'
require 'resque/plugins/lock'

$counter = 0

class LockTest < Test::Unit::TestCase
  class Job
    extend Resque::Plugins::Lock
    @queue = :lock_test

    def self.lock_timeout
      1
    end

    def self.perform
      raise "Woah woah woah, that wasn't supposed to happen"
    end
  end

  def setup
    Resque.redis.del('queue:lock_test')
    Resque.redis.del(Job.lock)
    Resque.redis.del(JobWithOptionalQueueOnlyLocking.lock)
  end

  def test_lint
    assert_nothing_raised do
      Resque::Plugin.lint(Resque::Plugins::Lock)
    end
  end

  def test_version
    major, minor, patch = Resque::Version.split('.')
    assert_equal 1, major.to_i
    assert minor.to_i >= 17
    assert Resque::Plugin.respond_to?(:before_enqueue_hooks)
  end

  def test_lock
    3.times { Resque.enqueue(Job) }

    assert_equal 1, Resque.redis.llen('queue:lock_test')
  end

  def test_deadlock
    now = Time.now.to_i

    Resque.redis.set(Job.lock, now+60)
    Resque.enqueue(Job)
    assert_equal 0, Resque.redis.llen('queue:lock_test')

    Resque.redis.set(Job.lock, now-1)
    Resque.enqueue(Job)
    assert_equal 1, Resque.redis.llen('queue:lock_test')

    sleep 3
    Resque.enqueue(Job)
    assert_equal 2, Resque.redis.llen('queue:lock_test')
  end

  class JobWithOptionalQueueOnlyLocking
    extend Resque::Plugins::Lock
    @queue = :lock_test
    class << self
      attr_accessor :unlock_while_performing
    end

    def self.perform
      Resque.enqueue(self)
      if unlock_while_performing
        raise 'this job should be queueable while it is running' unless
          Resque.redis.llen('queue:lock_test') == 1
      else
        raise 'this job should NOT be queueable while it is running' unless
          Resque.redis.llen('queue:lock_test') == 0
      end
    end
  end

  def test_queue_is_normally_locked_when_job_running
    JobWithOptionalQueueOnlyLocking.unlock_while_performing = nil
    Resque.enqueue(JobWithOptionalQueueOnlyLocking)
    job  = Resque.reserve('lock_test')
    job.perform
  rescue => e
    flunk e.message
  end

  def test_queue_only_locking
    JobWithOptionalQueueOnlyLocking.unlock_while_performing = true
    Resque.enqueue(JobWithOptionalQueueOnlyLocking)
    job  = Resque.reserve('lock_test')
    job.perform
  rescue => e
    flunk e.message
  end
end
