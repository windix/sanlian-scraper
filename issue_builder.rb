require "./lib"
require 'reverse_markdown'
require 'yaml'
require 'pp'

$category_id_to_skip = [
  239, # Talk三联
  240, # Shot三联
  241, # 主编说
  242, # 封面大使
  243, # 荐读
]

def content_html_to_markdown(html)
  html.gsub!(/<span.*?>(.*?)<\/span>/, '\\1')
  html.gsub!(/<a.*?>.*<\/a>/, '') # remove links
  html.gsub!('!magzinePic', '')
  html.gsub!('<center></center>', '')

  markdown = ReverseMarkdown.convert html
end

def build_file_name(category, sub_category, title)
  [
    category,
    sub_category,
    title.sub('|', '-'),
  ].compact.join('-')
end

def build_issue_article_list(issue_id)
  issue_summary = parse_json_file(list_json_location)['model']['list'].find {
    |issue| issue['id'] == issue_id
  }

  abort("Cannot find issue by issue_id: #{issue_id}") unless issue_summary

  issue_data = parse_json_file(issue_json_location(issue_id))

  {
    'name' => issue_summary['name'],
    'pic_url' => issue_summary['pic'],
    'total_num' => issue_summary['totalQiakn'].to_i, # typo from source
    'year_num' => issue_summary['qikanNum'].to_i,
    'year' => issue_summary['qikanYear'].to_i,
    'month' => issue_summary['qikanMonth'].to_i,
    'categories' => issue_data['model']['list'].map do |lanmu|
      category_id = lanmu['lanmuId'].to_i
      next if $category_id_to_skip.include?(category_id)

      category = lanmu['lanmu']

      articles = lanmu['list'].map do |article|
        article_id = article['id'].to_i
        sub_category = article['subLanmu']
        url = "#{build_file_name(category, sub_category, article['title'])}.html"

        pic_url = article['pic']

        {
          'title' => article['title'],
          'sub_category' => sub_category,
          'pic_url' => pic_url,
          'url' => url
        }
      end

      {
        'category' => category,
        'articles' => articles,
      }
    end.compact
  }
end

def build_issue_article_list_page(issue_article_list, file_base_path)
  file_path = "#{file_base_path}/index.md"

  issue_article_list['layout'] = 'article_list'

  output = <<-HEREDOC
#{YAML.dump(issue_article_list)}
---

HEREDOC

  File.write(file_path, output)
  puts "Generated #{file_path}"
end

def build_article_pages(issue_id, file_base_path)
  issue_data = parse_json_file(issue_json_location(issue_id))

  issue_data['model']['list'].each do |lanmu|
    category_id = lanmu['lanmuId'].to_i

    next if $category_id_to_skip.include?(category_id)

    category = lanmu['lanmu']

    lanmu['list'].each do |article|
      article_id = article['id'].to_i
      sub_category = article['subLanmu']
      file_path = "#{file_base_path}/#{build_file_name(category, sub_category, article['title'])}.md"

      article_brief_data = parse_json_file("#{issue_location(issue_id)}/#{article_id}_brief.json")
      article_detail_data = parse_json_file("#{issue_location(issue_id)}/#{article_id}_detail.json")

      title = article_brief_data['model']['articleName']
      sub_title = article_brief_data['model']['articleTitle']
      source = article_brief_data['model']['courseSource']
      author = article_brief_data['model']['authorName']

      desc = article_brief_data['model']['articleDaodu']
      desc = "> #{desc}" unless desc.empty?

      content = case category_id
                when 33 # 天下
                  ""
                when 37 # 好东西
                  ""
                else
                  content_html_to_markdown(article_detail_data['model']['content'])
                end

      output = <<-HEREDOC
---
layout: article
title: #{title}
sub-title: #{sub_title}
author: #{author}
categories: #{category} #{sub_category}
source: #{source}
---
#{desc}

#{content}

HEREDOC

      File.write(file_path, output)
      puts "Generated #{file_path}"
    end
  end
end

if ARGV.length != 1
  abort("Usage: issue_builder.rb <issue_id>")
end

issue_id = ARGV[0].to_i

issue_article_list = build_issue_article_list(issue_id)

# adding padding 0 to year_num, i.e. "1995/01"
issue_path = "#{issue_article_list['year']}/#{"%02d" % issue_article_list['year_num']}"

file_base_path = "jekyll-web/issues/#{issue_path}"

FileUtils.mkdir_p file_base_path

build_issue_article_list_page(issue_article_list, file_base_path)

build_article_pages(issue_id, file_base_path)
