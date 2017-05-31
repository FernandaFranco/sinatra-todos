require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

helpers do
  def completed?(list)
    total_items(list) > 0 && items_remaining(list).zero?
  end

  def items_remaining(list)
    list[:todos].count do |todo|
      !todo[:completed]
    end
  end

  def total_items(list)
    list[:todos].size
  end

  def list_class(list)
    "complete" if completed?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition{ |list| completed?(list)}

    incomplete_lists.each {|list| yield list, lists.index(list)}
    complete_lists.each {|list| yield list, lists.index(list)}
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition{ |todo| todo[:completed] }

    incomplete_todos.each(&block)
    complete_todos.each(&block)
  end

  def next_todo_id(todos)
    max = todos.map { |todo| todo[:id] }.max || 0
    max + 1
  end
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

# Return a specific error message if the name is invalid. Return nil otherwise.
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "List name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# Return a specific error message if the name is invalid. Return nil otherwise.
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "Todo must be between 1 and 100 characters."
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
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Method to make sure a list ID exists
def load_list(index)
  list = session[:lists][index] if index
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# View a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb :list, layout: :layout
end

# Edit an existing todo list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id)
  erb :edit_list, layout: :layout
end

# Update an existing todo list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id)

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# Delete an existing todo list
post "/lists/:id/delete" do
  id = params[:id].to_i

  session[:lists].delete_at(id)
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

# Create a new todo item in a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << {id: id, name: text, completed: false}

    session[:success] = "The todo has been added."
    redirect "/lists/#{@list_id}"
  end
end

# Deleting a todo item
post "/lists/:list_id/todos/:todo_id/delete" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  @list[:todos].reject! { |todo| todo[:id] == todo_id}

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{list_id}"
  end
end

# Checking an item as completed/uncompleted
post "/lists/:list_id/todos/:todo_id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  todo = @list[:todos].find { |todo| todo[:id] == todo_id }
  todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all items completed
post "/lists/:list_id/complete_all" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  @list[:todos].each do |todo|
    todo[:completed] = true
  end

  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end

not_found do
  session[:error] = "Page not found"
  redirect "/lists"
end
