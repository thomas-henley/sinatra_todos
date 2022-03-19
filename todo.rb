require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

before do
  session[:lists] ||= []
end

helpers do
  def complete? list
    !list[:todos].empty? && list[:todos].all? { |todo| todo[:completed] }
  end
  
  def unfinished_tasks list
    list[:todos].count { |todo| !todo[:completed] }
  end
  
  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| complete?(list) }
      
    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
  
  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
      
    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

get "/" do
  redirect "/lists"
end

get "/lists" do
  @lists = session[:lists]
  @lists.sort_by! { |list| complete?(list) ? 1 : 0 }
  erb :lists, layout: :layout
end

get "/lists/new" do
  erb :new_list, layout: :layout
end
  
def valid_list_id?(id)
  session[:lists].any? { |list| list[:id] == id.to_i }
end

def invalid_list_redirect
  session[:error] = "The specified list was not found."
  redirect "/lists"
end

get "/lists/:list_id" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  erb :list, layout: :layout
end

get "/lists/:list_id/edit" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  erb :edit_list, layout: :layout
end

post "/lists/:list_id" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  list_name = params[:list_name].strip
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been edited."
    redirect "/lists/#{@list[:id]}"
  end
end

def next_id(collection)
  max = collection.map { |elem| elem[:id] }.max || 0
  max + 1
end

# Add a todo task to the list
post "/lists/:list_id/todos" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_id(@list[:todos])
    @list[:todos] << { id: id, name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{@list[:id]}"
  end
end

# Toggle a todo's complete status
post "/lists/:list_id/todos/:todo_id" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  todo = @list[:todos].find { |elem| elem[:id] == params[:todo_id].to_i }
  todo[:completed] = (params[:completed] == "true")
  redirect "/lists/#{@list[:id]}"
end

# delete item off of todo list
post "/lists/:list_id/todos/:todo_id/delete" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  @list[:todos].reject! { |todo| todo[:id] == params[:todo_id].to_i }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax request
    status 204
  else
    session[:success] = "The todo was deleted."
    redirect "/lists/#{@list[:id]}"
  end
end

post "/lists/:list_id/complete_all" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  @list = session[:lists].find { |list| list[:id] == params[:list_id].to_i }
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  redirect "/lists/#{@list[:id]}"
end

post "/lists/:list_id/delete" do
  invalid_list_redirect unless valid_list_id?(params[:list_id])
  
  session[:lists].reject! { |list| list[:id] == params[:list_id].to_i }
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    # ajax request
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

def error_for_todo_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  end
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
    id = next_id(session[:lists])
    session[:lists] << {id: id, name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end
