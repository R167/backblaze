module Helpers
  def file_list(size: 10, next_item: nil)
    files = []
    size.times do
      files << {
        "action" => "upload",
        "fileId" => SecureRandom.uuid.tr("-", "_"),
        "fileName" => "random_file_#{rand(0..10000)}.txt",
        "size" => rand(10..1000),
        "uploadTimestamp" => Time.now.to_i
      }
    end

    {
      "files" => files,
      "nextFileName" => next_item
    }
  end

  ##
  # Evaluate block in a forked process.
  #
  # Uses Marshal to return the value returned from the block
  # @yieldreturn [T] any value
  # @return [T] result of block
  def eval_in_fork(&block)
    r, w = IO.pipe

    fork do
      r.close
      Marshal.dump(block.call, w)
      w.close
      exit!(0)
    end

    w.close
    forked_return = Marshal.load(r)
    r.close
    forked_return
  end
end
