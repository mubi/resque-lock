Resque Lock
===========

A [Resque][rq] plugin. Requires Resque 1.7.0.

If you want only one instance of your job queued at a time, extend it
with this module.


For example:

    require 'resque/plugins/lock'

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      def self.perform(repo_id)
        heavy_lifting
      end
    end

While this job is queued or running, no other UpdateNetworkGraph
jobs with the same arguments will be placed on the queue.

If you want to define the key yourself you can override the
`lock` class method in your subclass, e.g.

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock

      Run only one at a time, regardless of repo_id.
      def self.lock(repo_id)
        "network-graph"
      end

      def self.perform(repo_id)
        heavy_lifting
      end
    end

The above modification will ensure only one job of class
UpdateNetworkGraph is queued at a time, regardless of the
repo_id. Normally a job is locked using a combination of its
class name and arguments.

If you don't want to have to wait until a job has completed
before being able to enqueue another job with the same
arguments, you can set the `unlock_while_performing` flag:

    class UpdateNetworkGraph
      extend Resque::Plugins::Lock
      @unlock_while_performing = true

      # etc ...
    end

With this option set, another job of the same type with the
same arguments can be queued even while the original one is
being performed. Otherwise, the queue will remain locked
until the job has completed. This option can be useful if you
know that some data has changed which the currently-performing
job will not have taken into account.

[rq]: http://github.com/defunkt/resque
