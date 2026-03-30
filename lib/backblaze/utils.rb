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

  def response_to_hash(response)
    Hash[response.map { |k, v| [underscore(k).to_sym, v] }]
  end

  # Percent-encode a file name for B2 headers.
  # Preserves '/' as literal (B2 uses it as path separator).
  # Encodes spaces as %20, '+' as %2B, per B2 spec.
  def b2_encode_file_name(name)
    name.split('/').map { |segment|
      URI.encode_www_form_component(segment).gsub('+', '%20')
    }.join('/')
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
