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
  # Multi-language plugin removed
  # gem "jekyll-assets", "~> 3.0.12" # Disable, not compatible with Ruby 3.4
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

# Use a simple solution to monitor directory changes
gem "webrick"

# Gems required for Ruby 3.4 compatibility
gem "csv"
gem "bigdecimal"
#gem "fiddle"  # Need to resolve fiddle/import warning

# Lock `http_parser.rb` gem to `v0.6.x` on JRuby builds since newer versions of the gem
# do not have a Java counterpart.
gem "http_parser.rb", "~> 0.6.0", :platforms => [:jruby]
