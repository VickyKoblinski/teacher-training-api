
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

  def match_site(site)
    find_by_site_details(site)
  end

private

  def find_by_provider_details(provider)
    if check_postcode_present(provider.postcode) && check_postcode_matches(provider.postcode)
      edubase_by_postcode[provider.postcode.upcase].select do |e|
        if check_name_matches_establishment(site.location_name, e)
          check_establishment_open(e)
        end
      end
    end
  end

  def find_by_site_details(site)
    log = []

    site_postcode = site.postcode.upcase
    site_name = if site.location_name == "Main Site"
                  site.provider.provider_name
                else
                  site.location_name
                end
    if site_postcode.present? && check_postcode_matches(site_postcode)
      establishment = find_open_establishments_by_name(
        name: site_name,
        establishments: edubase_by_postcode[site_postcode],
        log: log,
      )

      [establishment, log]
    else
      log << if site_postcode.present?
               :no_postcode
             else
               :no_establishment_match_postcode
             end
    end
  end

  def find_open_establishments_by_name(name:, establishments:, log:)
    found_establishment = establishments.find do |e|
      if check_name_matches_establishment(name, e) || check_name_distance(name, e)
        check_establishment_open(e)
      end
    end

    unless found_establishment
      if establishments.none? { |e| check_name_matches_establishment(name, e) }
        log << :no_names_matched
      end

      if establishments.none? { |e| check_name_distance(name, e) }
        log << :no_names_close_enough
      end

      if establishments.none? { |e| check_establishment_open(e) }
        log << :no_name_matching_establishments_open
      end
    end

    found_establishment
  end

  def strings_similar?(string1, string2, threshold = 0.80)
    ratio = 1 - (Levenshtein.distance(string1, string2).to_f / string1.length)
    result = ratio >= threshold
    puts "distance: #{string1} | #{string2} = #{result} : #{ratio} (#{Levenshtein.distance(string1, string2)} / #{string1.length})"
    result
  end

  # def check_postcode_present(postcode, stats)
  #   if postcode.present?
  #     @counters[:providers_with_postcode] += 1
  #     true
  #   else
  #     @counters[:providers_without_postcode] += 1
  #     false
  #   end
  # end

  def check_postcode_matches(postcode)
    edubase_by_postcode.key?(postcode)
  end

  def check_name_matches_establishment(name, establishment)
    name == establishment["EstablishmentName"]
  end

  def check_name_distance(name, establishment)
    strings_similar?(name, establishment["EstablishmentName"])
  end

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

found_sites_csv_path = "found_sites.csv"
missing_sites_csv_path = "missing_sites.csv"

found_sites_csv = CSV.open(
  found_sites_csv_path,
  "wb",
)
found_sites_csv << %w[provider_code location_code location_name establishment_name URN UPRN]

missing_sites_csv = CSV.open(
  missing_sites_csv_path,
  "wb",
)
missing_sites_csv << %w[provider_code location_code location_name log]

rc.providers.each do |provider|
  provider.sites.each do |site|
    (establishment, log) = matcher_service.match_site(site)
    if establishment.present?
      found_sites_csv << [
        provider.provider_code,
        site.code,
        site.location_name,
        establishment["EstablishmentName"],
        establishment["URN"],
        establishment["UPRN"],
      ]
    else
      missing_sites_csv << [
        provider.provider_code,
        site.code,
        site.location_name,
        log.join("; "),
      ]
    end
  end
end

found_sites_csv.close
missing_sites_csv.close

pp matcher_service.counters
