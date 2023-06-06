require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    list[:todos].size > 0 && list[:todos].all? { |todo| todo[:completed] }
  end

  def completion_status(list)
    complete = list[:todos].count { |todo| todo[:completed] }
    total = list[:todos].count
    "#{complete}/#{total}"
  end

  def sort_todos_by_completed(list, &block)
    complete_todos, incomplete_todos = list[:todos].partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, list[:todos].index(todo) }
    complete_todos.each { |todo| yield todo, list[:todos].index(todo) }
  end

  def sort_lists_by_completed(lists, &block)
    complete_lists, incomplete_lists = lists.partition { | list| list_complete?(list) }

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end
end

before do
  session[:lists] ||= []
end

def get_list(params)
  session[:lists][params[:id].to_i]
end

get "/" do
  redirect "/lists"
end

# Show the list of lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render "New List" form
get "/lists/new" do
  erb :new_list
end

def error_for_list_name(list_name)
  if !(1..100).cover? list_name.length
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == list_name }
    "List name must be unique."
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

get "/lists/:id/edit" do
  @list = session[:lists][params[:id].to_i]
  erb :edit_list
end

post "/lists/:id/destroy" do
  removed_list = session[:lists].delete_at(params[:id].to_i)
  if removed_list
    session[:success] = "List deleted."
  else
    session[:error] = "Error deleting list."
  end
  redirect "/lists"
end

post "/lists/:id" do
  @list = session[:lists][params[:id].to_i]
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/" + params[:id]
  end
end

get "/lists/:id" do
  @list = get_list params
  erb :list
end

post "/lists/:id/complete_all" do
  @list = get_list params
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/" + params[:id]
end

def error_for_todo(todo_name)
  unless (1..100).cover? todo_name.size
    "Todo must be between 1 and 100 characters."
  end
end

post "/lists/:id/todos" do
  @list = get_list params

  todo_name = params[:todo].strip

  error = error_for_todo(todo_name)
  if error
    session[:error] = error
    erb :list
  else
    @list[:todos] << {name: todo_name, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/" + params[:id]
  end
end

post "/lists/:id/todos/:todo_id/destroy" do
  @list = get_list params
  removed_todo = @list[:todos].delete_at(params[:todo_id].to_i)
  if removed_todo
    session[:success] = "Todo item deleted."
  else
    session[:error] = "There was an error deleting the todo item."
  end
  erb :list
end

post "/lists/:id/todos/:todo_id" do
  @list = get_list params
  is_completed = params[:completed] == "true"
  @list[:todos][params[:todo_id].to_i][:completed] = is_completed
  session[:success] = "Todo has been updated."
  erb :list
end
