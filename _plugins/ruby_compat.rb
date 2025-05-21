# Ruby 3.3+u517cu5bb9u6027u8865u4e01
# u89e3u51b3tainted?u65b9u6cd5u5728Ruby 3.3+u4e2du88abu79fbu9664u7684u95eeu9898

# u5728Stringu548cObjectu4e2du6dfbu52a0tainted?u76f8u5173u65b9u6cd5
class String
  unless method_defined?(:tainted?)
    def tainted?
      false
    end
  end
  
  unless method_defined?(:taint)
    def taint
      self
    end
  end
  
  unless method_defined?(:untaint)
    def untaint
      self
    end
  end
end

class Object
  unless method_defined?(:tainted?)
    def tainted?
      false
    end
  end
  
  unless method_defined?(:taint)
    def taint
      self
    end
  end
  
  unless method_defined?(:untaint)
    def untaint
      self
    end
  end
end

# u76f4u63a5u66ffu6362Liquid::Variableu7c7bu7684taint_checku65b9u6cd5
module TaintFixer
  def self.apply_fix
    if defined?(Liquid::Variable) && Liquid::Variable.method_defined?(:taint_check)
      Liquid::Variable.class_eval do
        def taint_check(context, obj)
          # u7a7au5b9eu73b0uff0cu8df3u8fc7u6240u6709u68c0u67e5
          return
        end
      end
      puts "[u517cu5bb9u6027u8865u4e01] u5df2u6210u529fu8986u76d6Liquid::Variable#taint_checku65b9u6cd5"
    end
  end
end

# u5728Jekyllu542fu52a8u540eu7acbu5373u5e94u7528u8865u4e01
Jekyll::Hooks.register :site, :after_init do |site|
  TaintFixer.apply_fix
end
