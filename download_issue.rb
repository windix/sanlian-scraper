require './lib'

if ARGV.length != 1
  abort("Usage: download_issue.rb <issue_id>")
end

issue_id = ARGV[0].to_i
fetch_issue(issue_id)
parse_issue(issue_id)
