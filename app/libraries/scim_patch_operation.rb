# frozen_string_literal: true

# Parse One of "Operations" in PATCH request
class ScimPatchOperation
  attr_reader :op, :path_scim, :path_sp, :value

  # path presence is guaranteed by ScimPatchOperationConverter
  #
  # value must be String or Array.
  # complex-value(Hash) is converted to multiple single-value operations by ScimPatchOperationConverter
  def initialize(op, path, value)
    if !op.in?(%w[add replace remove]) || path.nil?
      raise Scimaenaga::ExceptionHandler::UnsupportedPatchRequest
    end

    # define validate method in the inherited class
    validate(op, path, value)

    @op = op
    @value = value
    @path_scim = parse_path_scim(path)
    @path_sp = path_scim_to_path_sp(@path_scim)

    # define parse method in the inherited class
  end

  private

    def parse_path_scim(path)
      # 'emails[type eq "work"].value' is parsed as follows:
      #
      # {
      #   attribute: 'emails',
      #   filter: {
      #     attribute: 'type',
      #     operator: 'eq',
      #     parameter: 'work'
      #   },
      #   rest_path: ['value']
      # }
      #
      # This method suport only single operator

      # path: emails.value
      # filter_string: type eq "work"
      path_str = path.dup
      filter_string = path_str.slice!(/\[(.+?)\]/, 0)&.slice(/\[(.+?)\]/, 1)

      # path_elements: ['emails', 'value']
      attributes = Scimaenaga.config.mutable_user_attributes_schema.keys.map(&:to_s)
      first_element = attributes.find { |attr| path_str.start_with?(attr) }
      path_elements =
        if path_str == first_element
          [first_element]
        elsif first_element
          elements_after_first = path_str.slice((first_element.length + 1)..-1).split('.')
          [first_element] + elements_after_first
        else
          path_str.split('.') # This should not pass if the config is correctly defined.
        end

      # filter_elements: ['type', 'eq', '"work"']
      filter_elements = filter_string&.split(' ')
      path_scim = { attribute: path_elements[0],
                    rest_path: path_elements.slice(1...path_elements.length), }
      if filter_elements.present?
        path_scim[:filter] = {
          attribute: filter_elements[0],
          operator: filter_elements[1],
          # delete double quotation
          parameter: filter_elements[2].slice(1...filter_elements[2].length - 1),
        }
      end

      path_scim
    end

end
