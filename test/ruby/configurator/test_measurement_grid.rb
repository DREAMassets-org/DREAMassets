require "minitest/autorun"
require "time"
require "byebug"

lib_dir = "../../../lib/ruby"
require_relative "#{lib_dir}/measurement"
require_relative "#{lib_dir}/configurator/measurement_grid"

class TestMeasurementGrid < Minitest::Test
  def random_measurement_at(tag: nil, ts: Time.now, hex_z_acc: nil)
    ts_string = Time.at(ts.to_i).to_s
    tag ||= "AABBCCDD"
    hex_z_acc ||= "3111"
    Measurement.new(
      tag_id: tag,
      hex_temperature: "11",
      hex_x_acc: "1111",
      hex_y_acc: "2111",
      hex_z_acc: hex_z_acc,
      hex_rssi: "11",
      timestamp: ts_string
    )
  end

  def setup
    @empty_grid = MeasurementGrid.new(:z_acceleration)

    @grid = MeasurementGrid.new(:z_acceleration)
    [
      random_measurement_at(tag: "AABB", ts: Time.now + 4, hex_z_acc: 1000.to_s(16)),
      random_measurement_at(tag: "AABB", ts: Time.now + 8, hex_z_acc: 4000.to_s(16)),
      random_measurement_at(tag: "CCBB", ts: Time.now + 6, hex_z_acc: 2000.to_s(16))
    ].each { |m| @grid.add_entry(m) }
  end

  def test_default
    assert_equal(@empty_grid.tags, [])
    assert_nil(@empty_grid.length)
  end

  def test_tags_and_size
    assert_equal(@grid.tags, ["BBAA", "BBCC"])
    assert_equal(@grid.length, 9)
  end

  def test_timestamps; end

  def test_values
    assert_equal(@grid.values("BBAA"), [nil, nil, nil, nil, 1.0302734375, 1.0302734375, 1.0302734375, 1.0302734375, 0.1220703125])
    assert_equal(@grid.values("BBCC"), [nil, nil, nil, nil, nil, nil, 0.06103515625])
    assert_nil(@grid.values("UNKNOWNTAG"))
  end
end
