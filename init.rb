require 'redmine'

require 'dispatcher'
Dispatcher.to_prepare :redmine_gantt_date do

  #unless Redmine::Export::PDF.included_modules.include? PDFExtend
  #  Redmine::Export::PDF.send(:include, PDFExtend)
  #end
  unless Redmine::Helpers::Gantt.included_modules.include? GanttExtend
    Redmine::Helpers::Gantt.send(:include, GanttExtend)
  end

end

Redmine::Plugin.register :redmine_gantt_date do
  name 'Redmine Gantt Date plugin'
  author 'F.S.D.'
  description 'This plugin is display days on gantt chart'
  version '0.1'
  url 'http://github.com/FSD/GanttDate'
  author_url 'http://www.f-s-d.jp/'
end
