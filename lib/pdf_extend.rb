module PDFExtend

  def self.included(base) # :nodoc:
    base.extend(ClassMethods)
    base.send(:include, InstanceMethods)

    # Same as typing in the class
    base.class_eval do
      unloadable # Send unloadable so it will not be unloaded in development

      # 本家メソッドを上書き
      #alias_method_chain :html_task, :expect
      #alias_method_chain :subject_for_project, :expect
      alias_method_chain :initialize, :expect
    end
  end

  module ClassMethods
  end

  module InstanceMethods

    def initialize_with_expect(lang)

      set_language_if_valid lang
      pdf_encoding = l(:general_pdf_encoding).upcase
      if RUBY_VERSION < '1.9'
        @ic = Iconv.new(pdf_encoding, 'UTF-8')
      end
      super('P', 'mm', 'A3', (pdf_encoding == 'UTF-8'), pdf_encoding)
      case current_language.to_s.downcase
      when 'vi'
        @font_for_content = 'DejaVuSans'
        @font_for_footer  = 'DejaVuSans'
      else
        case pdf_encoding
        when 'UTF-8'
          @font_for_content = 'FreeSans'
          @font_for_footer  = 'FreeSans'
        when 'CP949'
          extend(PDF_Korean)
          AddUHCFont()
          @font_for_content = 'UHC'
          @font_for_footer  = 'UHC'
        when 'CP932', 'SJIS', 'SHIFT_JIS'
          extend(PDF_Japanese)
          AddSJISFont()
          @font_for_content = 'SJIS'
          @font_for_footer  = 'SJIS'
        when 'GB18030'
          extend(PDF_Chinese)
          AddGBFont()
          @font_for_content = 'GB'
          @font_for_footer  = 'GB'
        when 'BIG5'
          extend(PDF_Chinese)
          AddBig5Font()
          @font_for_content = 'Big5'
          @font_for_footer  = 'Big5'
        else
          @font_for_content = 'Arial'
          @font_for_footer  = 'Helvetica'
        end
      end
      SetCreator(Redmine::Info.app_name)
      SetFont(@font_for_content)
    end

  end

end
