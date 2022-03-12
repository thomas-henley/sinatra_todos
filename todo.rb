require "sinatra"
require "sinatra/reloader"
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end

get "/lists/:index" do
  @list = session[:lists][params["index"].to_i]
  erb :list, layout: :layout
end

get "/lists/:index/edit" do
  @list = session[:lists][params["index"].to_i]
  erb :edit_list, layout: :layout
end

post "/lists/:index" do
  list_name = params[:list_name].strip
  @list = session[:lists][params["index"].to_i]
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been edited."
    redirect "/lists/#{params[:index]}"
  end
end

post "/lists/:index/delete" do
  session[:lists].delete_at(params[:index].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Return an error message if the name is invalid, else return nil
def error_for_list_name(name)
  if session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  elsif !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end
