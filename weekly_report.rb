require './notify_report'
wday = Time.now.getlocal("+09:00").wday
# 月曜日
if wday == 1
  NotifyReport.lastweek_report
end
