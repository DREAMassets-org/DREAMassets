class MeasurementGrid
  def initialize(attribute)
    @grid = {}
    @start_time = Time.now
    @attribute = attribute
  end

  def tags
    @grid.keys
  end

  def length
    @grid.map { |_tag_id, entries| entries.length }.max
  end

  def add_entry(measurement)
    tag_entries = @grid[measurement.tag_id] || Array.new
    num_entries = measurement.timestamp.to_i - @start_time.to_i
    num_entries.times do |ts|
      if tag_entries[ts].nil?
        if ts > 0
          tag_entries[ts] = tag_entries[ts - 1]
        else
          ts = 0
        end
      end
    end
    tag_entries[num_entries] = measurement.send(@attribute) || 0
    @grid[measurement.tag_id] = tag_entries
  end

  def values(tag)
    @grid[tag]
  end

  def timestamps
    @grid.keys.times.map
  end
end
