require './github_stats'
require 'artii'
require 'dotenv'
require 'slack-notifier'
class NotifyReport
  class << self
    def authors
      authors = ENV['AUTHORS'].try(:split, ',')
      authors ||= []
    end
    
    def non_commit_notify_targets
      targets = ENV['NON_COMMIT_NOTIFY_TARGETS'].try(:split, ',')
      targets ||= []
    end

    def filter_repo_names
      repos = ENV['FILTER_REPO_NAMES'].try(:split, ',')
      repos ||= []
    end

    def yesterday_report
      Dotenv.load
      artii = Artii::Base.new
      gs = GithubStats.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      gs.set_filter_repo_names(filter_repo_names)
      today = Time.now.getlocal('+09:00').beginning_of_day
      yesterday = today - 1.day
      _name_commits = gs.name_mapped_commits(date: yesterday)
      text = ""
      text += "```\n"
      text += artii.asciify("DAILY  REPORTS  #{yesterday.to_date.strftime('%^b %d')}")
      text += "```\n"
      text += "本日も開発お疲れ様:laughing::heart: 本日のレポートだよっ\n"
      name_commits = _name_commits.select{|nc| authors.include?(nc[:name])}
      name_commits.each do |name_commit|
        name = name_commit[:name]
        # pull reqコミットは省く
        commits = name_commit[:commits].select{|c| ! c[:commit][:message].start_with?("Merge pull request")}
        text += "<@#{name}|#{name}>さんの今日のコミット\n"
        text += "コミット数: `#{commits.count}`\n"
        text += "```\n"
        text += commits.map{|c| GithubStats.formatted_commit(c)}.join("\n")
        text += "\n"
        text += "```\n"
        text += "\n"
      end
      slack_say(text)
      ###############################
      # issues
      ###############################
      text = ""
      text += "===============================================================\n"
      text += "今日みんなのクローズしたタスク一覧だよっ:heart: また1つ改善されたね:laughing:\n"
      name_issues = gs.name_mapped_issues(state: 'closed', since: yesterday)
      name_issues.each do |name_issue|
        name = name_issue[:name]
        issues = name_issue[:issues]
        text += "<@#{name}|#{name}>さんの今日クローズしたタスク\n"
        text += "```\n"
        text += issues.map{|i| GithubStats.formatted_issue(i)}.join("\n")
        text += "\n"
        text += "```\n"
      end
      slack_say(text)

      ###############################
      # no commit user
      ###############################

      text = ""
      text += "===============================================================\n"
      text += ">本日コミット出来なかったユーザー\n"
      non_commit_users = non_commit_notify_targets.select{|name| name_commits.find{|n| n[:name] == name} == nil}
      if non_commit_users.empty?
        text += "すごい！今日はみんながコミットしたんだね:100::heart: 明日も頑張ろう！:hugging_face:"
      else
        text += non_commit_users.map{|name| "<@#{name}|#{name}>さん"}.join(", ")
        text += "\n明日はコミット出来るように頑張ってね:cry:"
      end
      slack_say(text)
      text
    end

    def notify_today_issues
      Dotenv.load
      gs = GithubStats.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      gs.set_filter_repo_names(filter_repo_names)
      name_issues = gs.name_mapped_issues(state: 'open', labels: 'notify-within-today')
      if name_issues.count != 0
        text = ""
        text += "===============================================================\n"
        text += "かすみだよ！タスクのお知らせをするね:smile:\n"
        name_issues.each do |name_issue|
          name = name_issue[:name]
          issues = name_issue[:issues]
          text += "<@#{name}|#{name}>さんは `今日中` にこんなタスクを終わらせるっていってたよ:heart:\n"
          text += "```\n"
          text += issues.map{|i| GithubStats.formatted_issue(i)}.join("\n")
          text += "```\n"
        end
        text += "もし忘れても、私が何度もお知らせするから頑張ってね:heart:"
        slack_say(text, channel: "#reminder-daily")
      end
    end

    def notify_this_week_issues
      Dotenv.load
      gs = GithubStats.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      gs.set_filter_repo_names(filter_repo_names)
      name_issues = gs.name_mapped_issues(state: 'open', labels: 'notify-within-this-week')
      text = ""
      text += "===============================================================\n"
      text += "かすみだよ！今日もお疲れ様！タスクのお知らせをするね:smile:\n"
      if name_issues.count == 0
        text += "すごい！今週やるべきタスクはないみたい！:heart:\n"
        text += "私、もっと頑張って仕事作るね:heart:\n"
      else
        name_issues.each do |name_issue|
          name = name_issue[:name]
          issues = name_issue[:issues]
          text += "<@#{name}|#{name}>さんは `今週中` にこんなタスクを終わらせるっていってたよ:heart:\n"
          text += "```\n"
          text += issues.map{|i| GithubStats.formatted_issue(i)}.join("\n")
          text += "```\n"
        end
        text += "ちゃんと今週中に終わらせてね:heart:"
      end
      slack_say(text, channel: "#reminder")
    end
    
    def notify_non_commit_user_on_18
      Dotenv.load
      gs = GithubStats.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      gs.set_filter_repo_names(filter_repo_names)
      today = Time.now.getlocal('+09:00').beginning_of_day
      _name_commits = gs.name_mapped_commits(date: today)
      name_commits = _name_commits.select{|nc| authors.include?(nc[:name])}
      text = ""
      text += "===============================================================\n"
      text += "こんばんは！18:00です:heart:！\n"
      text += "今日ももうこんな時間だね。コミットは済んだかな？\n"
      text += "まだコミットしていない人は、"
      non_commit_users = non_commit_notify_targets.select{|name| name_commits.find{|n| n[:name] == name} == nil}
      text += non_commit_users.map{|name| "<@#{name}|#{name}>さん"}.join(", ")
      text += " だよ:star: \n集計は0時までだから、早めにコミットしてね:heart:"
      slack_say(text)
    end

    def lastweek_report
      Dotenv.load
      artii = Artii::Base.new
      gs = GithubStats.new(access_token: ENV['GITHUB_ACCESS_TOKEN'])
      gs.set_filter_repo_names(filter_repo_names)
      today = Time.now.getlocal('+09:00').beginning_of_day
      from = (today - 8.days)
      to = today
      _name_commits = gs.name_mapped_commits(from: from, to: to)
      name_commits = _name_commits.select{|nc| authors.include?(nc[:name])}
      text = ""
      text += "```\n"
      text += artii.asciify("WEEKLY  REPORTS  #{from.to_date.strftime('%^b %d')}")
      text += "```\n"
      text += "今週も開発お疲れ様でした:laughing::heart: 今週のレポートだよっ\n"
      slack_say(text)
      name_commits.each do |name_commit|
        text = ""
        name = name_commit[:name]
        # pull reqコミットは省く
        commits = name_commit[:commits].select{|c| ! c[:commit][:message].start_with?("Merge pull request")}
        text += "<@#{name}|#{name}>さんの今週のコミット\n"
        text += "コミット数: `#{commits.count}`\n"
        text += "```\n"
        text += commits.map{|c| GithubStats.formatted_commit(c)}.join("\n")
        text += "\n"
        text += "```\n"
        text += "\n"
        slack_say(text)
      end

      ###############################
      # issues
      ###############################
      text = ""
      text += "===============================================================\n"
      text += "今週みんながクローズしたタスク一覧だよっ:heart: たくさん改善されたね:laughing:\n"
      slack_say(text)
      name_issues = gs.name_mapped_issues(state: 'closed', since: from)
      name_issues.each do |name_issue|
        name = name_issue[:name]
        issues = name_issue[:issues]
        text = ""
        text += "<@#{name}|#{name}>さんの今週クローズしたタスク\n"
        text += "```\n"
        text += issues.map{|i| GithubStats.formatted_issue(i)}.join("\n")
        text += "\n"
        text += "```\n"
        slack_say(text)
      end
      text
    end

    def slack_say(text, channel: "#reports")
      client = Slack::Notifier.new ENV["SLACK_WEB_HOOK"],
        channel: channel,
        username: "有村架純ちゃん"
      client.ping(text.force_encoding("UTF-8"))
    end

  end
end
