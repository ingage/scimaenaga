# frozen_string_literal: true

module Scimaenaga
  class ApplicationController < ActionController::API
    include ActionController::HttpAuthentication::Basic::ControllerMethods
    include ExceptionHandler
    include Response

    around_action :set_locale
    before_action :log_request_details
    before_action :authorize_request

    private

      def authorize_request
        send(authentication_strategy) do |searchable_attribute, authentication_attribute|
          authorization = AuthorizeApiRequest.new(
            searchable_attribute: searchable_attribute,
            authentication_attribute: authentication_attribute
          )
          @company = authorization.company
        end
        raise Scimaenaga::ExceptionHandler::InvalidCredentials if @company.blank?
      end

      def authentication_strategy
        if request.headers['Authorization']&.include?('Bearer')
          :authenticate_with_oauth_bearer
        else
          :authenticate_with_http_basic
        end
      end

      def authenticate_with_oauth_bearer
        authentication_attribute = request.headers['Authorization'].split.last
        payload = Scimaenaga::Encoder.decode(authentication_attribute).with_indifferent_access
        searchable_attribute = payload[Scimaenaga.config.basic_auth_model_searchable_attribute]

        yield searchable_attribute, authentication_attribute
      end

      def find_value_for(attribute)
        params.dig(*path_for(attribute))
      end

      # `path_for` is a recursive method used to find the "path" for
      # `.dig` to take when looking for a given attribute in the
      # params.
      #
      # Example: `path_for(:name)` should return an array that looks
      # like [:names, 0, :givenName]. `.dig` can then use that path
      # against the params to translate the :name attribute to "John".

      def path_for(attribute, object = controller_schema, path = [])
        at_path = path.empty? ? object : object.dig(*path)
        return path if at_path == attribute

        case at_path
        when Hash
          at_path.each do |key, _value|
            found_path = path_for(attribute, object, [*path, key])
            return found_path if found_path
          end
          nil
        when Array
          at_path.each_with_index do |_value, index|
            found_path = path_for(attribute, object, [*path, index])
            return found_path if found_path
          end
          nil
        end
      end

      def set_locale
        I18n.locale = :en
        yield
      ensure
        I18n.locale = I18n.default_locale
      end

      def log_request_details
        if request.method != 'GET'
          details = {
            method: request.method,
            fullpath: request.fullpath,
            params: request.filtered_parameters,
          }
          Rails.logger.info details.to_json
        end
      end
  end
end
