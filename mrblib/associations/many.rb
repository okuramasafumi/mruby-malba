module Malba
  # Representing many association
  class Many < Association
    # Recursively converts objects into an Array of Hashes
    #
    # @param target [Object] the object having an association method
    # @param params [Hash] user-given Hash for arbitrary data
    # @return [Array<Hash>]
    def to_hash(target, params: {})
      objects = target.send(@name)
      objects = @condition.call(objects, params) if @condition
      objects.map { |o| @resource.new(o, params: params).to_hash }
    end
  end
end
