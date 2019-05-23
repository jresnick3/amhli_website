require 'sinatra'
require 'fileutils'

ENV["RACK-ENV"] = "test"

require 'minitest/autorun'
require 'rack/test'

require_relative './amhli'

class AMHLITest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
    CSV.new(data_path + "/requests.csv")
  end

  def teardown
    FileUtils.rm_rf(data_path)
    File.open('./test/members.yml', 'w') {}
  end

  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  def example_session
    {"rack.session" => { email: "example@aol.com" }}
  end

  def create_user(first, last, email, password)
    members = load_members || {}
    password = BCrypt::Password.create(password)
    members[email] = {first_name: first, last_name: last, password: password}
    File.open('./test/members.yml', 'w') {|file| file.write(members.to_yaml)}
  end

  def load_events
    CSV.read("./data/weekly_events.csv")
  end

  def load_requests
    pattern = File.join(data_path, "requests.csv")
    CSV.read(pattern)
  end

  def test_index
    get '/'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'Adult Male Higher Learning Initiative')
    assert_includes(last_response.body, '>Sign in</a>')
  end

  def test_sign_in_page
    get '/signin', email: 'example@aol.com'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, 'Are you a returning user?')
    assert_includes(last_response.body, 'value="example@aol.com"')
  end

  def test_sign_in_success
    create_user("John", "Smith", "example@aol.com", "1234")
    post '/signin', email: "example@aol.com", password: "1234"
    assert_equal('example@aol.com', session[:email])
    assert_equal('Sign in successful!', session[:message])
    assert_equal(302, last_response.status)

    get last_response["Location"]
    assert_equal(200, last_response.status)
  end

  def test_sign_in_bad_credentials
    post '/signin', email: "example@aol.com", password: "1234"
    assert_equal(422, last_response.status)
    assert_includes(last_response.body, "Invalid Credentials")
  end

  def test_sign_out
    post '/signout', {}, example_session
    assert_equal(302, last_response.status)
    assert_nil(session[:email])
  end

  def test_events_page
    get '/weekly_events'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "#{load_events.last.last}")
  end

  def test_shiurim_page
    get '/shiurim'
    assert_equal(200, last_response.status)
  end

  def test_night_seder
    get '/night_seder'
    assert_equal(200, last_response.status)
  end

  def test_signup_page
    get '/join'
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Are you ready to join the Adult Male Higher Learning Initiative?")
    assert_includes(last_response.body, "<input id='password' type='password'")
  end

  def test_signup_valid
    post '/join', first_name: "John", last_name: "Smith", email: "example@aol.com", password: "1234"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Hey John Smith!")
  end

  def test_signup_invalid
    create_user("John", "Smith", "example@aol.com", "1234")
    post '/join', first_name: "Jon", last_name: "Dow", email: "example@aol.com", password: "123"
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Sorry, this email address is already used by a member.")
  end

  def test_request_chavrusah_page_signed_out
    get '/request_chavrusah'
    assert_equal(302, last_response.status)
    assert_equal("You must be a member to request a chavrusah.", session[:message])

    get last_response["Location"]
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Are you ready to join the Adult Male Higher Learning Initiative?")
  end

  def test_request_chavrusah_page_signed_in
    get '/request_chavrusah', {}, example_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Are you looking for a chavrusah?")
  end

  def test_request_chavrusah
    post '/request_chavrusah' , {request_time: "morning"}, example_session
    assert_equal(302, last_response.status)
    assert_equal("Thanks for your interest, your request is being processed. Wait for an email.", session[:message])
    assert_equal("morning", load_requests.first.last)

    get last_response["Location"]
    assert_equal(200, last_response.status)
  end
end
