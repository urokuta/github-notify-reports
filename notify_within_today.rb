require './notify_report'
hour = Time.now.getlocal("+09:00").hour
if (hour % 2) == 0
  NotifyReport.notify_today_issues
end
