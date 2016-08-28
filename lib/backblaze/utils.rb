module Backblaze::Utils
  def underscore(word)
    word.to_s.
      gsub(/([A-Z\d]+)([A-Z][a-z])/,'\1_\2').
      gsub(/([a-z\d])([A-Z])/,'\1_\2').
      tr("-", "_").
      downcase
  end

  def camelize(word, capitalize=false)
    word = word.to_s
    "#{capitalize ? word[0, 1].upcase : word[0, 1].downcase}#{word.split('_').map(&:capitalize).join('')[1..-1]}"
  end

  def limit(user, range)
    if user < range.first
      range.first
    elsif user > range.last
      range.last
    else
      user
    end
  end

  def retry_block(attempts: 1, errors: [StandardError], raise_last: true, &block)
    attempts -= 1
    block.call(count)
  rescue *errors => e
    if attempts > 0
      retry
    elsif raise_last
      raise e
    end
  end

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    include Backblaze::Utils
  end

  class << self
    include Backblaze::Utils
  end
end
