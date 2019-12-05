module API
  module V2
    class SerializableOrganisation < JSONAPI::Serializable::Resource
      type "organisations"
      has_many :users
      attributes :name

      attribute :nctl_ids do
        @object.nctl_organisations.map(&:nctl_id)
      end
    end
  end
end
