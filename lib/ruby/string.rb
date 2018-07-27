# Add a methods to the ruby String class
class String
  # return a string as a set of byte pairs (assuming a hex input string)
  #
  # Ex.
  # > "abcdef00".as_byte_pairs
  # => "abcd ef00"
  def as_byte_pairs
    chars.each_slice(4).map(&:join).join(" ")
  end
end
