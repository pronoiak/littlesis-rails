# frozen_string_literal: true

class ExternalData
  module Datasets
    class FECContribution < SimpleDelegator
      def donor_attributes
        {
          'name' => name,
          'city' => self['CITY'],
          'state' => self['STATE'],
          'zip_code' => self['ZIP_CODE'],
          'employer' => employer,
          'occupation' => self['OCCUPATION'],
          'md5digest' => md5digest
        }
      end

      def md5digest
        @md5digest ||= Digest::MD5.hexdigest([name, city, state, zip_code, employer, occupation].join(''))
      end

      alias digest md5digest

      def name
        return nil if self['NAME'].blank?

        @name ||= NameParser.format(self['NAME'])
      end

      def city
        self['CITY']
      end

      def state
        self['STATE']
      end

      def zip_code
        self['ZIP_CODE']
      end

      def employer
        return nil if self['EMPLOYER'].blank?

        @employer ||= OrgName.parse(self['EMPLOYER']).clean
      end

      def occupation
        self['OCCUPATION']
      end

      def sub_id
        self['SUB_ID']
      end

      def amount
        self['TRANSACTION_AMT'].to_f.round(2)
      end

      def date
        LsDate.parse_fec_date self['TRANSACTION_DT']
      end

      def committee_id
        self['CMTE_ID']
      end
    end
  end
end
