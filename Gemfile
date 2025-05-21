# frozen_string_literal: true

source "http://gems.ruby-china.com/"

gem "jekyll", "= 3.10.0"
gem "liquid", "= 4.0.4"
gem "github-pages", "= 232", group: :jekyll_plugins
gem "minima", "~> 2.5"

# Jekyll plugins
group :jekyll_plugins do
  gem "jekyll-feed", "= 0.17.0"
  gem "jekyll-seo-tag", "= 2.8.0"
  gem "jekyll-sitemap", "= 1.4.0"
  gem "jekyll-paginate", "= 1.1.0"
  # 多语言插件已移除
  # gem "jekyll-assets", "~> 3.0.12" # 禁用，与Ruby 3.4不兼容
  gem "kramdown-parser-gfm", "= 1.1.0"
 end

# Windows and JRuby does not include zoneinfo files, so bundle the tzinfo-data gem
# and associated library.
platforms :mingw, :x64_mingw, :mswin, :jruby do
  gem "tzinfo", "~> 1.2"
  gem "tzinfo-data"
end

# Performance-booster for watching directories on Windows
# wdm 0.1.1与Ruby 3.4不兼容，暂时注释掉
# gem "wdm", "~> 0.1.1", :platforms => [:mingw, :x64_mingw, :mswin]

# 使用更简单的解决方案来监控目录变化
gem "webrick"

# Ruby 3.4兼容性所需的gem
gem "csv"
gem "bigdecimal"
#gem "fiddle"  # 需要解决fiddle/import警告

# Lock `http_parser.rb` gem to `v0.6.x` on JRuby builds since newer versions of the gem
# do not have a Java counterpart.
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]
