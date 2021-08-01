module Phase
  class View(S, R) < ReadonlyView(S, R)
    def self.of(src : S, region : Enumerable? = nil) : self
      case src
      when ReadonlyView
        return src.view(region)
      else
        new_view = View(S, typeof(src.sample)).new(src)
        new_view.restrict_to(region) if region
        return new_view
      end
    end
  end
end
