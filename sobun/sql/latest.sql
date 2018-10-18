select 
  batch_id,
  datetime(timestamp, 'unixepoch', 'localtime') as human_time,
  timestamp,
  tag_id,       
  measurements,
  hci,
  rssi
from measurements
order by timestamp desc
limit 20;
