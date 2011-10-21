module GanttExtend
  require 'date'

  class PDF
    MaxCharactorsForSubject = 45
    TotalWidth = 280
    LeftPaneWidth = 70

    def self.right_pane_width
      TotalWidth - LeftPaneWidth
    end
  end

  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      # 本家メソッドを上書き
      #alias_method_chain :html_task, :expect
      #alias_method_chain :subject_for_project, :expect
      alias_method_chain :to_pdf, :expect
      alias_method_chain :pdf_task, :expect
      alias_method_chain :pdf_subject, :expect

      #PDFガントチャートの線が微妙にズレる不具合を修正(floor)
      alias_method_chain :coordinates, :expect

    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def subject_for_project_with_expect(project,options)
      subject = "<H2>SUBJECT</H2>" 
      html_subject(options,subject, :css => "project-name")
    end

    def html_task_with_expect(params, coords, options={})
      output = ""
      output << "<H2>TEST</H2>"
      @lines << output
      output
    end




    #------------------------------------------------------
    # 線の高さ(height)を変更した
    #------------------------------------------------------
    def pdf_subject_with_expect(params, subject, options={})

      params[:pdf].SetFontStyle('B',5)
      params[:pdf].SetY(params[:top])
      params[:pdf].SetX(15)

      char_limit = PDF::MaxCharactorsForSubject - params[:indent]
      params[:pdf].RDMCell(params[:subject_width]-15, 3, (" " * params[:indent]) +  subject.to_s.sub(/^(.{#{char_limit}}[^\s]*\s).*$/, '\1 (...)'), "LR")

      params[:pdf].SetY(params[:top])
      params[:pdf].SetX(params[:subject_width])
      params[:pdf].RDMCell(params[:g_width], 3, "", "LR")

    end


    #------------------------------------------------------
    # 線の高さ(height)を変更した
    #------------------------------------------------------
    def pdf_task_with_expect(params, coords, options={})

      height = options[:height] || 1.5
      h_margin = ( 3 - height ) / 2
      
      if coords[:bar_start] && coords[:bar_end]
        params[:pdf].SetY(params[:top] + h_margin)
        params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
        params[:pdf].SetFillColor(200,200,200)
        params[:pdf].RDMCell(coords[:bar_end] - coords[:bar_start], height, "", 0, 0, "", 1)

        if coords[:bar_late_end]
          params[:pdf].SetY(params[:top] + h_margin)
          params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
          params[:pdf].SetFillColor(255,100,100)
          params[:pdf].RDMCell(coords[:bar_late_end] - coords[:bar_start], height, "", 0, 0, "", 1)
        end
        if coords[:bar_progress_end]
          params[:pdf].SetY(params[:top] + h_margin)
          params[:pdf].SetX(params[:subject_width] + coords[:bar_start])
          params[:pdf].SetFillColor(90,200,90)
          params[:pdf].RDMCell(coords[:bar_progress_end] - coords[:bar_start], height, "", 0, 0, "", 1)
        end
      end
      # Renders the markers
      if options[:markers]
        if coords[:start]
          params[:pdf].SetY(params[:top] + h_margin)
          params[:pdf].SetX(params[:subject_width] + coords[:start] - height / 2)
          params[:pdf].SetFillColor(50,50,200)
          params[:pdf].RDMCell(height, height, "", 0, 0, "", 1)
          #options[:fill] = 1;
          #params[:pdf].Circle(params[:pdf].GetX() + 140 ,params[:pdf].GetY() + height / 2 ,h_margin * 1.5 ,options)
        end
        if coords[:end]
          params[:pdf].SetY(params[:top] + h_margin)
          params[:pdf].SetX(params[:subject_width] + coords[:end] + 3 )
          params[:pdf].SetFillColor(50,50,200)
          params[:pdf].RDMCell(height, height, "", 0, 0, "", 1)
        end
      end
      # Renders the label on the right
      #if options[:label]
      #  params[:pdf].SetX(params[:subject_width] + (coords[:bar_end] || 0) + 5)
      #  params[:pdf].RDMCell(30, 2, options[:label])
      #end
    end

    #------------------------------------------------------
    # 日付出力を追加
    #------------------------------------------------------
    def to_pdf_with_expect

      require 'calendar/japanese/holiday'

      pdf = ::Redmine::Export::PDF::ITCPDF.new(current_language)
      pdf.SetTitle("#{l(:label_gantt)} #{project}")
      pdf.alias_nb_pages
      pdf.footer_date = format_date(Date.today)
      pdf.AddPage("L")
      pdf.SetFontStyle('B',12)
      pdf.SetX(15)
      pdf.RDMCell(PDF::LeftPaneWidth, 20, project.to_s)
      pdf.Ln
      pdf.SetFontStyle('B',9)
      
      pdf.SetLineWidth(0.1)

      subject_width = PDF::LeftPaneWidth
      header_height = 3

      headers_height = header_height
      show_weeks = false
      show_days = false

      if self.months < 7
        show_weeks = true
        headers_height = 2*header_height
        if self.months < 5
          show_weeks = false
          show_days = true
          headers_height = 3*header_height
        end
      end

      g_width = PDF.right_pane_width
      zoom = (g_width) / (self.date_to - self.date_from + 1)
      g_height = 120
      t_height = g_height + headers_height

      y_start = pdf.GetY

      # Months headers
      pdf.SetFontStyle('B',5)
      month_f = self.date_from
      left = subject_width
      height = header_height
      self.months.times do
        width = ((month_f >> 1) - month_f) * zoom
        pdf.SetY(y_start)
        pdf.SetX(left)
        pdf.RDMCell(width, height, "#{month_f.year}-#{month_f.month}", "LTR", 0, "C")
        left = left + width
        month_f = month_f >> 1
      end

      # Weeks headers
      if show_weeks
        pdf.SetFontStyle('B',5)
        left = subject_width
        height = header_height
        if self.date_from.cwday == 1
          # self.date_from is monday
          week_f = self.date_from
        else
          # find next monday after self.date_from
          week_f = self.date_from + (7 - self.date_from.cwday + 1)
          width = (7 - self.date_from.cwday + 1) * zoom-1
          pdf.SetY(y_start + header_height)
          pdf.SetX(left)
          pdf.RDMCell(width + 1, height, "", "LTR")
          left = left + width+1
        end
        while week_f <= self.date_to
          width = (week_f + 6 <= self.date_to) ? 7 * zoom : (self.date_to - week_f + 1) * zoom
          pdf.SetY(y_start + header_height)
          pdf.SetX(left)
          pdf.RDMCell(width, height, (width >= 5 ? week_f.cweek.to_s : ""), "LTR", 0, "C")
          left = left + width
          week_f = week_f+7
        end
      end

      # Days headers
      if show_days
        left = subject_width
        height = header_height
        wday = self.date_from.cwday
        day_num = self.date_from
        if self.months < 4
          pdf.SetFontStyle('B',5)
        else
          pdf.SetFontStyle('B',3)
        end

        # LOOP
        (self.date_to - self.date_from + 1).to_i.times do

          width = zoom
          holiday = Calendar::Japanese::Holiday.holiday_info day_num

        if wday == 6
          pdf.SetTextColor(0,0,255)
          pdf.SetFillColor(222,222,255)
        elsif wday == 7
          pdf.SetTextColor(255,0,0)
          pdf.SetFillColor(255,222,222)
        elsif holiday.is_national
          pdf.SetTextColor(255,0,0)
          pdf.SetFillColor(255,222,222)
        else
          pdf.SetTextColor(0,0,0)
          pdf.SetFillColor(255,255,255)
        end

          pdf.SetLineWidth(0.1)
          pdf.SetY(y_start + header_height)
          pdf.SetX(left)
          pdf.RDMCell(width, height, day_num.day.to_s, "LTR", 0, "C",1)

          pdf.SetY(y_start + 2 * header_height)
          pdf.SetX(left)
          pdf.RDMCell(width, height, day_name(wday).first, "LTR", 0, "C",1)

          #Draw Rect
          pdf.SetLineWidth(0.01)
          pdf.SetDrawColor(160,160,160)
          (0..number_of_rows-1).each do |i|
            height_box = header_height * 3 + i * header_height
            pdf.SetY(y_start + height_box)
            pdf.SetX(left)
            pdf.RDMCell(width, header_height, "", "LTR", 0, "C",1)
          end

          pdf.SetLineWidth(0.1)
          pdf.SetDrawColor(0,0,0)

          left = left + width
          day_num = day_num + 1
          wday = wday + 1
          wday = 1 if wday > 7
        end
      end

      pdf.SetTextColor(0,0,0)
      pdf.SetFillColor(255,255,255)

      pdf.SetY(y_start)
      pdf.SetX(15)
      pdf.SetFontStyle('B',9)
      pdf.RDMCell(subject_width+g_width-15, headers_height, "", 1)

      # Tasks
      top = headers_height + y_start
      options = {
        :top => top,
        :zoom => zoom,
        :subject_width => subject_width,
        :g_width => g_width,
        :indent => 0,
        :indent_increment => 3,
        :top_increment => 3,
        :format => :pdf,
        :pdf => pdf
      }
      render(options)
      pdf.Output

    end

    #------------------------------------------------------
    # floorをとって単位(pt)を小数点で与えるようにした
    # (ガントチャートの線の端点がズレるため)
    #------------------------------------------------------
    def coordinates_with_expect(start_date, end_date, progress, zoom=nil)
      zoom ||= @zoom

      coords = {}
      if start_date && end_date && start_date < self.date_to && end_date > self.date_from
        if start_date > self.date_from
          coords[:start] = start_date - self.date_from
          coords[:bar_start] = start_date - self.date_from
        else
          coords[:bar_start] = 0
        end
        if end_date < self.date_to
          coords[:end] = end_date - self.date_from
          coords[:bar_end] = end_date - self.date_from + 1
        else
          coords[:bar_end] = self.date_to - self.date_from + 1
        end

        if progress
          progress_date = start_date + (end_date - start_date + 1) * (progress / 100.0)
          if progress_date > self.date_from && progress_date > start_date
            if progress_date < self.date_to
              coords[:bar_progress_end] = progress_date - self.date_from
            else
              coords[:bar_progress_end] = self.date_to - self.date_from + 1
            end
          end

          if progress_date < Date.today
            late_date = [Date.today, end_date].min
            if late_date > self.date_from && late_date > start_date
              if late_date < self.date_to
                coords[:bar_late_end] = late_date - self.date_from + 1
              else
                coords[:bar_late_end] = self.date_to - self.date_from + 1
              end
            end
          end
        end
      end
      # Transforms dates into pixels witdh
      coords.keys.each do |key|
        #coords[key] = (coords[key] * zoom).floor
        coords[key] = (coords[key] * zoom)
      end
      coords
    end


    def logger
      RAILS_DEFAULT_LOGGER
    end

  end


end
