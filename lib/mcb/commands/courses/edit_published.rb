name 'edit_published'
summary 'Edit publisheds course directly in the DB'

run do |opts, args, _cmd|
  MCB.init_rails(opts)

  cli = HighLine.new

  provider = Provider.find_by!(provider_code: args[0])

  all_courses_mode = args.size == 1
  courses = if all_courses_mode
              provider.courses
            else
              provider.courses.filter{ |course| args.include?(course.course_code) }
            end

  multi_course_mode = courses.size > 1

  flow = :root
  finished = false
  until finished do
    case flow
    when :root
      cli.choose do |menu|
        courses[0..1].each { |c| puts Terminal::Table.new rows: MCB::CourseShow.new(c).to_h }
        puts "Only showing first 2 courses of #{courses.size}." if courses.size > 2

        if multi_course_mode
          menu.prompt = "Editing multiple courses"
        else
          menu.prompt = "Editing course"
        end
        menu.choice(:exit) { finished = true }
        menu.choice(:toggle_sites) { flow = :toggle_sites } unless multi_course_mode
        menu.choice(:edit_route) { flow = :edit_route }
        menu.choice(:edit_qualifications) { flow = :edit_qualifications }
        menu.choice(:edit_study_mode) { flow = :edit_study_mode }
        menu.choice(:edit_english) { flow = :edit_english }
        menu.choice(:edit_maths) { flow = :edit_maths }
        menu.choice(:edit_science) { flow = :edit_science }
        menu.choice(:edit_start_date) { flow = :edit_start_date }
      end
    when :toggle_sites
      cli.choose do |menu|
        menu.prompt = "Toggling course sites"
        menu.choice(:done) { flow = :root }
        menu.choices(*(courses.first.actual_and_potential_site_statuses.map(&:description))) do |site_str|
          site_code = site_str.match(/\(code: (.*)\)/)[1]
          courses.first.toggle_site(provider.sites.find_by!(code: site_code))
        end
      end
    when :edit_route
      cli.choose do |menu|
        menu.prompt = "Editing course route"
        menu.choices(*Course.program_types.keys) { |value| courses.each{ |c| c.program_type = value } }
        flow = :root
      end
    when :edit_qualifications
      cli.choose do |menu|
        menu.prompt = "Editing course qualifications"
        menu.choices(*Course.qualifications.keys) { |value| courses.each{ |c| c.qualification = value } }
        flow = :root
      end
    when :edit_study_mode
      cli.choose do |menu|
        menu.prompt = "Editing course study mode"
        menu.choices(*Course.study_modes.keys) { |value| courses.each{ |c| c.study_mode = value } }
        flow = :root
      end
    when :edit_english
      cli.choose do |menu|
        menu.prompt = "Editing course english"
        menu.choices(*Course.englishes.keys) { |value| courses.each{ |c| c.english = value } }
        flow = :root
      end
    when :edit_maths
      cli.choose do |menu|
        menu.prompt = "Editing course maths"
        menu.choices(*Course.maths.keys) { |value| courses.each{ |c| c.maths = value } }
        flow = :root
      end
    when :edit_science
      cli.choose do |menu|
        menu.prompt = "Editing course science"
        menu.choices(*Course.sciences.keys) { |value| courses.each{ |c| c.science = value } }
        flow = :root
      end
    when :edit_start_date
      start_date = Date.parse(cli.ask("What's the new start date?  "))
      if cli.agree("Start date will be set to #{start_date.strftime('%d %b %Y')}. Continue? ")
        courses.each { |c| c.start_date = start_date }
      end
      flow = :root
    end
    courses.each(&:save!)
    courses.each(&:reload)
    courses.first.site_statuses.reload unless multi_course_mode
  end
end
