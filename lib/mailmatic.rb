require 'rubygems'
require 'premailer'

module MailMatic
  class Generator
    STATICMATIC_SETUP_COMMAND = "staticmatic setup \"%s\""
    STATICMATIC_BUILD_COMMAND = "staticmatic build \"%s\""
    STATICMATIC_OUTPUT_SUBDIR = "site"
    EMAILS_SUBDIR             = "emails"
    DEFAULT_LAYOUT_SUBPATH    = "src/layouts/default.haml"
    DEFAULT_PAGE_SUBPATH      = "src/pages/index.haml"
    PREMAILER_WARN_LEVEL      = Premailer::Warnings::SAFE

    attr_accessor :root_dir
    def initialize(root_dir)
      @root_dir = root_dir
    end

    def generate_email(infile, outfile)
      outdir = File.dirname(outfile)
      Dir.mkdir(outdir) if !File.directory?(outdir)

      premailer = Premailer.new(
        infile,
        :warn_level => PREMAILER_WARN_LEVEL
      )

      File.open(outfile, "wb") do |f|
        f << premailer.to_inline_css
      end
      puts "created #{outfile}"

      if premailer.warnings.any?
        puts
        puts "WARNING: #{outfile}"
        puts "-" * 79
        premailer.warnings.each do |w|
          puts "  [#{w[:level]}] #{w[:message]} may not render properly in #{w[:clients]}"
        end
        puts
      end

      return 0
    rescue Exception => e
      puts "failed to create #{outfile}"
      puts e.inspect
      return -1
    end

    def generate_emails
      html_dir   = File.expand_path(STATICMATIC_OUTPUT_SUBDIR, root_dir)
      emails_dir = File.expand_path(EMAILS_SUBDIR, root_dir)
      Dir.mkdir(emails_dir) if !File.directory?(emails_dir)
      Dir.chdir(html_dir) do
        Dir.glob("**/*.html").each do |html_file|
          email_file = File.expand_path(html_file, "../#{EMAILS_SUBDIR}")
          status = generate_email(html_file, email_file)
          return status if status != 0
        end
      end
      return 0
    end

    def generate_pages
      result = system(STATICMATIC_BUILD_COMMAND % root_dir)
      return result ? 0 : -1
    end

    def setup
      # Run StaticMatic setup then hack a few files with sed
      result = system(STATICMATIC_SETUP_COMMAND % root_dir)
      return -1 unless result

      i_opt = "-i"
      if `uname` =~ /darwin/i
        i_opt = '-i ""'
      end

      result = system("sed #{i_opt} -e \"s/StaticMatic/MailMatic/g\" \"#{root_dir}/#{DEFAULT_LAYOUT_SUBPATH}\"")
      return -1 unless result

      result = system("sed #{i_opt} -e \"s/= stylesheets/%link\\{:rel => 'stylesheet', :href => 'stylesheets\\/screen.css'\\}/g\" \"#{root_dir}/#{DEFAULT_LAYOUT_SUBPATH}\"")
      return -1 unless result

      result = system("sed #{i_opt} -e \"s/StaticMatic/MailMatic/g\" \"#{root_dir}/#{DEFAULT_PAGE_SUBPATH}\"")
      return -1 unless result

      return 0
    end

    def build
      puts "Building #{root_dir}"

      status = generate_pages
      return status if status != 0

      status = generate_emails

      return status
    end
  end

  class Application
    def self.run!(*args)
      command = args.shift
      args.push(Dir.pwd) if args.empty?

      case command
      when 'setup'
        args.each do |arg|
          status = MailMatic::Generator.new(arg).setup
          return status if status != 0
        end
        return 0

      when 'build'
        args.each do |arg|
          status = MailMatic::Generator.new(arg).build
          return status if status != 0
        end
        return 0

      else
        puts "ERROR: Invalid command"
        return -1
      end
    end
  end
end
