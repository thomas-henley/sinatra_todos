require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
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

# Add a todo task to the list
post "/lists/:index/todos" do
  @list = session[:lists][params["index"].to_i]
  todo_name = params[:todo].strip
  error = error_for_todo_name(todo_name)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << { name: todo_name, completed: false }
    session[:success] = "The todo was added."
    redirect "/lists/#{params[:index]}"
  end
end

post "/lists/:index/todos/:todo_index" do
  @list = session[:lists][params["index"].to_i]
  todo = @list[:todos][params[:todo_index].to_i]
  todo[:completed] = (params[:completed] == "true")
  redirect "/lists/#{params["index"].to_i}"
end

post "/lists/:index/todos/:todo_index/delete" do
  @list = session[:lists][params["index"].to_i]
  @list[:todos].delete_at(params[:todo_index].to_i)
  session[:success] = "The todo was deleted."
  redirect "/lists/#{params["index"].to_i}"
end

post "/lists/:index/complete_all" do
  @list = session[:lists][params["index"].to_i]
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  redirect "/lists/#{params[:index]}"
end

post "/lists/:index/delete" do
  session[:lists].delete_at(params[:index].to_i)
  session[:success] = "The list has been deleted."
  redirect "/lists"
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
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end
