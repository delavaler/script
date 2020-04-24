# frozen_string_literal: true

require "bundler/inline"

# This reproduction script allows you to test Action Policy with Rails.
# It contains:
#   - Headless User model
#   - UserPolicy
#   - UsersController
#   - Example tests for the controller.
#
# Update the classes to reproduce the failing case.
#
# Run the script as follows:
#
#   $ ruby bug_report_template.rb
gemfile(true) do
  source "https://rubygems.org"

  gem "rails", "~> 6.0"
  gem "action_policy", "~> 0.4"

  gem "pry-byebug", platform: :mri
end

require "rails"
require "action_controller/railtie"
require "action_policy"

require "minitest/autorun"

module Buggy
  class Application < Rails::Application
    config.logger = Logger.new("/dev/null")
    config.eager_load = false

    initializer "routes" do
      Rails.application.routes.draw do
        get ":controller(/:action)"
      end
    end
  end
end

Rails.application.initialize!

class User
  include Comparable

  attr_reader :name

  def initialize(name)
    @name = name
  end

  def admin?
    name == "admin"
  end

  def <=>(other)
    return super unless other.is_a?(User)
    name <=> other.name
  end
end

class Post
  attr_reader :title, :user
  def initialize(title, user)
    @title = title
    @user = user
  end
end

class UserPolicy < ActionPolicy::Base
  def index?
    true
  end

  def create?
    user.admin?
  end

  def show?
    true
  end

  def manage?
    user.admin? && !record.admin?
  end
end

class PostPolicy < ActionPolicy::Base
  def create?
    check?(:create?, record.user)
  end
end

class UsersController < ActionController::Base
  authorize :user, through: :current_user

  before_action :set_user, only: [:update, :show]

  def index
    authorize!
    render plain: "OK"
  end

  def create
    authorize!
    render plain: "OK"
  end

  def update
    render plain: "OK"
  end

  def show
    if allowed_to?(:update?, @user)
      render plain: "OK"
    else
      render plain: "Read-only"
    end
  end

  def current_user
    @current_user ||= User.new(params[:user])
  end

  private

  def set_user
    @user = User.new(params[:target])
    authorize! @user
  end
end

class PostPolicyTest < ActiveSupport::TestCase
  test 'should return false' do
    post = Post.new('title', User.new('user'))
    policy = PostPolicy.new(post, user: User.new('user'))
    assert_not policy.create?
  end
end

