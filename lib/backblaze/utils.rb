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
