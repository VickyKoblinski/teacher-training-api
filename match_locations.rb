
require 'pry'

class EdubaseMatcherService
  attr_accessor :counters
  attr_accessor :edubase_by_postcode
  attr_accessor :edubase_by_name

  def initialize(csv_file:)
    @edubase_by_name = {}
    @edubase_by_postcode = {}
    @counters = Hash.new { |hash, key| hash[key] = 0 }

    edubase_csv = File.read(csv_file).force_encoding(Encoding::ISO8859_1)
    CSV.parse(edubase_csv, headers: true) do |row|
      edubase_by_name[row["EstablishmentName"]] ||= []
      edubase_by_name[row["EstablishmentName"]] << row
      edubase_by_postcode[row["Postcode"].upcase] ||= []
      edubase_by_postcode[row["Postcode"].upcase] << row
    end
  end

  def find_by_provider_details(provider)
    if check_postcode_present(provider) && check_postcode_matches(provider)
      edubase_by_postcode[provider.postcode.upcase].select do |e|
        if check_name_matches(provider, e)
          check_establishment_open(e)
        end
      end
    end
  end

  def matches?(provider)
    establishment = find_by_provider_details(provider)

    if establishment.present?
      @counters[:found] += 1
      return true
    else
      @counters[:not_found] += 1
      return false
    end
  end

private

  def strings_similar?(string1, string2, threshold = 0.80)
    ratio = 1 - (Levenshtein.distance(string1, string2).to_f / string1.length)
    result = ratio >= threshold
    puts "distance: #{string1} | #{string2} = #{result} : #{ratio} (#{Levenshtein.distance(string1, string2)} / #{string1.length})"
    result
  end

  def check_postcode_present(provider)
    if provider.postcode.present?
      @counters[:providers_with_postcode] += 1
      true
    else
      @counters[:providers_without_postcode] += 1
      false
    end
  end

  def check_postcode_matches(provider)
    if edubase_by_postcode.key?(provider.postcode.upcase)
      @counters[:providers_with_matching_postcode] += 1
      true
    else
      @counters[:providers_without_matching_postcode] += 1
      false
    end
  end

  def check_name_matches(provider, establishment)
    if provider.provider_name == establishment["EstablishmentName"]
      @counters[:providers_with_exact_name_match] += 1
      true
    elsif strings_similar?(provider.provider_name, establishment["EstablishmentName"])
      @counters[:providers_with_close_enough_name_match] += 1
      true
    else
      @counters[:providers_without_name_match] += 1
      false
    end
  end

  # def check_name_distance(provider, establishment)
  #   return true if strings_similar?(provider.provider_name, establishment["EstablishmentName"])

  #   @counters[:name_too_distant] += 1
  #   false
  # end

  def check_establishment_open(establishment)
    if establishment["EstablishmentStatus (name)"] == "Open"
      @counters[:establishment_found_open] += 1
      true
    else
      @counters[:establishment_not_found_open] += 1
      false
    end
  end
end


csv_file = ARGV.shift

rc = RecruitmentCycle.current
matcher_service = EdubaseMatcherService.new(csv_file: csv_file)

rc.providers.each do |provider|
  unless matcher_service.matches? provider
    puts "#{provider.provider_name} NOT FOUND"
  end
end

pp matcher_service.counters
