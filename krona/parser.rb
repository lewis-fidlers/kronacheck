# coding: utf-8
require "time"
require "csv"
require "charlock_holmes"

module Krona
  class Parser
    TOTAL_KEY= "’’’TOTAL"

    def initialize(directory:)
      @directory = directory
      @provinces = {}
      @cities = {}
    end

    def csv_files
      Dir.glob("#{@directory}/COVID19BE_CASES_MUNI_CUM*.csv").sort
    end

    def cities(last_n_days: 10)
      ensure_parsed!
      (@cities.keys + [TOTAL_KEY]).inject({}) do |result, city|
        if arr = @cities[city]
          first, *rest = arr.sort_by(&:first).last(last_n_days)
          prev = first.last.to_i
          result[city] = rest.collect do |date, cases|
            cases = cases.to_i
            r = [date, cases - prev, cases]
            prev = cases
            r
          end.sort_by(&:first)
        end
        result
      end
    end

    def provinces(last_n_days: 10)
      ensure_parsed!
      @provinces.inject({}) do |result, (province, value)|
        arr = value.to_a
        first, *rest = arr.sort_by(&:first).last(last_n_days)
        prev = first.last.to_i
        result[province] = rest.collect do |date, cases|
          cases = cases.to_i
          r = [date, cases - prev, cases]
          prev = cases
          r
        end.sort_by(&:first)
        result
      end
    end

    def parse_csvs!
      csv_files.each do |name|
        total_cases = 0
        date = date_for(file_name: name)
        encoding = encoding_for(file_name: name)

        CSV.foreach(name, headers: true, encoding: "#{encoding}:UTF-8") do |row|
          city = row["TX_DESCR_NL"]
          cases = row["CASES"].to_i
          total_cases += cases
          province = row["TX_PROV_DESCR_NL"]
          @provinces[province] ||=  {}
          @provinces[province][date] ||= 0
          @provinces[province][date] += cases

          @cities[city] ||= {}
          @cities[city][date] ||= 0
          @cities[city][date] += cases
        end
        @cities[TOTAL_KEY] ||= []
        @cities[TOTAL_KEY] << [date, total_cases]
      rescue CSV::MalformedCSVError
        puts "#{name} kan het niet aan"
      end
    end

    def date_for(file_name:)
      date_part = file_name.split("_").last.split(".").first
      date = begin
               Time.parse(date_part)
             rescue ArgumentError
               nil
             end.to_date
    end

    def encoding_for(file_name:)
      detection = CharlockHolmes::EncodingDetector.detect(File.read(file_name))
      detection[:encoding]
    end

    def ensure_parsed!
      return unless @cities.empty?

      parse_csvs!
    end
  end
end
