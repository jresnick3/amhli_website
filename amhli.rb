require 'pry'
require 'tilt/erubis'
require 'sinatra'
require 'sinatra/reloader' if development?
require 'rack'
require 'sinatra/content_for'
require 'yaml'
require 'bcrypt'
require 'csv'

configure do
  enable :sessions
  set :session_secret, 'secret1'
end

helpers do
  def event_headers
    @events = CSV.read('./data/weekly_events.csv')
    @events.first
  end

  def events
    @events = CSV.read('./data/weekly_events.csv')
    @events[1..-1]
  end
end

def data_path
  if ENV["RACK-ENV"] == "test"
    File.expand_path('../test/data', __FILE__)
  else
    File.expand_path('../data', __FILE__)
  end
end

def load_members
  members_path = if ENV["RACK_ENV"] = "test"
    File.expand_path("../test/members.yml", __FILE__)
  else
    File.expand_path("../members.yml", __FILE__)
  end
  YAML.load_file(members_path)
end

def valid_new_member?(email)
  @members = load_members
  return true unless @members
  @members.none?{ |key,_| key == email}
end

def add_member(first, last, email, password)
  members = @members || {}
  password = BCrypt::Password.create(password)
  members[email] = {first_name: first, last_name: last, password: password}
  File.open('./members.yml', 'w') {|file| file.write(members.to_yaml)}
end

def valid_user?(email)
  @members = load_members
  @members && @members.any?{ |key,_| key == email}
end

def valid_password?(email, password)
  @members = load_members
  @members[email][:password] == password
end

def valid_credentials?(email, password)
  valid_user?(email) && valid_password?(email, password)
end

def signed_in?
  session[:email]
end

def add_to_sheet(time)
  pattern = File.join(data_path, 'requests.csv')
  CSV.open(pattern, 'wb') do |csv|
    csv << [session[:email], time]
  end
end

get '/' do
  erb :index
end

get '/signin' do
  erb :signin
end

post '/signin' do
  email, password = params[:email], params[:password]
  if valid_credentials?(email, password)
    session[:message] = "Sign in successful!"
    session[:email] = email
    redirect '/'
  else
    status 422
    session[:message] = "Invalid Credentials."
    erb :signin
  end
end

post '/signout' do
  session.delete(:email)
  redirect '/'
end

get '/weekly_events' do
  erb :events
end

get '/shiurim' do
  erb :shiurim
end

get '/night_seder' do
  erb :schedule
end

get '/join' do
  erb :join
end

post '/join' do
  @first_name = params[:first_name]
  @last_name = params[:last_name]
  email = params[:email]
  password = params[:password]
  if valid_new_member?(email)
    add_member(@first_name, @last_name, email, password)
    erb :welcome
  else
    session[:message] = "Sorry, this email address is already used by a member."
    erb :join
  end
end

get '/request_chavrusah' do
  if signed_in?
    erb :request
  else
    session[:message] = "You must be a member to request a chavrusah."
    redirect '/join'
  end
end

post '/request_chavrusah' do
  learn_time = params[:request_time]
  add_to_sheet(learn_time)
  session[:message] = "Thanks for your interest, your request is being processed. Wait for an email."
  redirect '/'
end
