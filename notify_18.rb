require './notify_report'
hour = Time.now.getlocal("+09:00").hour
if hour == 18
  NotifyReport.notify_non_commit_user_on_18
end
