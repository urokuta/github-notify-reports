require './notify_report'
# hour = Time.now.getlocal("+09:00").hour
# min = Time.now.getlocal("+09:00").min
# if (hour == 23 && min > 40) || (hour == 0 && min < 20)
NotifyReport.yesterday_report
# end
