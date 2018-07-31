class MeasurementGrid
  FLIPPED_THRESHOLD = 0.5

  def initialize(attribute, window_size: 80, expected_tags: nil)
    @grid = {}
    @start_time = Time.now
    @attribute = attribute
    @window_size = window_size
    @expected_tags = expected_tags

    (@expected_tags || []).each do |tag|
      @grid[tag] = []
    end
  end

  def tags
    @grid.keys
  end

  def length
    @grid.map { |_tag, entries| entries.length }.max
  end

  # have we recorded data for all the expected tags
  def stabilizing?
    @expected_tags.any? { |tag| [values(tag)].flatten.compact.empty? }
  end

  def latest_active_tags_in_order
    tags.each_with_object({}) do |tag, memo|
      last_activity = flipped(tag).reverse.find_index("|")
      memo[tag] = last_activity if last_activity
    end.sort_by { |_tag, order| -order }.map(&:first)
  end

  def <<(measurement)
    add_entry(measurement)
    self
  end

  def add_entry(measurement)
    tag_entries = @grid[measurement.tag_id] || Array.new
    num_entries = measurement.timestamp.to_i - @start_time.to_i
    num_entries.times do |ts|
      next unless ts > 0
      tag_entries[ts] = tag_entries[ts - 1] if tag_entries[ts].nil?
    end
    tag_entries[num_entries] = measurement.send(@attribute) || 0
    @grid[measurement.tag_id] = tag_entries.last(@window_size)
  end

  def flipped(tag)
    # more than FLIPPED_THRESHOLD g difference in acceleration which should represent a flip
    derivatives(tag).map { |v| (v.abs > FLIPPED_THRESHOLD) ? "|" : "." }
  end

  def derivatives(tag)
    derivative(values(tag))
  end

  def values(tag)
    @grid[tag]
  end

  private

  def derivative(data)
    return [] if data.length < 2
    data.map { |v| v }.each_cons(2).map do |x, y|
      (!y || !x) ? 0 : (y.to_f - x.to_f)
    end
  end
end
